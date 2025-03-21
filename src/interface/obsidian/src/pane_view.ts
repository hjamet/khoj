import { ItemView, WorkspaceLeaf, setIcon } from 'obsidian';
import { KhojSetting } from 'src/settings';
import { KhojSearchModal } from 'src/search_modal';
import { KhojView, populateHeaderPane } from './utils';
import { KhojChatView } from './chat_view';

export abstract class KhojPaneView extends ItemView {
    setting: KhojSetting;
    isSimplifiedView: boolean;

    constructor(leaf: WorkspaceLeaf, setting: KhojSetting, isSimplifiedView: boolean = false) {
        super(leaf);

        this.setting = setting;
        this.isSimplifiedView = isSimplifiedView;

        // Register Modal Keybindings to send user message
        // this.scope.register([], 'Enter', async () => { await this.chat() });
    }

    async onOpen() {
        let { contentEl } = this;

        // Add title to the Khoj Chat modal
        let headerEl = contentEl.createDiv(({ attr: { id: "khoj-header", class: "khoj-header" } }));

        // Only setup the header pane for full views
        if (!this.isSimplifiedView) {
            // Setup the header pane
            await populateHeaderPane(headerEl, this.setting);

            // Set the active nav pane
            headerEl.getElementsByClassName("chat-nav")[0]?.classList.add("khoj-nav-selected");
            headerEl.getElementsByClassName("chat-nav")[0]?.addEventListener("click", (_) => { this.activateView(KhojView.CHAT); });
            headerEl.getElementsByClassName("search-nav")[0]?.addEventListener("click", (_) => { new KhojSearchModal(this.app, this.setting).open(); });
            // The similar-nav event listener is already set in utils.ts
            let similarNavSvgEl = headerEl.getElementsByClassName("khoj-nav-icon-similar")[0]?.firstElementChild;
            if (!!similarNavSvgEl) similarNavSvgEl.id = "similar-nav-icon-svg";
        } else {
            // For simplified view, just add the title with the icon
            const viewType = this.getViewType();
            let titleEl = headerEl.createEl('div', {
                cls: 'khoj-simplified-header'
            });

            // Get the icon based on view type
            if (viewType === KhojView.SIMILAR && (this.constructor as any).iconName) {
                const iconName = (this.constructor as any).iconName;
                setIcon(titleEl.createSpan({ cls: 'khoj-simplified-icon' }), iconName);
            }

            titleEl.createSpan({ text: this.getDisplayText() });
        }
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
