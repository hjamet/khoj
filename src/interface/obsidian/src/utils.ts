import { FileSystemAdapter, Notice, Vault, Modal, TFile, request, setIcon, Editor } from 'obsidian';
import { KhojSetting, UserInfo } from 'src/settings'

export function getVaultAbsolutePath(vault: Vault): string {
    let adaptor = vault.adapter;
    if (adaptor instanceof FileSystemAdapter) {
        return adaptor.getBasePath();
    }
    return '';
}

function fileExtensionToMimeType(extension: string): string {
    switch (extension) {
        case 'pdf':
            return 'application/pdf';
        case 'png':
            return 'image/png';
        case 'jpg':
        case 'jpeg':
            return 'image/jpeg';
        case 'md':
        case 'markdown':
            return 'text/markdown';
        case 'org':
            return 'text/org';
        default:
            return 'text/plain';
    }
}

function filenameToMimeType(filename: TFile): string {
    switch (filename.extension) {
        case 'pdf':
            return 'application/pdf';
        case 'png':
            return 'image/png';
        case 'jpg':
        case 'jpeg':
            return 'image/jpeg';
        case 'webp':
            return 'image/webp';
        case 'md':
        case 'markdown':
            return 'text/markdown';
        case 'org':
            return 'text/org';
        default:
            console.warn(`Unknown file type: ${filename.extension}. Defaulting to text/plain.`);
            return 'text/plain';
    }
}

export const fileTypeToExtension = {
    'pdf': ['pdf'],
    'image': ['png', 'jpg', 'jpeg', 'webp'],
    'markdown': ['md', 'markdown'],
};
export const supportedImageFilesTypes = fileTypeToExtension.image;
export const supportedBinaryFileTypes = fileTypeToExtension.pdf.concat(supportedImageFilesTypes);
export const supportedFileTypes = fileTypeToExtension.markdown.concat(supportedBinaryFileTypes);

export async function updateContentIndex(vault: Vault, setting: KhojSetting, lastSync: Map<TFile, number>, regenerate: boolean = false, userTriggered: boolean = false): Promise<Map<TFile, number>> {
    // Get all markdown, pdf files in the vault
    console.log(`Khoj: Updating Khoj content index...`)
    const files = vault.getFiles()
        // Filter supported file types for syncing
        .filter(file => supportedFileTypes.includes(file.extension))
        // Filter user configured file types for syncing
        .filter(file => {
            if (fileTypeToExtension.markdown.includes(file.extension)) return setting.syncFileType.markdown;
            if (fileTypeToExtension.pdf.includes(file.extension)) return setting.syncFileType.pdf;
            if (fileTypeToExtension.image.includes(file.extension)) return setting.syncFileType.images;
            return false;
        })
        // Filter files based on specified folders
        .filter(file => {
            // If no folders are specified, sync all files
            if (setting.syncFolders.length === 0) return true;
            // Otherwise, check if the file is in one of the specified folders
            return setting.syncFolders.some(folder =>
                file.path.startsWith(folder + '/') || file.path === folder
            );
        });

    let countOfFilesToIndex = 0;
    let countOfFilesToDelete = 0;
    lastSync = lastSync.size > 0 ? lastSync : new Map<TFile, number>();

    // Add all files to index as multipart form data
    let fileData = [];
    let currentBatchSize = 0;
    const MAX_BATCH_SIZE = 10 * 1024 * 1024; // 10MB max batch size
    let currentBatch = [];

    for (const file of files) {
        // Only push files that have been modified since last sync if not regenerating
        if (!regenerate && file.stat.mtime < (lastSync.get(file) ?? 0)) {
            continue;
        }

        countOfFilesToIndex++;
        const encoding = supportedBinaryFileTypes.includes(file.extension) ? "binary" : "utf8";
        const mimeType = fileExtensionToMimeType(file.extension) + (encoding === "utf8" ? "; charset=UTF-8" : "");
        const fileContent = encoding == 'binary' ? await vault.readBinary(file) : await vault.read(file);
        const fileItem = { blob: new Blob([fileContent], { type: mimeType }), path: file.path };

        // Check if adding this file would exceed batch size
        const fileSize = (typeof fileContent === 'string') ? new Blob([fileContent]).size : fileContent.byteLength;
        if (currentBatchSize + fileSize > MAX_BATCH_SIZE && currentBatch.length > 0) {
            fileData.push(currentBatch);
            currentBatch = [];
            currentBatchSize = 0;
        }

        currentBatch.push(fileItem);
        currentBatchSize += fileSize;
    }

    // Add any previously synced files to be deleted to final batch
    let filesToDelete: TFile[] = [];
    for (const lastSyncedFile of lastSync.keys()) {
        if (!files.includes(lastSyncedFile)) {
            countOfFilesToDelete++;
            let fileObj = new Blob([""], { type: filenameToMimeType(lastSyncedFile) });
            currentBatch.push({ blob: fileObj, path: lastSyncedFile.path });
            filesToDelete.push(lastSyncedFile);
        }
    }

    // Add final batch if not empty
    if (currentBatch.length > 0) {
        fileData.push(currentBatch);
    }

    // Delete all files of enabled content types first if regenerating
    let error_message = null;
    const contentTypesToDelete = [];
    if (regenerate) {
        // Mark content types to delete based on user sync file type settings
        if (setting.syncFileType.markdown) contentTypesToDelete.push('markdown');
        if (setting.syncFileType.pdf) contentTypesToDelete.push('pdf');
        if (setting.syncFileType.images) contentTypesToDelete.push('image');
    }
    for (const contentType of contentTypesToDelete) {
        const response = await fetch(`${setting.khojUrl}/api/content/type/${contentType}?client=obsidian`, {
            method: "DELETE",
            headers: {
                'Authorization': `Bearer ${setting.khojApiKey}`,
            }
        });
        if (!response.ok) {
            error_message = "❗️Failed to clear existing content index";
            fileData = [];
        }
    }

    // Iterate through all indexable files in vault, 10Mb batch at a time
    let responses: string[] = [];
    for (const batch of fileData) {
        // Create multipart form data with all files in batch
        const formData = new FormData();
        batch.forEach(fileItem => { formData.append('files', fileItem.blob, fileItem.path) });

        // Call Khoj backend to sync index with updated files in vault
        const response = await fetch(`${setting.khojUrl}/api/content?client=obsidian`, {
            method: "PATCH",
            headers: {
                'Authorization': `Bearer ${setting.khojApiKey}`,
            },
            body: formData,
        });

        if (!response.ok) {
            if (response.status === 429) {
                let response_text = await response.text();
                if (response_text.includes("Too much data")) {
                    const errorFragment = document.createDocumentFragment();
                    errorFragment.appendChild(document.createTextNode("❗️Exceeded data sync limits. To resolve this either:"));
                    const bulletList = document.createElement('ul');

                    const limitFilesItem = document.createElement('li');
                    const settingsPrefixText = document.createTextNode("Limit files to sync from ");
                    const settingsLink = document.createElement('a');
                    settingsLink.textContent = "Khoj settings";
                    settingsLink.href = "#";
                    settingsLink.addEventListener('click', (e) => {
                        e.preventDefault();
                        openKhojPluginSettings();
                    });
                    limitFilesItem.appendChild(settingsPrefixText);
                    limitFilesItem.appendChild(settingsLink);
                    bulletList.appendChild(limitFilesItem);

                    const upgradeItem = document.createElement('li');
                    const upgradeLink = document.createElement('a');
                    upgradeLink.href = `${setting.khojUrl}/settings#subscription`;
                    upgradeLink.textContent = 'Upgrade your subscription';
                    upgradeLink.target = '_blank';
                    upgradeItem.appendChild(upgradeLink);
                    bulletList.appendChild(upgradeItem);
                    errorFragment.appendChild(bulletList);
                    error_message = errorFragment;
                } else {
                    error_message = `❗️Failed to sync your content with Khoj server. Requests were throttled. Upgrade your subscription or try again later.`;
                }
                break;
            } else if (response.status === 404) {
                error_message = `❗️Could not connect to Khoj server. Ensure you can connect to it.`;
                break;
            } else {
                error_message = `❗️Failed to sync all your content with Khoj server. Raise issue on Khoj Discord or Github\nError: ${response.statusText}`;
            }
        } else {
            responses.push(await response.text());
        }
    }

    // Update last sync time for each successfully indexed file
    files
        .filter(file => responses.find(response => response.includes(file.path)))
        .reduce((newSync, file) => {
            newSync.set(file, new Date().getTime());
            return newSync;
        }, lastSync);

    // Remove files that were deleted from last sync
    filesToDelete
        .filter(file => responses.find(response => response.includes(file.path)))
        .forEach(file => lastSync.delete(file));

    if (error_message) {
        new Notice(error_message);
    } else {
        if (userTriggered) new Notice('✅ Updated Khoj index.');
        console.log(`✅ Refreshed Khoj content index. Updated: ${countOfFilesToIndex} files, Deleted: ${countOfFilesToDelete} files.`);
    }

    return lastSync;
}

export async function openKhojPluginSettings(): Promise<void> {
    const setting = this.app.setting;
    await setting.open();
    setting.openTabById('khoj');
}

export async function createNote(name: string, newLeaf = false): Promise<void> {
    try {
        let pathPrefix: string
        switch (this.app.vault.getConfig('newFileLocation')) {
            case 'current':
                pathPrefix = (this.app.workspace.getActiveFile()?.parent.path ?? '') + '/'
                break
            case 'folder':
                pathPrefix = this.app.vault.getConfig('newFileFolderPath') + '/'
                break
            default: // 'root'
                pathPrefix = ''
                break
        }
        await this.app.workspace.openLinkText(`${pathPrefix}${name}.md`, '', newLeaf)
    } catch (e) {
        console.error('Khoj: Could not create note.\n' + (e as any).message);
        throw e
    }
}

export async function createNoteAndCloseModal(query: string, modal: Modal, opt?: { newLeaf: boolean }): Promise<void> {
    try {
        await createNote(query, opt?.newLeaf);
    }
    catch (e) {
        new Notice((e as Error).message)
        return
    }
    modal.close();
}

export async function canConnectToBackend(
    khojUrl: string,
    khojApiKey: string,
    showNotice: boolean = false
): Promise<{ connectedToBackend: boolean; statusMessage: string, userInfo: UserInfo | null }> {
    let connectedToBackend = false;
    let userInfo: UserInfo | null = null;

    if (!!khojUrl) {
        let headers = !!khojApiKey ? { "Authorization": `Bearer ${khojApiKey}` } : undefined;
        try {
            let response = await request({ url: `${khojUrl}/api/v1/user`, method: "GET", headers: headers })
            connectedToBackend = true;
            userInfo = JSON.parse(response);
        } catch (error) {
            connectedToBackend = false;
            console.log(`Khoj connection error:\n\n${error}`);
        };
    }

    let statusMessage: string = getBackendStatusMessage(connectedToBackend, userInfo?.email, khojUrl, khojApiKey);
    if (showNotice) new Notice(statusMessage);
    return { connectedToBackend, statusMessage, userInfo };
}

export function getBackendStatusMessage(
    connectedToServer: boolean,
    userEmail: string | undefined,
    khojUrl: string,
    khojApiKey: string
): string {
    // Welcome message with default settings. Khoj cloud always expects an API key.
    if (!khojApiKey && khojUrl === 'https://app.khoj.dev')
        return `🌈 Welcome to Khoj! Get your API key from ${khojUrl}/settings#clients and set it in the Khoj plugin settings on Obsidian`;

    if (!connectedToServer)
        return `❗️Could not connect to Khoj at ${khojUrl}. Ensure your can access it`;
    else if (!userEmail)
        return `✅ Connected to Khoj. ❗️Get a valid API key from ${khojUrl}/settings#clients to log in`;
    else if (userEmail === 'default@example.com')
        // Logged in as default user in anonymous mode
        return `✅ Signed in to Khoj`;
    else
        return `✅ Signed in to Khoj as ${userEmail}`;
}

export async function populateHeaderPane(headerEl: Element, setting: KhojSetting): Promise<void> {
    let userInfo: UserInfo | null = null;
    try {
        const { userInfo: extractedUserInfo } = await canConnectToBackend(setting.khojUrl, setting.khojApiKey, false);
        userInfo = extractedUserInfo;
    } catch (error) {
        console.error("❗️Could not connect to Khoj");
    }

    // Add Khoj title to header element
    const titleEl = headerEl.createDiv();
    titleEl.className = 'khoj-logo';
    titleEl.textContent = "Khoj Chat";

    // Populate the header element with the navigation pane
    // Create the nav element
    const nav = headerEl.createEl('nav');
    nav.className = 'khoj-nav';

    // Create the chat link
    const chatLink = nav.createEl('a');
    chatLink.id = 'chat-nav';
    chatLink.className = 'khoj-nav chat-nav';
    chatLink.dataset.view = KhojView.CHAT;

    // Create the chat icon
    const chatIcon = chatLink.createEl('span');
    chatIcon.className = 'khoj-nav-icon khoj-nav-icon-chat';
    setIcon(chatIcon, 'khoj-chat');

    // Create the chat text
    const chatText = chatLink.createEl('span');
    chatText.className = 'khoj-nav-item-text';
    chatText.textContent = 'Chat';

    // Append the chat icon and text to the chat link
    chatLink.appendChild(chatIcon);
    chatLink.appendChild(chatText);

    // Create the search link
    const searchLink = nav.createEl('a');
    searchLink.id = 'search-nav';
    searchLink.className = 'khoj-nav search-nav';

    // Create the search icon
    const searchIcon = searchLink.createEl('span');
    searchIcon.className = 'khoj-nav-icon khoj-nav-icon-search';
    setIcon(searchIcon, 'khoj-search');

    // Create the search text
    const searchText = searchLink.createEl('span');
    searchText.className = 'khoj-nav-item-text';
    searchText.textContent = 'Search';

    // Append the search icon and text to the search link
    searchLink.appendChild(searchIcon);
    searchLink.appendChild(searchText);

    // Create the similar link
    const similarLink = nav.createEl('a');
    similarLink.id = 'similar-nav';
    similarLink.className = 'khoj-nav similar-nav';
    similarLink.dataset.view = KhojView.SIMILAR;

    // Create the similar icon
    const similarIcon = similarLink.createEl('span');
    similarIcon.id = 'similar-nav-icon';
    similarIcon.className = 'khoj-nav-icon khoj-nav-icon-similar';
    setIcon(similarIcon, 'webhook');

    // Create the similar text
    const similarText = similarLink.createEl('span');
    similarText.className = 'khoj-nav-item-text';
    similarText.textContent = 'Similar';

    // Append the similar icon and text to the similar link
    similarLink.appendChild(similarIcon);
    similarLink.appendChild(similarText);

    // Add event listeners to the navigation links
    const app = (window as any).app;

    // Chat link event listener
    chatLink.addEventListener('click', () => {
        // Get the activateView method from the plugin instance
        const khojPlugin = app.plugins.plugins.khoj;
        if (khojPlugin && khojPlugin.activateView) {
            khojPlugin.activateView(KhojView.CHAT);
        }
    });

    // Search link event listener
    searchLink.addEventListener('click', () => {
        // Open the search modal
        const khojPlugin = app.plugins.plugins.khoj;
        if (khojPlugin) {
            new (window as any).khoj.KhojSearchModal(app, khojPlugin.settings).open();
        }
    });

    // Similar link event listener
    similarLink.addEventListener('click', () => {
        // Get the activateView method from the plugin instance
        const khojPlugin = app.plugins.plugins.khoj;
        if (khojPlugin && khojPlugin.activateView) {
            khojPlugin.activateView(KhojView.SIMILAR);
        }
    });

    // Append the nav items to the nav element
    nav.appendChild(chatLink);
    nav.appendChild(searchLink);
    nav.appendChild(similarLink);

    // Create right side container for New Chat button and agent selector
    const rightSideContainer = headerEl.createDiv("khoj-header-right-container");

    // Add agent selector container
    const agentContainer = rightSideContainer.createDiv("khoj-header-agent-container");

    // Add agent selector
    const agentSelect = agentContainer.createEl("select", {
        attr: {
            class: "khoj-header-agent-select",
            id: "khoj-header-agent-select"
        }
    });

    // Add New Chat button
    const newChatButton = rightSideContainer.createEl('button');
    newChatButton.className = 'khoj-header-new-chat-button';
    newChatButton.title = 'Start New Chat (Ctrl+Alt+N)';
    setIcon(newChatButton, 'plus-circle');
    newChatButton.textContent = 'New Chat';

    // Add event listener to the New Chat button
    newChatButton.addEventListener('click', () => {
        const khojPlugin = app.plugins.plugins.khoj;
        if (khojPlugin) {
            // First activate the chat view
            khojPlugin.activateView(KhojView.CHAT).then(() => {
                // Then create a new conversation
                setTimeout(() => {
                    const chatView = app.workspace.getActiveViewOfType((window as any).khoj.KhojChatView);
                    if (chatView) {
                        chatView.createNewConversation();
                    }
                }, 100);
            });
        }
    });

    // Append the title, nav items and right container to the header element
    headerEl.appendChild(titleEl);
    headerEl.appendChild(nav);
    headerEl.appendChild(rightSideContainer);

    // Update active state based on current view
    const updateActiveState = () => {
        const activeLeaf = app.workspace.activeLeaf;
        if (!activeLeaf) return;

        const viewType = activeLeaf.view?.getViewType();

        // Remove active class from all links
        chatLink.classList.remove('khoj-nav-selected');
        similarLink.classList.remove('khoj-nav-selected');

        // Add active class to the current view link
        if (viewType === KhojView.CHAT) {
            chatLink.classList.add('khoj-nav-selected');
        } else if (viewType === KhojView.SIMILAR) {
            similarLink.classList.add('khoj-nav-selected');
        }
    };

    // Initial update
    updateActiveState();

    // Register event for workspace changes
    app.workspace.on('active-leaf-change', updateActiveState);
}

export enum KhojView {
    CHAT = "khoj-chat-view",
    SIMILAR = "khoj-similar-view",
}

function copyParentText(event: MouseEvent, message: string, originalButton: string) {
    const button = event.currentTarget as HTMLElement;
    if (!button || !button?.parentNode?.textContent) return;
    if (!!button.firstChild) button.removeChild(button.firstChild as HTMLImageElement);
    const textContent = message ?? button.parentNode.textContent.trim();
    navigator.clipboard.writeText(textContent).then(() => {
        setIcon((button as HTMLElement), 'copy-check');
        setTimeout(() => {
            setIcon((button as HTMLElement), originalButton);
        }, 1000);
    }).catch((error) => {
        console.error("Error copying text to clipboard:", error);
        const originalButtonText = button.innerHTML;
        button.innerHTML = "⛔️";
        setTimeout(() => {
            button.innerHTML = originalButtonText;
            setIcon((button as HTMLElement), originalButton);
        }, 2000);
    });

    return textContent;
}

export function createCopyParentText(message: string, originalButton: string = 'copy-plus') {
    return function (event: MouseEvent) {
        return copyParentText(event, message, originalButton);
    }
}

export function jumpToPreviousView() {
    const editor: Editor = this.app.workspace.getActiveFileView()?.editor
    if (!editor) return;
    editor.focus();
}

export function pasteTextAtCursor(text: string | undefined) {
    // Get the current active file's editor
    const editor: Editor = this.app.workspace.getActiveFileView()?.editor
    if (!editor || !text) return;
    const cursor = editor.getCursor();
    // If there is a selection, replace it with the text
    if (editor?.getSelection()) {
        editor.replaceSelection(text);
        // If there is no selection, insert the text at the cursor position
    } else if (cursor) {
        editor.replaceRange(text, cursor);
    }
}

export function getFileFromPath(sourceFiles: TFile[], chosenFile: string): TFile | undefined {
    // Find the vault file matching file of chosen file, entry
    let fileMatch = sourceFiles
        // Sort by descending length of path
        // This finds longest path match when multiple files have same name
        .sort((a, b) => b.path.length - a.path.length)
        // The first match is the best file match across OS
        // e.g. Khoj server on Linux, Obsidian vault on Android
        .find(file => chosenFile.replace(/\\/g, "/").endsWith(file.path))
    return fileMatch;
}

export function getLinkToEntry(sourceFiles: TFile[], chosenFile: string, chosenEntry: string): string | undefined {
    // Find the vault file matching file of chosen file, entry
    let fileMatch = getFileFromPath(sourceFiles, chosenFile);

    // Return link to vault file at heading of chosen search result
    if (fileMatch) {
        let resultHeading = fileMatch.extension !== 'pdf' ? chosenEntry.split('\n', 1)[0] : '';
        let linkToEntry = resultHeading.startsWith('#') ? `${fileMatch.path}${resultHeading}` : fileMatch.path;
        console.log(`Link: ${linkToEntry}, File: ${fileMatch.path}, Heading: ${resultHeading}`);
        return linkToEntry;
    }
}
