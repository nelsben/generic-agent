/**
 * customerSummaryRail: the right rail (FR2, FE-15). A full-height sheet, 480 to 640 px wide, that slides over
 * the right of the page on Cmd/Ctrl-Shift-K, the launcher's expand or the compact window's expand, with the
 * account's context beside the shared conversation.
 *
 * Where it draws (docs/research/fr2-surfaces-spike.md, "Rail"): it is a child of customerSummaryPanel, inside the
 * stage the panel moves onto document.body, so it is fixed to the window. It slides over the page with a soft
 * shadow and no backdrop. It never pushes the page: no published API lets a component resize the Lightning
 * workspace, and the spike's push worked only by restyling Salesforce's own markup.
 *
 * The conversation is not built here. The panel owns the one c-customer-summary-conversation and moves it into
 * this component's "conversation" slot while the rail is open, so the thread, the session and the sessions list
 * (FE-22's control, shown open) are the same ones the compact window had.
 *
 * Public interface:
 *   @api recordId, objectApiName  the page's record. An Account's Id sets the account whose context is shown;
 *                                 it stays until another Account page opens, so opening a deal from the rail
 *                                 keeps the rail on its account.
 *   @api brand                    the BrandSettings values: the agent name and the logo in the header.
 *   @api open({ sessionId, recordId, source, focus, returnFocus })  slides the rail in. source is hotkey,
 *                                 expand, launcher, tab or hover. focus (default true, except for hover) moves
 *                                 focus in; returnFocus names where it goes back on close (default: where it was).
 *   @api close(), minimize()      closes it, or slides it out to the slim edge tab.
 *   @api prefetch()               starts loading the account's context (CustomerSummaryContext.getContext).
 *   @api state                    closed, open or minimized.
 *   event railopen                detail { sessionId, recordId, source, focus }; cancelable: a host that places
 *                                 focus itself (the panel, on the composer) prevents it, otherwise the rail
 *                                 focuses its main column.
 *   event railclose               detail { hadFocus, restored }: the rail closed; restored says whether focus
 *                                 went back where it came from, so a host can place it when it did not.
 *   event railminimize            the rail went to its edge tab.
 *
 * Keys: a document keydown listener owns Cmd-Shift-K on a Mac and Ctrl-Shift-K elsewhere, by physical key, and
 * yields when another component already handled the event. The context starts loading on the key press, before
 * the rail renders open. Esc anywhere in the rail closes it and returns focus, unless an IME composition is open.
 *
 * Minimize and hover: minimize leaves a 28 px tab on the right edge. Clicking it opens the rail with focus;
 * resting the pointer on it for HOVER_OPEN_MS opens it as a peek (no focus move), which slides back to the tab
 * when the pointer leaves, unless the rep clicked or moved focus into it.
 *
 * Context (BE-25): open deals, recent activity (each item with its kind), open cases and the rep's own last
 * summary, each a collapsible section that shows skeleton rows while loading, an empty line, a no-access line
 * for a part the rep cannot read, and one fixed sentence with Retry when the call fails. Each deal, case and
 * activity is a button that opens its record. No record Id is put in the markup.
 */
import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, unsubscribe, MessageContext, APPLICATION_SCOPE } from 'lightning/messageService';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import CUSTOMER_SUMMARY_EXPAND from '@salesforce/messageChannel/CustomerSummaryExpand__c';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Account.Name';
import getContext from '@salesforce/apex/CustomerSummaryContext.getContext';

const ACCOUNT_PREFIX = '001';
const FALLBACK_NAME = 'Assistant';
export const HOVER_OPEN_MS = 350;
export const PEEK_CLOSE_MS = 400;
const SKELETON_ROWS = ['s1', 's2', 's3'];
const CONTEXT_FAILED = "Couldn't load this account's details. Try again in a minute.";
const NO_ACCOUNT = 'Open an account to see its open deals, recent activity, cases and last summary here.';
const NO_ACCESS = "Your access doesn't include this.";
const KIND_LABEL = {
    call: 'Call',
    email: 'Email',
    task: 'Task',
    event: 'Event',
    case_comment: 'Case comment'
};
// The activity sources CustomerSummaryContext lists in unavailable, and how a rep reads each.
const ACTIVITY_SOURCES = [
    ['tasks', 'tasks and calls'],
    ['events', 'events'],
    ['emails', 'emails'],
    ['caseComments', 'case comments']
];
const SECTIONS = [
    { key: 'deals', title: 'Open deals', empty: 'No open deals.' },
    { key: 'activity', title: 'Recent activity', empty: 'No recent activity.' },
    { key: 'cases', title: 'Open cases', empty: 'No open cases.' },
    { key: 'summary', title: 'Last summary', empty: 'No summary of this account yet. Ask for one.' }
];

function isMac() {
    const nav = window.navigator || {};
    const platform = (nav.userAgentData && nav.userAgentData.platform) || nav.platform || '';
    return /mac|iphone|ipad/i.test(platform);
}

/** Cmd-Shift-K on Mac, Ctrl-Shift-K elsewhere; by physical key so non-Latin layouts work; no Alt. */
export function isRailHotkey(event) {
    if (event.code !== 'KeyK' || !event.shiftKey || event.altKey) {
        return false;
    }
    return isMac() ? event.metaKey && !event.ctrlKey : event.ctrlKey && !event.metaKey;
}

function isComposing(event) {
    return event.isComposing || event.keyCode === 229;
}

/** The focused element itself, through open shadow roots: document.activeElement stops at the outermost host. */
function deepActiveElement() {
    let active = document.activeElement;
    while (active && active.shadowRoot && active.shadowRoot.activeElement) {
        active = active.shadowRoot.activeElement;
    }
    return active && active !== document.body ? active : null;
}

function hasFocus(el) {
    return Boolean(el) && (deepActiveElement() === el || el.matches(':focus'));
}

/** A Date field ('2026-11-14') as a short local date, never shifted by the time zone. */
function dayText(value) {
    const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(value || '');
    if (!m) {
        return '';
    }
    const d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
    return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
}

/** A Datetime value as a short local date. */
function instantText(value) {
    const d = value ? new Date(value) : null;
    return d && !Number.isNaN(d.getTime()) ? d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' }) : '';
}

function joined(parts) {
    return parts.filter((p) => p !== null && p !== undefined && p !== '').join(' · ');
}

export default class CustomerSummaryRail extends NavigationMixin(LightningElement) {
    @api objectApiName;
    @api brand = null;

    _state = 'closed';
    keyHint = 'Ctrl Shift K';
    keyShortcut = 'Control+Shift+K';
    contextState = 'idle';
    context = null;
    accountName = '';
    liveMessage = '';
    collapsed = {};
    // FE-32: History is closed by default. Its timeline and chart mount, and so load, only when it is opened.
    historyOpen = false;
    historyCount = null;

    _recordId = null;
    _accountId = null;
    _loadedAccountId = null;
    _requestId = 0;
    _peek = false;
    _focusInside = false;
    _returnFocus = null;
    _hoverTimer = null;
    _leaveTimer = null;
    _keyHandler = null;
    _subscription = null;
    messageContext;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value || null;
        if (this._recordId && this._recordId.startsWith(ACCOUNT_PREFIX) && this._recordId !== this._accountId) {
            this._accountId = this._recordId;
            this.accountName = '';
            // FE-32: History closes on an account change, so the previous account's timeline and count go with it.
            this.historyOpen = false;
            this.historyCount = null;
            if (this._state !== 'closed') {
                this.prefetch();
            }
        }
    }

    /** closed, open or minimized. */
    @api
    get state() {
        return this._state;
    }

    @api
    get accountId() {
        return this._accountId;
    }

    @wire(MessageContext)
    wiredMessageContext(context) {
        this.messageContext = context;
        this._subscribe();
    }

    @wire(getRecord, { recordId: '$_accountId', optionalFields: [ACCOUNT_NAME_FIELD] })
    wiredAccount({ data }) {
        this.accountName = data ? getFieldValue(data, ACCOUNT_NAME_FIELD) || '' : '';
    }

    // ------------------------------------------------------------ lifecycle

    connectedCallback() {
        const mac = isMac();
        this.keyHint = mac ? '⌘⇧K' : 'Ctrl Shift K';
        this.keyShortcut = mac ? 'Meta+Shift+K' : 'Control+Shift+K';
        this._keyHandler = (event) => this._handleDocumentKeydown(event);
        document.addEventListener('keydown', this._keyHandler);
        this._subscribe();
    }

    disconnectedCallback() {
        if (this._keyHandler) {
            document.removeEventListener('keydown', this._keyHandler);
            this._keyHandler = null;
        }
        if (this._subscription) {
            unsubscribe(this._subscription);
            this._subscription = null;
        }
        this._clearTimers();
    }

    _subscribe() {
        if (this._subscription || !this.messageContext) {
            return;
        }
        this._subscription = subscribe(this.messageContext, CUSTOMER_SUMMARY_EXPAND, (message) => this._handleExpandMessage(message), {
            scope: APPLICATION_SCOPE
        });
    }

    // ------------------------------------------------------------ public interface

    @api
    open(options) {
        const opts = options || {};
        const source = opts.source || 'hotkey';
        const focus = opts.focus === undefined ? source !== 'hover' : Boolean(opts.focus);
        if (opts.recordId) {
            this.recordId = opts.recordId;
        }
        // The context call goes out first: the rail renders while it is on its way.
        this.prefetch();
        this._clearTimers();
        this._peek = source === 'hover';
        if (this._state !== 'open') {
            if (focus && !this._railHasFocus()) {
                this._returnFocus = opts.returnFocus || deepActiveElement();
            }
            this._showDialog();
            this._state = 'open';
        }
        const event = new CustomEvent('railopen', {
            detail: { sessionId: opts.sessionId || null, recordId: opts.recordId || null, source, focus },
            cancelable: true
        });
        this.dispatchEvent(event);
        if (focus && !event.defaultPrevented) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                const main = this.refs && this.refs.main;
                if (main && this._state === 'open') {
                    main.focus();
                }
            }, 0);
        }
    }

    @api
    close() {
        if (this._state === 'closed') {
            return;
        }
        const hadFocus = this._railHasFocus();
        const target = this._returnFocus;
        this._returnFocus = null;
        this._clearTimers();
        this._peek = false;
        this._closeDialog();
        this._state = 'closed';
        // A focused element moved out of the rail does not always fire focusout.
        this._focusInside = false;
        // Focus goes back where it came from: the browser's dialog record first, then the element recorded
        // on open. When neither is there, restored is false and the host picks a place (the panel: its launcher).
        let restored = false;
        if (hadFocus) {
            if (!this._activeInside() && deepActiveElement()) {
                restored = true;
            } else if (target && target.isConnected && typeof target.focus === 'function') {
                target.focus();
                restored = hasFocus(target);
            }
        }
        this.dispatchEvent(new CustomEvent('railclose', { detail: { hadFocus, restored } }));
    }

    @api
    minimize() {
        if (this._state !== 'open') {
            return;
        }
        const hadFocus = this._railHasFocus();
        this._clearTimers();
        this._peek = false;
        this._closeDialog();
        this._state = 'minimized';
        this.dispatchEvent(new CustomEvent('railminimize'));
        if (hadFocus) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                const tab = this.refs && this.refs.tab;
                if (tab && this._state === 'minimized') {
                    tab.focus();
                }
            }, 0);
        }
    }

    /** Loads the account's context unless it is loaded or on its way. A failed load is tried again. */
    @api
    prefetch() {
        const accountId = this._accountId;
        if (!accountId) {
            return Promise.resolve();
        }
        if (accountId === this._loadedAccountId && this.contextState !== 'error') {
            return this._pending || Promise.resolve();
        }
        return this._load(accountId);
    }

    _load(accountId) {
        this._requestId += 1;
        const requestId = this._requestId;
        this._loadedAccountId = accountId;
        this.contextState = 'loading';
        this.context = null;
        this.liveMessage = 'Loading account details';
        this._pending = getContext({ accountId })
            .then((result) => {
                if (requestId !== this._requestId) {
                    return;
                }
                this.context = result || null;
                this.contextState = 'ready';
                this.liveMessage = 'Account details loaded';
            })
            .catch(() => {
                if (requestId !== this._requestId) {
                    return;
                }
                this.context = null;
                this.contextState = 'error';
                this.liveMessage = CONTEXT_FAILED;
            })
            .finally(() => {
                if (requestId === this._requestId) {
                    this._pending = null;
                }
            });
        return this._pending;
    }

    // ------------------------------------------------------------ dialog and focus

    /**
     * Focus inside the rail, including the slotted conversation, whose composer sits in another shadow root.
     * The focusin and focusout events are the reliable record: under synthetic shadow the active element of
     * the body-mounted stage reads as the body, and :focus-within does not see through it.
     */
    _railHasFocus() {
        return this._focusInside || this._activeInside();
    }

    /** The focused element, as the page reads it, is inside this component. */
    _activeInside() {
        const rail = this.refs && this.refs.rail;
        if (rail && rail.matches(':focus-within')) {
            return true;
        }
        const host = this.template.host;
        let node = deepActiveElement();
        while (node) {
            if (node === host) {
                return true;
            }
            node = node.parentNode || node.host || null;
        }
        return false;
    }

    /** Non-modal: show() makes the browser remember the focused element and close() gives focus back to it. */
    _showDialog() {
        const rail = this.refs && this.refs.rail;
        if (rail && typeof rail.show === 'function' && !rail.open) {
            rail.show();
        }
    }

    _closeDialog() {
        const rail = this.refs && this.refs.rail;
        if (rail && rail.open && typeof rail.close === 'function') {
            rail.close();
        }
    }

    _clearTimers() {
        clearTimeout(this._hoverTimer);
        clearTimeout(this._leaveTimer);
        this._hoverTimer = null;
        this._leaveTimer = null;
    }

    // ------------------------------------------------------------ keys, controls, hover

    _handleDocumentKeydown(event) {
        if (!event.defaultPrevented && isRailHotkey(event)) {
            event.preventDefault();
            this.open({ source: 'hotkey' });
        }
    }

    handleRailKeydown(event) {
        if (event.key !== 'Escape' || event.defaultPrevented || isComposing(event)) {
            return;
        }
        event.preventDefault();
        this.close();
    }

    handleMinimize() {
        this.minimize();
    }

    handleClose() {
        this.close();
    }

    handleTabClick() {
        this.open({ source: 'tab' });
    }

    handleTabEnter() {
        if (this._state !== 'minimized') {
            return;
        }
        this.prefetch();
        clearTimeout(this._hoverTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._hoverTimer = setTimeout(() => {
            this._hoverTimer = null;
            if (this._state === 'minimized') {
                this.open({ source: 'hover' });
            }
        }, HOVER_OPEN_MS);
    }

    /** Keyboard focus on the tab starts the context call, as the pointer's hover does. */
    handleTabFocus() {
        this.prefetch();
    }

    handleTabLeave() {
        clearTimeout(this._hoverTimer);
        this._hoverTimer = null;
        // The tab slides out over 180 ms and sits above the peek while it does, so the pointer can leave the
        // tab without ever entering the rail: that leave ends the peek too.
        if (this._peek && this._state === 'open') {
            this.handleRailLeave();
        }
    }

    handleRailEnter() {
        clearTimeout(this._leaveTimer);
        this._leaveTimer = null;
    }

    /** A peek slides back to the tab when the pointer leaves, unless the rep has started using it. */
    handleRailLeave() {
        if (!this._peek) {
            return;
        }
        clearTimeout(this._leaveTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._leaveTimer = setTimeout(() => {
            this._leaveTimer = null;
            if (this._peek && this._state === 'open' && !this._railHasFocus()) {
                this.minimize();
            }
        }, PEEK_CLOSE_MS);
    }

    /** A click inside turns a peek into an ordinary open rail. */
    handleRailEngage() {
        this._peek = false;
    }

    /** Focus moved into the rail: noted, and a peek becomes an ordinary open rail. */
    handleRailFocusIn() {
        this._focusInside = true;
        this._peek = false;
    }

    /** focusout comes before the next focusin, so a move inside the rail ends with the flag set again. */
    handleRailFocusOut() {
        this._focusInside = false;
    }

    _handleExpandMessage(message) {
        if (this._state === 'open') {
            return;
        }
        const m = message || {};
        this.open({ sessionId: m.sessionId || null, recordId: m.recordId || null, source: 'expand' });
    }

    handleRetry() {
        if (this._accountId) {
            this._load(this._accountId);
        }
    }

    handleSectionToggle(event) {
        const key = event.currentTarget.dataset.section;
        this.collapsed = { ...this.collapsed, [key]: !this.collapsed[key] };
    }

    handleOpenRecord(event) {
        const { list, index } = event.currentTarget.dataset;
        const rows = this._rows(list);
        const row = rows[Number(index)];
        if (!row || !row.recordId) {
            return;
        }
        // The host navigates when it can: inside customerSummaryPanel the rail lives on a stage moved onto
        // document.body, out of reach of the page's navigation context, so the panel (still in the utility
        // bar) takes the event and calls Navigate. On its own, the rail navigates itself.
        const request = new CustomEvent('railopenrecord', { detail: { recordId: row.recordId }, cancelable: true });
        this.dispatchEvent(request);
        if (request.defaultPrevented) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: row.recordId, actionName: 'view' }
        });
    }

    // ------------------------------------------------------------ template state

    get agentName() {
        return (this.brand && this.brand.agentName) || FALLBACK_NAME;
    }

    get logoUrl() {
        return (this.brand && this.brand.logoUrl) || null;
    }

    get logoAlt() {
        return this.brand && this.brand.companyName ? this.brand.companyName + ' logo' : '';
    }

    get railLabel() {
        return this.agentName + ' side panel';
    }

    get tabLabel() {
        return 'Open the ' + this.agentName + ' side panel';
    }

    get isOpen() {
        return this._state === 'open';
    }

    get openState() {
        return this.isOpen ? 'true' : 'false';
    }

    /** Overlay, never push (fr2-surfaces-spike.md): the page underneath keeps its own layout. */
    get railClass() {
        return 'cs-rail cs-rail_overlay' + (this.isOpen ? ' cs-rail_open' : '') + (this._peek && this.isOpen ? ' cs-rail_peek' : '');
    }

    get tabClass() {
        return 'cs-rail-tab' + (this._state === 'minimized' ? ' cs-rail-tab_shown' : '');
    }

    get hasAccount() {
        return Boolean(this._accountId);
    }

    /** FE-19: the history timeline and the sentiment chart sit under the sections while the rail is open, so a closed rail makes no call. */
    get showHistory() {
        return this.hasAccount && this._state === 'open';
    }

    /** FE-32: the History body (timeline and chart) is mounted only while History is open. */
    get historyExpanded() {
        return this.showHistory && this.historyOpen;
    }
    get historyBodyId() {
        return 'cs-ctx-body-history';
    }
    get historyAriaExpanded() {
        return String(this.historyExpanded);
    }
    get historyIcon() {
        return this.historyExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }
    get historyBodyClass() {
        return 'cs-ctx-body' + (this.historyExpanded ? '' : ' slds-hide');
    }
    /** The count comes from the timeline once it has loaded, so it is absent until History has been opened. */
    get hasHistoryCount() {
        return this.historyCount !== null;
    }

    handleHistoryToggle() {
        this.historyOpen = !this.historyOpen;
    }

    handleHistoryCount(event) {
        // Ignore a count from a timeline that is closed, or that loaded for an account the rail no longer shows.
        const detail = event.detail || {};
        if (!this.historyExpanded || detail.accountId !== this._accountId) {
            return;
        }
        const count = Number(detail.count);
        this.historyCount = Number.isNaN(count) ? null : String(count);
    }

    get noAccountText() {
        return NO_ACCOUNT;
    }

    get contextHeading() {
        return this.accountName ? 'About ' + this.accountName : 'About this account';
    }

    get isLoading() {
        return this.contextState === 'idle' || this.contextState === 'loading';
    }

    get isError() {
        return this.contextState === 'error';
    }

    get errorText() {
        return CONTEXT_FAILED;
    }

    get busy() {
        return this.isLoading ? 'true' : 'false';
    }

    get skeletonRows() {
        return SKELETON_ROWS;
    }

    _unavailable(key) {
        const list = (this.context && this.context.unavailable) || [];
        return list.includes(key);
    }

    _rows(list) {
        const c = this.context || {};
        switch (list) {
            case 'deals':
                return c.openDeals || [];
            case 'activity':
                return c.recentActivity || [];
            case 'cases':
                return c.openCases || [];
            default:
                return [];
        }
    }

    _items(key) {
        if (key === 'deals') {
            return this._rows('deals').map((d, i) => ({
                key: 'd' + i,
                index: String(i),
                title: d.name || 'Untitled deal',
                meta: joined([d.stage, d.closeDate ? 'Closes ' + dayText(d.closeDate) : '']),
                amount: d.amount,
                hasAmount: d.amount !== null && d.amount !== undefined,
                hasKind: false
            }));
        }
        if (key === 'activity') {
            return this._rows('activity').map((a, i) => ({
                key: 'a' + i,
                index: String(i),
                title: a.text || KIND_LABEL[a.kind] || 'Activity',
                meta: joined([a.who, dayText(a.activityDate)]),
                kind: a.kind,
                kindLabel: KIND_LABEL[a.kind] || 'Activity',
                kindClass: 'cs-ctx-kind cs-ctx-kind_' + (KIND_LABEL[a.kind] ? a.kind : 'other'),
                hasKind: true,
                hasAmount: false
            }));
        }
        if (key === 'cases') {
            return this._rows('cases').map((c, i) => ({
                key: 'c' + i,
                index: String(i),
                title: c.subject || 'Case ' + (c.caseNumber || ''),
                meta: joined([c.caseNumber ? 'Case ' + c.caseNumber : '', c.status, c.priority ? c.priority + ' priority' : '']),
                hasKind: false,
                hasAmount: false
            }));
        }
        return [];
    }

    _activityNote() {
        const missing = ACTIVITY_SOURCES.filter(([k]) => this._unavailable(k)).map(([, label]) => label);
        if (!missing.length || missing.length === ACTIVITY_SOURCES.length) {
            return '';
        }
        return "Some activity isn't shown: your access doesn't include " + missing.join(', ') + '.';
    }

    get sections() {
        const ready = this.contextState === 'ready';
        return SECTIONS.map((s) => {
            const expanded = !this.collapsed[s.key];
            const isSummary = s.key === 'summary';
            const unavailable =
                ready &&
                (s.key === 'deals'
                    ? this._unavailable('openDeals')
                    : s.key === 'cases'
                      ? this._unavailable('openCases')
                      : s.key === 'summary'
                        ? this._unavailable('lastSummary')
                        : ACTIVITY_SOURCES.every(([k]) => this._unavailable(k)));
            const items = ready && !isSummary ? this._items(s.key) : [];
            const summary = ready && isSummary && this.context ? this.context.lastSummary : null;
            const lines = summary
                ? String(summary.firstLines || '')
                      .split('\n')
                      .map((l) => l.trim())
                      .filter(Boolean)
                      .map((text, i) => ({ key: 'l' + i, text }))
                : [];
            const hasContent = isSummary ? lines.length > 0 : items.length > 0;
            return {
                key: s.key,
                title: s.title,
                testId: 'cs-ctx-' + s.key,
                bodyId: 'cs-ctx-body-' + s.key,
                expanded,
                ariaExpanded: String(expanded),
                icon: expanded ? 'utility:chevrondown' : 'utility:chevronright',
                bodyClass: 'cs-ctx-body' + (expanded ? '' : ' slds-hide'),
                count: !isSummary && ready && !unavailable ? String(items.length) : '',
                hasCount: !isSummary && ready && !unavailable,
                loading: this.isLoading,
                unavailable,
                unavailableText: NO_ACCESS,
                empty: ready && !unavailable && !hasContent,
                emptyText: s.empty,
                isSummary,
                items,
                hasItems: !isSummary && items.length > 0,
                lines,
                hasSummary: isSummary && lines.length > 0,
                summaryDate: summary ? 'Saved ' + instantText(summary.summaryDate) : '',
                note: ready && s.key === 'activity' && !unavailable ? this._activityNote() : '',
                hasNote: ready && s.key === 'activity' && !unavailable && Boolean(this._activityNote())
            };
        });
    }
}
