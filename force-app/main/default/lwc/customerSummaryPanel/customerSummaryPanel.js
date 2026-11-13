/**
 * customerSummaryPanel: the compact window (FR2, FE-13). An eager utility bar item that puts a launcher
 * and a 420 px window at the bottom right of the page, opened by Cmd/Ctrl-K or the launcher.
 *
 * The panel is the frame: the launcher, the window, the hotkey, Esc, the focus it returns, minimize,
 * expand, the brand theme and the message channel. The whole conversation (header, thread, cards,
 * quick actions, composer) is c-customer-summary-conversation; this passes it the page's record, the
 * brand and the session, and asks it to focus its composer.
 *
 * Where it draws (docs/research/fr2-surfaces-spike.md, "Corner"): a closed utility panel is
 * display:none and an open one is a transformed box, so nothing fixed inside it can reach the page's
 * corner. The frame's stage (launcher plus window) is rendered here and then moved onto document.body
 * once (moveToBody below). The utility item keeps the wires, the message channel and the key listener;
 * its own panel shows only a short note with an Open button. The bar stays at its default (left)
 * alignment, where a softphone lives, and the stage sits at the bottom right, clear of it.
 *
 * Keys: a document keydown listener owns Cmd-K on Mac and Ctrl-K elsewhere (no Shift or Alt): it
 * records where focus was, opens the window and focuses the composer. It yields when another
 * component already handled the event (defaultPrevented). Under synthetic shadow a document listener
 * does not hear keys from inside the moved stage, so the stage handles the same key itself first.
 *
 * Focus: the window is a non-modal <dialog> (show(), never showModal()), so Tab is never trapped.
 * Esc anywhere inside it closes it and returns focus to where it was, through the browser's own
 * dialog record (see _showSheet): a field inside another component on the record page too, which
 * Lightning Web Security hides from this component. When that element is gone or cannot take focus,
 * focus goes to the launcher, never the page body. During an IME composition Esc only ends the
 * composition.
 * The composer stops every other key, so Lightning's single-key shortcuts don't fire while typing.
 *
 * Minimize closes the window to the launcher; the conversation stays mounted, so the thread is kept.
 * Expand (for the rail, FE-15) is behind @api expandEnabled, off by default, so no dead button ships.
 * It fires 'expand' and publishes on CustomerSummaryExpand, both with { sessionId, recordId }.
 */
import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { subscribe, unsubscribe, publish, MessageContext, APPLICATION_SCOPE } from 'lightning/messageService';
import { EnclosingUtilityId, minimize as minimizeUtility } from 'lightning/platformUtilityBarApi';
import CUSTOMER_SUMMARY_OPEN from '@salesforce/messageChannel/CustomerSummaryOpen__c';
import CUSTOMER_SUMMARY_EXPAND from '@salesforce/messageChannel/CustomerSummaryExpand__c';
import getSettings from '@salesforce/apex/BrandSettings.getSettings';

// Brand settings field -> the theme variable the panel sets (fr2-design.md, Theming), on its host and
// on the body-mounted stage. The stylesheets read only these variables, each with a neutral fallback.
const THEME_VARIABLES = [
    ['primaryColor', '--cs-color-primary'],
    ['accentColor', '--cs-color-accent'],
    ['surfaceColor', '--cs-color-surface'],
    ['inkColor', '--cs-color-ink'],
    ['displayFont', '--cs-font-display'],
    ['bodyFont', '--cs-font-body'],
    ['radius', '--cs-radius']
];
const ACCOUNT_PREFIX = '001';
// The launcher's words and the window's name before the brand settings arrive, or when they fail.
const FALLBACK_NAME = 'Assistant';
// After a close, the page can still move focus for a moment (Lightning's own Esc handling, a utility
// panel being put away); the panel puts it back for this long, polling at FOCUS_GUARD_POLL_MS.
const FOCUS_GUARD_MS = 2000;
const FOCUS_GUARD_POLL_MS = 50;
// Any of these from the user ends the guard: they have moved focus themselves.
const USER_INPUT_EVENTS = ['keydown', 'mousedown', 'pointerdown', 'touchstart'];

function isMac() {
    const nav = window.navigator || {};
    const platform = (nav.userAgentData && nav.userAgentData.platform) || nav.platform || '';
    return /mac|iphone|ipad/i.test(platform);
}

/** Cmd-K on Mac, Ctrl-K elsewhere; by physical key so non-Latin layouts work; no Shift or Alt. */
function isHotkey(event) {
    if (event.code !== 'KeyK' || event.shiftKey || event.altKey) {
        return false;
    }
    return isMac() ? event.metaKey && !event.ctrlKey : event.ctrlKey && !event.metaKey;
}

/** The focused element itself, through open shadow roots: document.activeElement stops at the outermost host. */
function deepActiveElement() {
    let active = document.activeElement;
    while (active && active.shadowRoot && active.shadowRoot.activeElement) {
        active = active.shadowRoot.activeElement;
    }
    return active && active !== document.body ? active : null;
}

/** True when focus is on el now (el may sit inside a shadow tree). */
function hasFocus(el) {
    return Boolean(el) && (deepActiveElement() === el || el.matches(':focus'));
}

/**
 * The one place the panel leaves its own DOM (the spike's body mount): moves el to the end of
 * document.body. Lightning Web Security allows it, but it is not a documented pattern, so it stays
 * in this one function, easy to replace. The caller tracks whether it is mounted: under synthetic
 * shadow a moved node's parentNode reads null, so it cannot be asked.
 */
function moveToBody(el) {
    document.body.appendChild(el);
}

export default class CustomerSummaryPanel extends LightningElement {
    @api recordId;
    @api objectApiName;
    /** Shows the Expand button (the rail, FE-15). Off until the rail ships, so no dead button. */
    @api expandEnabled = false;
    /** right (default) or left: left for an org that mirrors its utility bar to the right. */
    @api corner = 'right';

    brand = null;
    sessionId = null;
    isOpen = false;
    keyHint = 'Ctrl K';
    keyShortcut = 'Control+K';

    _pageRef;
    _keyHandler;
    _subscription;
    _returnFocus = null;
    _focusGuard = null;
    _stage = null;
    _stageMounted = false;

    messageContext;

    /** MessageContext can arrive after connectedCallback: subscribe as soon as it does. */
    @wire(MessageContext)
    wiredMessageContext(context) {
        this.messageContext = context;
        this._subscribe();
    }

    /** The utility bar item this panel sits in, or null outside a utility bar. */
    @wire(EnclosingUtilityId) utilityId;

    @wire(CurrentPageReference)
    wiredPageRef(ref) {
        this._pageRef = ref;
    }

    /**
     * The brand (BrandSettings, the Default record). Until it arrives, or if it fails, the launcher shows
     * the fallback words and no logo, and the stylesheets' neutral fallbacks apply.
     */
    @wire(getSettings)
    wiredBrand({ data }) {
        if (!data) {
            return;
        }
        this.brand = data;
        this._applyTheme();
    }

    /** The theme variables go on the host and on the stage, which no longer inherits from the host. */
    _applyTheme() {
        const data = this.brand;
        if (!data) {
            return;
        }
        [this.template.host, this._stage].filter(Boolean).forEach((target) => {
            THEME_VARIABLES.forEach(([field, variable]) => {
                if (data[field]) {
                    target.style.setProperty(variable, data[field]);
                } else {
                    target.style.removeProperty(variable);
                }
            });
        });
    }

    // ------------------------------------------------------------ lifecycle

    connectedCallback() {
        const mac = isMac();
        this.keyHint = mac ? '⌘K' : 'Ctrl K';
        this.keyShortcut = mac ? 'Meta+K' : 'Control+K';
        this._keyHandler = (event) => this._handleDocumentKeydown(event);
        document.addEventListener('keydown', this._keyHandler);
        // Reconnected after a disconnect: put the stage back on the body.
        this._mountStage();
        this._subscribe();
    }

    renderedCallback() {
        if (!this._stage && this.refs && this.refs.stage) {
            this._stage = this.refs.stage;
            this._mountStage();
            this._applyTheme();
        }
    }

    disconnectedCallback() {
        this._stopFocusGuard();
        if (this._keyHandler) {
            document.removeEventListener('keydown', this._keyHandler);
            this._keyHandler = null;
        }
        if (this._stageMounted) {
            this._stage.remove();
            this._stageMounted = false;
        }
        if (this._subscription) {
            unsubscribe(this._subscription);
            this._subscription = null;
        }
    }

    _mountStage() {
        if (this._stage && !this._stageMounted) {
            moveToBody(this._stage);
            this._stageMounted = true;
        }
    }

    _subscribe() {
        if (this._subscription || !this.messageContext) {
            return;
        }
        this._subscription = subscribe(
            this.messageContext,
            CUSTOMER_SUMMARY_OPEN,
            (message) => this._handleMessage(message),
            { scope: APPLICATION_SCOPE }
        );
    }

    // ------------------------------------------------------------ template state

    get agentName() {
        return (this.brand && this.brand.agentName) || FALLBACK_NAME;
    }

    get launcherName() {
        return this.brand && this.brand.agentName ? 'Ask ' + this.brand.agentName : 'Ask the ' + FALLBACK_NAME.toLowerCase();
    }

    get logoUrl() {
        return (this.brand && this.brand.logoUrl) || null;
    }

    get stageClass() {
        return 'cs-stage ' + (this.corner === 'left' ? 'cs-corner_left' : 'cs-corner_right');
    }

    get launcherClass() {
        return 'cs-launcher' + (this.isOpen ? ' cs-launcher_away' : '');
    }

    get sheetClass() {
        return 'cs-sheet' + (this.isOpen ? ' cs-sheet_open' : '');
    }

    get openState() {
        return this.isOpen ? 'true' : 'false';
    }

    // ------------------------------------------------------------ page context

    get pageRecordId() {
        if (this.recordId) {
            return this.recordId;
        }
        const ref = this._pageRef;
        return ref && ref.type === 'standard__recordPage' && ref.attributes ? ref.attributes.recordId || null : null;
    }

    get pageObjectApiName() {
        if (this.objectApiName) {
            return this.objectApiName;
        }
        const ref = this._pageRef;
        return ref && ref.type === 'standard__recordPage' && ref.attributes ? ref.attributes.objectApiName || null : null;
    }

    handleSessionChange(event) {
        this.sessionId = event.detail ? event.detail.sessionId : null;
    }

    _conversation() {
        return (this.refs && this.refs.conversation) || null;
    }

    _sheetHasFocus() {
        const sheet = this.refs && this.refs.sheet;
        return Boolean(sheet) && sheet.matches(':focus-within');
    }

    // ------------------------------------------------------------ keys and controls

    _handleDocumentKeydown(event) {
        if (!event.defaultPrevented && isHotkey(event)) {
            event.preventDefault();
            this._openAndFocus();
        }
    }

    /**
     * Keys inside the stage (the composer, the launcher), which the document listeners cannot hear:
     * Cmd/Ctrl-K, and any key ends the focus guard, as a key on the page does.
     */
    handleStageKeydown(event) {
        this._stopFocusGuard();
        this._handleDocumentKeydown(event);
    }

    /** Keys anywhere inside the window: Esc closes it and returns focus, unless an IME composition is open. Tab is left alone. */
    handleSheetKeydown(event) {
        if (event.key !== 'Escape' || event.defaultPrevented || event.isComposing || event.keyCode === 229) {
            return;
        }
        event.preventDefault();
        this._close();
    }

    handleLauncher() {
        this._openAndFocus();
    }

    /** The Open button in the utility panel's own note: put the utility away and open the window. */
    async handleUtilityOpen() {
        try {
            if (this.utilityId) {
                await minimizeUtility(this.utilityId);
            }
        } catch (e) {
            // The API is unavailable: open anyway.
        }
        this._openAndFocus();
        // The Open button is gone with the utility panel: a close goes to the launcher.
        this._returnFocus = null;
    }

    handleMinimize() {
        this._close();
    }

    handleExpand() {
        const detail = { sessionId: this.sessionId, recordId: this.pageRecordId };
        this.dispatchEvent(new CustomEvent('expand', { detail: { ...detail }, bubbles: true, composed: true }));
        if (this.messageContext) {
            publish(this.messageContext, CUSTOMER_SUMMARY_EXPAND, { ...detail });
        }
        // The rail takes the thread over; the compact window closes as on minimize.
        this._close();
    }

    _openAndFocus() {
        this._stopFocusGuard();
        // Record where focus was, unless it is already inside the window.
        if (!this._sheetHasFocus()) {
            this._returnFocus = deepActiveElement();
            this._showSheet();
        }
        this.isOpen = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const conversation = this._conversation();
            if (conversation) {
                conversation.focusComposer();
            }
        }, 0);
    }

    _close() {
        this._stopFocusGuard();
        const target = this._returnFocus;
        this._returnFocus = null;
        this.isOpen = false;
        // After the rerender, when the launcher can take focus again.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this._returnFocusTo(target), 0);
    }

    /**
     * The window is a non-modal <dialog>: show() makes the browser remember the element that has
     * focus, and close() gives focus back to it. That is the only record of a field inside another
     * namespace's component: Lightning Web Security hides it from this component (its event path and
     * the active element both stop at the record page's outer host). Already open with focus
     * elsewhere on the page: closed and shown again, so the record is the element focused now.
     */
    _showSheet() {
        const sheet = this.refs && this.refs.sheet;
        if (!sheet || typeof sheet.show !== 'function') {
            return;
        }
        if (sheet.open) {
            sheet.close();
        }
        sheet.show();
    }

    /**
     * Focus back where it was: the browser's record (close()), else the element this component
     * recorded; when that element is gone or cannot take focus, the launcher, never the body.
     */
    _returnFocusTo(target) {
        const sheet = this.refs && this.refs.sheet;
        if (sheet && sheet.open && typeof sheet.close === 'function') {
            sheet.close();
        }
        // Focus is on the page again (the stage's own elements read as the body here).
        const landed = deepActiveElement();
        if (landed) {
            if (landed === target) {
                this._guardFocus(target);
            }
            return;
        }
        if (target && target.isConnected && typeof target.focus === 'function') {
            target.focus();
            if (hasFocus(target)) {
                this._guardFocus(target);
                return;
            }
        }
        const launcher = this.refs && this.refs.launcher;
        if (launcher) {
            launcher.focus();
            this._guardFocus(launcher);
        }
    }

    /**
     * Keep focus on target for a moment after a close. Ends after FOCUS_GUARD_MS, when target leaves
     * the page, or as soon as the user presses a key or a pointer.
     */
    _guardFocus(target) {
        const stopOnInput = () => this._stopFocusGuard();
        USER_INPUT_EVENTS.forEach((type) => document.addEventListener(type, stopOnInput, true));
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        const poll = setInterval(() => {
            if (!target.isConnected) {
                this._stopFocusGuard();
            } else if (!hasFocus(target)) {
                target.focus();
            }
        }, FOCUS_GUARD_POLL_MS);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        const timeout = setTimeout(() => this._stopFocusGuard(), FOCUS_GUARD_MS);
        this._focusGuard = { poll, timeout, stopOnInput };
    }

    _stopFocusGuard() {
        const guard = this._focusGuard;
        if (!guard) {
            return;
        }
        this._focusGuard = null;
        clearInterval(guard.poll);
        clearTimeout(guard.timeout);
        USER_INPUT_EVENTS.forEach((type) => document.removeEventListener(type, guard.stopOnInput, true));
    }

    // ------------------------------------------------------------ message channel

    /** CustomerSummaryOpen: a prompt runs with the message's recordId as context; an Account Id alone briefs it. */
    _handleMessage(message) {
        if (!message) {
            return Promise.resolve();
        }
        const recordId = message.recordId || null;
        this._openAndFocus();
        const conversation = this._conversation();
        if (!conversation) {
            return Promise.resolve();
        }
        const prompt = (message.prompt || '').trim();
        if (prompt) {
            return conversation.ask(prompt, recordId);
        }
        if (recordId && recordId.startsWith(ACCOUNT_PREFIX)) {
            return conversation.summarize(recordId);
        }
        return Promise.resolve();
    }
}
