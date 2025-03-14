import { ItemView, WorkspaceLeaf } from 'obsidian';
import { KhojSetting } from 'src/settings';
import { KhojSearchModal } from 'src/search_modal';
import { KhojView, populateHeaderPane } from './utils';

export abstract class KhojPaneView extends ItemView {
    setting: KhojSetting;

    constructor(leaf: WorkspaceLeaf, setting: KhojSetting) {
        super(leaf);

        this.setting = setting;

        // Register Modal Keybindings to send user message
        // this.scope.register([], 'Enter', async () => { await this.chat() });
    }

    async onOpen() {
        let { contentEl } = this;

        // Add title to the Khoj Chat modal
        let headerEl = contentEl.createDiv(({ attr: { id: "khoj-header", class: "khoj-header" } }));
        // Setup the header pane
        await populateHeaderPane(headerEl, this.setting);

        // If the view is a chat view, add an event listener to the "New Chat" button
        if (this.getViewType() === KhojView.CHAT) {
            const newChatButton = headerEl.querySelector('.khoj-header-new-chat-button') as HTMLButtonElement;
            if (newChatButton) {
                // @ts-ignore - We know this method exists in the KhojChatView class
                newChatButton.addEventListener('click', async () => {
                    // @ts-ignore
                    await this.createNewConversation(this.currentAgent || undefined);
                });
            }
        }

        // Set the active nav pane
        headerEl.getElementsByClassName("chat-nav")[0]?.classList.add("khoj-nav-selected");
        headerEl.getElementsByClassName("chat-nav")[0]?.addEventListener("click", (_) => { this.activateView(KhojView.CHAT); });
        headerEl.getElementsByClassName("search-nav")[0]?.addEventListener("click", (_) => { new KhojSearchModal(this.app, this.setting).open(); });
        headerEl.getElementsByClassName("similar-nav")[0]?.addEventListener("click", (_) => { new KhojSearchModal(this.app, this.setting, true).open(); });
        let similarNavSvgEl = headerEl.getElementsByClassName("khoj-nav-icon-similar")[0]?.firstElementChild;
        if (!!similarNavSvgEl) similarNavSvgEl.id = "similar-nav-icon-svg";
    }

    async activateView(viewType: string) {
        const { workspace } = this.app;

        let leaf: WorkspaceLeaf | null = null;
        const leaves = workspace.getLeavesOfType(viewType);

        if (leaves.length > 0) {
            // A leaf with our view already exists, use that
            leaf = leaves[0];
        } else {
            // Our view could not be found in the workspace, create a new leaf
            // in the right sidebar for it
            leaf = workspace.getRightLeaf(false);
            await leaf?.setViewState({ type: viewType, active: true });
        }

        if (leaf) {
            if (viewType === KhojView.CHAT) {
                // focus on the chat input when the chat view is opened
                let chatInput = <HTMLTextAreaElement>this.contentEl.getElementsByClassName("khoj-chat-input")[0];
                if (chatInput) chatInput.focus();
            }

            // "Reveal" the leaf in case it is in a collapsed sidebar
            workspace.revealLeaf(leaf);
        }
    }
}
