import json
import logging
import queue
from datetime import datetime
from time import perf_counter
from typing import Any, Dict, List

import tiktoken
from langchain.schema import ChatMessage
from transformers import AutoTokenizer

from khoj.database.adapters import ConversationAdapters
from khoj.database.models import ClientApplication, KhojUser
from khoj.utils.helpers import is_none_or_empty, merge_dicts

logger = logging.getLogger(__name__)
model_to_prompt_size = {
    "gpt-3.5-turbo": 3000,
    "gpt-4": 7000,
    "gpt-4-1106-preview": 7000,
    "gpt-4-turbo-preview": 7000,
    "llama-2-7b-chat.ggmlv3.q4_0.bin": 1548,
    "gpt-3.5-turbo-16k": 15000,
    "mistral-7b-instruct-v0.1.Q4_0.gguf": 1548,
}
model_to_tokenizer = {
    "llama-2-7b-chat.ggmlv3.q4_0.bin": "hf-internal-testing/llama-tokenizer",
    "mistral-7b-instruct-v0.1.Q4_0.gguf": "mistralai/Mistral-7B-Instruct-v0.1",
}


class ThreadedGenerator:
    def __init__(self, compiled_references, online_results, completion_func=None):
        self.queue = queue.Queue()
        self.compiled_references = compiled_references
        self.online_results = online_results
        self.completion_func = completion_func
        self.response = ""
        self.start_time = perf_counter()

    def __iter__(self):
        return self

    def __next__(self):
        item = self.queue.get()
        if item is StopIteration:
            time_to_response = perf_counter() - self.start_time
            logger.info(f"Chat streaming took: {time_to_response:.3f} seconds")
            if self.completion_func:
                # The completion func effectively acts as a callback.
                # It adds the aggregated response to the conversation history.
                self.completion_func(chat_response=self.response)
            raise StopIteration
        return item

    def send(self, data):
        if self.response == "":
            time_to_first_response = perf_counter() - self.start_time
            logger.info(f"First response took: {time_to_first_response:.3f} seconds")

        self.response += data
        self.queue.put(data)

    def close(self):
        if self.compiled_references and len(self.compiled_references) > 0:
            self.queue.put(f"### compiled references:{json.dumps(self.compiled_references)}")
        elif self.online_results and len(self.online_results) > 0:
            self.queue.put(f"### compiled references:{json.dumps(self.online_results)}")
        self.queue.put(StopIteration)


def message_to_log(
    user_message, chat_response, user_message_metadata={}, khoj_message_metadata={}, conversation_log=[]
):
    """Create json logs from messages, metadata for conversation log"""
    default_khoj_message_metadata = {
        "intent": {"type": "remember", "memory-type": "notes", "query": user_message},
        "trigger-emotion": "calm",
    }
    khoj_response_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Create json log from Human's message
    human_log = merge_dicts({"message": user_message, "by": "you"}, user_message_metadata)

    # Create json log from GPT's response
    khoj_log = merge_dicts(khoj_message_metadata, default_khoj_message_metadata)
    khoj_log = merge_dicts({"message": chat_response, "by": "khoj", "created": khoj_response_time}, khoj_log)

    conversation_log.extend([human_log, khoj_log])
    return conversation_log


def save_to_conversation_log(
    q: str,
    chat_response: str,
    user: KhojUser,
    meta_log: Dict,
    user_message_time: str = None,
    compiled_references: List[str] = [],
    online_results: Dict[str, Any] = {},
    inferred_queries: List[str] = [],
    intent_type: str = "remember",
    client_application: ClientApplication = None,
    conversation_id: int = None,
):
    user_message_time = user_message_time or datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    updated_conversation = message_to_log(
        user_message=q,
        chat_response=chat_response,
        user_message_metadata={"created": user_message_time},
        khoj_message_metadata={
            "context": compiled_references,
            "intent": {"inferred-queries": inferred_queries, "type": intent_type},
            "onlineContext": online_results,
        },
        conversation_log=meta_log.get("chat", []),
    )
    ConversationAdapters.save_conversation(
        user,
        {"chat": updated_conversation},
        client_application=client_application,
        conversation_id=conversation_id,
        user_message=q,
    )

    logger.info(
        f"""
Saved Conversation Turn
You ({user.username}): "{q}"

Khoj: "{inferred_queries if ("text-to-image" in intent_type) else chat_response}"
""".strip()
    )


def generate_chatml_messages_with_context(
    user_message,
    system_message,
    conversation_log={},
    model_name="gpt-3.5-turbo",
    max_prompt_size=None,
    tokenizer_name=None,
):
    """Generate messages for ChatGPT with context from previous conversation"""
    # Set max prompt size from user config, pre-configured for model or to default prompt size
    try:
        max_prompt_size = max_prompt_size or model_to_prompt_size[model_name]
    except:
        max_prompt_size = 2000
        logger.warning(
            f"Fallback to default prompt size: {max_prompt_size}.\nConfigure max_prompt_size for unsupported model: {model_name} in Khoj settings to longer context window."
        )

    # Scale lookback turns proportional to max prompt size supported by model
    lookback_turns = max_prompt_size // 750

    # Extract Chat History for Context
    chat_logs = []
    for chat in conversation_log.get("chat", []):
        chat_notes = f'\n\n Notes:\n{chat.get("context")}' if chat.get("context") else "\n"
        chat_logs += [chat["message"] + chat_notes]

    rest_backnforths = []
    # Extract in reverse chronological order
    for user_msg, assistant_msg in zip(chat_logs[-2::-2], chat_logs[::-2]):
        if len(rest_backnforths) >= 2 * lookback_turns:
            break
        rest_backnforths += reciprocal_conversation_to_chatml([user_msg, assistant_msg])[::-1]

    # Format user and system messages to chatml format
    messages = []
    if not is_none_or_empty(user_message):
        messages.append(ChatMessage(content=user_message, role="user"))
    if len(rest_backnforths) > 0:
        messages += rest_backnforths
    if not is_none_or_empty(system_message):
        messages.append(ChatMessage(content=system_message, role="system"))

    # Truncate oldest messages from conversation history until under max supported prompt size by model
    messages = truncate_messages(messages, max_prompt_size, model_name, tokenizer_name)

    # Return message in chronological order
    return messages[::-1]


def truncate_messages(
    messages: list[ChatMessage], max_prompt_size, model_name: str, tokenizer_name=None
) -> list[ChatMessage]:
    """Truncate messages to fit within max prompt size supported by model"""

    try:
        if model_name.startswith("gpt-"):
            encoder = tiktoken.encoding_for_model(model_name)
        else:
            encoder = AutoTokenizer.from_pretrained(tokenizer_name or model_to_tokenizer[model_name])
    except:
        default_tokenizer = "hf-internal-testing/llama-tokenizer"
        encoder = AutoTokenizer.from_pretrained(default_tokenizer)
        logger.warning(
            f"Fallback to default chat model tokenizer: {default_tokenizer}.\nConfigure tokenizer for unsupported model: {model_name} in Khoj settings to improve context stuffing."
        )

    system_message = messages.pop()
    assert type(system_message.content) == str
    system_message_tokens = len(encoder.encode(system_message.content))

    tokens = sum([len(encoder.encode(message.content)) for message in messages if type(message.content) == str])
    while (tokens + system_message_tokens) > max_prompt_size and len(messages) > 1:
        messages.pop()
        assert type(system_message.content) == str
        tokens = sum([len(encoder.encode(message.content)) for message in messages if type(message.content) == str])

    # Truncate current message if still over max supported prompt size by model
    if (tokens + system_message_tokens) > max_prompt_size:
        assert type(system_message.content) == str
        current_message = "\n".join(messages[0].content.split("\n")[:-1]) if type(messages[0].content) == str else ""
        original_question = "\n".join(messages[0].content.split("\n")[-1:]) if type(messages[0].content) == str else ""
        original_question = f"\n{original_question}"
        original_question_tokens = len(encoder.encode(original_question))
        remaining_tokens = max_prompt_size - original_question_tokens - system_message_tokens
        truncated_message = encoder.decode(encoder.encode(current_message)[:remaining_tokens]).strip()
        logger.debug(
            f"Truncate current message to fit within max prompt size of {max_prompt_size} supported by {model_name} model:\n {truncated_message}"
        )
        messages = [ChatMessage(content=truncated_message + original_question, role=messages[0].role)]

    return messages + [system_message]


def reciprocal_conversation_to_chatml(message_pair):
    """Convert a single back and forth between user and assistant to chatml format"""
    return [ChatMessage(content=message, role=role) for message, role in zip(message_pair, ["user", "assistant"])]
