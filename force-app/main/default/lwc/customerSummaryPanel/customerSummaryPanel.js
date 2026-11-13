/**
 * customerSummaryPanel: a Cmd/Ctrl-K panel over the Customer Summary engine, in the utility bar only.
 *
 * The panel is the frame: the utility item, the hotkey, Esc, the focus it returns, the brand theme
 * and the message channel. The whole conversation (header, thread, cards, quick actions, composer)
 * is c-customer-summary-conversation, which calls CustomerSummaryPanelController; this passes it the
 * page's record and the brand, and asks it to focus its composer.
 *
 * Keys: a document keydown listener owns Cmd-K on Mac and Ctrl-K elsewhere (no Shift or Alt):
 * it records where focus was, opens the utility and focuses the composer. It yields when another
 * component already handled the event (defaultPrevented). The panel is not a modal, so Tab is
 * never trapped; Esc anywhere inside it minimizes the utility and returns focus, except during an
 * IME composition, where Esc only ends the composition. The composer stops every other key, so
 * Lightning's single-key shortcuts don't fire while typing.
 */
import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { subscribe, unsubscribe, MessageContext, APPLICATION_SCOPE } from 'lightning/messageService';
import { EnclosingUtilityId, open as openUtility, minimize as minimizeUtility } from 'lightning/platformUtilityBarApi';
import CUSTOMER_SUMMARY_OPEN from '@salesforce/messageChannel/CustomerSummaryOpen__c';
import getSettings from '@salesforce/apex/BrandSettings.getSettings';

// Brand settings field -> the theme variable the panel sets on its host (fr2-design.md, Theming).
// The stylesheets read only these variables, each with a neutral fallback, so a value left out keeps it.
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
// After minimize resolves, the platform moves focus (utility header, bar button, body) for up to
// about a second; the panel puts it back for this long, polling at FOCUS_GUARD_POLL_MS.
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

export default class CustomerSummaryPanel extends LightningElement {
    @api recordId;
    @api objectApiName;

    brand = null;
    sessionId = null;

    _pageRef;
    _keyHandler;
    _subscription;
    _returnFocus = null;
    _focusGuard = null;

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
     * The brand (BrandSettings, the Default record). Until it arrives, or if it fails, the header shows no
     * name or logo and the stylesheets' neutral fallbacks apply.
     */
    @wire(getSettings)
    wiredBrand({ data }) {
        if (!data) {
            return;
        }
        this.brand = data;
        const style = this.template.host.style;
        THEME_VARIABLES.forEach(([field, variable]) => {
            if (data[field]) {
                style.setProperty(variable, data[field]);
            } else {
                style.removeProperty(variable);
            }
        });
    }

    // ------------------------------------------------------------ lifecycle

    connectedCallback() {
        this._keyHandler = (event) => this._handleDocumentKeydown(event);
        document.addEventListener('keydown', this._keyHandler);
        this.template.addEventListener('keydown', this._panelKeydown);
        this._subscribe();
    }

    disconnectedCallback() {
        this._stopFocusGuard();
        if (this._keyHandler) {
            document.removeEventListener('keydown', this._keyHandler);
            this._keyHandler = null;
        }
        this.template.removeEventListener('keydown', this._panelKeydown);
        if (this._subscription) {
            unsubscribe(this._subscription);
            this._subscription = null;
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
        return this.template.querySelector('c-customer-summary-conversation');
    }

    // ------------------------------------------------------------ keys

    _handleDocumentKeydown(event) {
        if (!event.defaultPrevented && isHotkey(event)) {
            event.preventDefault();
            this._openAndFocus();
        }
    }

    /** Keys anywhere inside the panel: Esc minimizes and returns focus, unless an IME composition is open. Tab is left alone. */
    _panelKeydown = (event) => {
        if (event.key !== 'Escape' || event.defaultPrevented || event.isComposing || event.keyCode === 229) {
            return;
        }
        event.preventDefault();
        this._close();
    };

    async _openAndFocus() {
        this._stopFocusGuard();
        // Record where focus was, unless it is already inside the panel.
        if (!this.template.activeElement) {
            const active = document.activeElement;
            this._returnFocus = active && active !== document.body ? active : null;
        }
        try {
            if (this.utilityId) {
                await openUtility(this.utilityId, { autoFocus: true });
            }
        } catch (e) {
            // The API is unavailable: just focus.
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const conversation = this._conversation();
            if (conversation) {
                conversation.focusComposer();
            }
        }, 0);
    }

    async _close() {
        this._stopFocusGuard();
        const target = this._returnFocus;
        this._returnFocus = null;
        try {
            if (this.utilityId) {
                await minimizeUtility(this.utilityId);
            }
        } catch (e) {
            // The API is unavailable: focus still moves back.
        }
        if (target && target.isConnected && typeof target.focus === 'function') {
            target.focus();
            this._guardFocus(target);
            return;
        }
        const active = this.template.activeElement;
        if (active && active.blur) {
            active.blur();
        }
    }

    /**
     * Keep focus on target while the platform finishes minimizing: it moves focus to the utility
     * header, the bar button, then body, up to about a second after minimize resolves. Ends after
     * FOCUS_GUARD_MS, when target leaves the page, or as soon as the user presses a key or a pointer.
     */
    _guardFocus(target) {
        const stopOnInput = () => this._stopFocusGuard();
        USER_INPUT_EVENTS.forEach((type) => document.addEventListener(type, stopOnInput, true));
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        const poll = setInterval(() => {
            if (!target.isConnected) {
                this._stopFocusGuard();
            } else if (document.activeElement !== target) {
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
