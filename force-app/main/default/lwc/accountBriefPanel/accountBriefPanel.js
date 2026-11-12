/**
 * accountBriefPanel: a Cmd/Ctrl-K panel over the Account Brief engine, in the utility bar only.
 *
 * One engine, two front ends: every call goes through AccountBriefPanelController, which only
 * delegates to the Apex the agent uses (AccountBriefResolver, AccountBrief, AccountBriefMemory,
 * DataExplorer). The panel never renders model text as HTML: answers are text in pre-line blocks.
 *
 * Requests: every entry point (composer, follow-up, candidate, brief button, drill, message
 * channel) goes through _request. The latest request wins: each carries a token, and a reply
 * whose token is no longer the latest is dropped, never rendered. A repeat of the request
 * already in flight (a double click) is ignored.
 *
 * Keys: a document keydown listener owns Cmd-K on Mac and Ctrl-K elsewhere (no Shift or Alt):
 * it records where focus was, opens the utility and focuses the composer. It yields when another
 * component already handled the event (defaultPrevented). The panel is not a modal, so Tab is
 * never trapped; Esc anywhere inside it minimizes the utility and returns focus. The composer
 * stops propagation of every key so Lightning's single-key shortcuts don't fire while typing,
 * so it handles the hotkey and Esc itself.
 */
import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { subscribe, unsubscribe, MessageContext, APPLICATION_SCOPE } from 'lightning/messageService';
import { EnclosingUtilityId, open as openUtility, minimize as minimizeUtility } from 'lightning/platformUtilityBarApi';
import { open as openAgent, execute as executeAgent } from 'lightning/accApi';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import ACCOUNT_BRIEF_OPEN from '@salesforce/messageChannel/AccountBriefOpen__c';
import resolve from '@salesforce/apex/AccountBriefPanelController.resolve';
import getBrief from '@salesforce/apex/AccountBriefPanelController.getBrief';
import explore from '@salesforce/apex/AccountBriefPanelController.explore';
import drill from '@salesforce/apex/AccountBriefPanelController.drill';
import history from '@salesforce/apex/AccountBriefPanelController.history';
import sources from '@salesforce/apex/AccountBriefPanelController.sources';
import agentId from '@salesforce/apex/AccountBriefPanelController.agentId';

const BRIEF_COMMAND = /^\/brief\s+/i;
const HISTORY_TURNS = 5;
const ACCOUNT_PREFIX = '001';
// An 18-character record Id inside a line of text, e.g. an AMBIGUOUS candidate line.
const ID_IN_LINE = /(^|[^A-Za-z0-9])([0-9][0-9A-Za-z]{17})(?![A-Za-z0-9])/;
const NAME_FIELDS = ['Name', 'CaseNumber', 'Subject'];
// After minimize resolves, the platform moves focus (utility header, bar button, body) for up to
// about a second; the panel puts it back for this long, polling at FOCUS_GUARD_POLL_MS.
const FOCUS_GUARD_MS = 2000;
const FOCUS_GUARD_POLL_MS = 50;
// Any of these from the user ends the guard: they have moved focus themselves.
const USER_INPUT_EVENTS = ['keydown', 'mousedown', 'pointerdown', 'touchstart'];
// The controller's fixed ERROR line; shown when a failure carries no handled text.
const ERROR_TEXT = "I couldn't finish that right now. Try again in a minute.";

const BADGE_CLASS = {
    OK: 'slds-theme_success',
    ERROR: 'slds-theme_error'
};

/** The AuraHandledException text from Apex, else the fixed line: never raw script or platform text. */
function errorText(error) {
    const body = error && error.body;
    const message = body && (Array.isArray(body) ? body[0] && body[0].message : body.message);
    return message || ERROR_TEXT;
}

function cellText(value) {
    if (value === null || value === undefined) {
        return '';
    }
    return typeof value === 'object' ? JSON.stringify(value) : String(value);
}

function idInLine(line) {
    const m = ID_IN_LINE.exec(line || '');
    return m ? m[2] : null;
}

/** A brief line as the rep reads it: the record Id and the ' — ' before it removed, indent kept. */
function withoutId(line, id) {
    const shown = line.replace(id, '').replace(/[\s—]+$/, '');
    return shown.trim() ? shown : line;
}

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

export default class AccountBriefPanel extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;

    draft = '';
    pending = false;
    turns = [];
    drillStack = [];
    sourceList = [];
    selectedKeys = [];
    botId = null;
    pageAccount = null;
    briefedAccount = null;
    historyAccount = null;
    historyItems = [];
    notice = '';
    liveMessage = '';
    // Every accordion starts collapsed; never reassigned, so a rerender keeps open sections open.
    closedSections = [];

    _pageRef;
    _lastContextId;
    _seq = 0;
    _requestId = 0;
    _inFlightKey = null;
    _keyHandler;
    _subscription;
    _returnFocus = null;
    _focusGuard = null;
    _drillOrigin = null;
    _focusAfterRender = null;
    _scrollAfterRender = null;

    @wire(MessageContext) messageContext;

    /** The utility bar item this panel sits in, or null outside a utility bar. */
    @wire(EnclosingUtilityId) utilityId;

    @wire(CurrentPageReference)
    wiredPageRef(ref) {
        this._pageRef = ref;
        this._syncContext();
    }

    @wire(sources)
    wiredSources({ data }) {
        if (data) {
            this.sourceList = data.map((s) => ({ key: s.key, title: s.title }));
        }
    }

    @wire(agentId)
    wiredAgentId({ data }) {
        this.botId = data || null;
    }

    // ------------------------------------------------------------ lifecycle

    connectedCallback() {
        this._keyHandler = (event) => this._handleDocumentKeydown(event);
        document.addEventListener('keydown', this._keyHandler);
        this.template.addEventListener('keydown', this._panelKeydown);
        this._subscribe();
        this._syncContext();
    }

    renderedCallback() {
        // MessageContext can arrive after connectedCallback.
        this._subscribe();
        if (this._focusAfterRender) {
            const target = this.template.querySelector(this._focusAfterRender);
            this._focusAfterRender = null;
            if (target) {
                target.focus();
            }
        }
        if (this._scrollAfterRender) {
            const turn = this.template.querySelector('[data-turn="' + this._scrollAfterRender + '"]');
            this._scrollAfterRender = null;
            if (turn && turn.scrollIntoView) {
                turn.scrollIntoView({ block: 'start' });
            }
        }
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
            ACCOUNT_BRIEF_OPEN,
            (message) => this._handleMessage(message),
            { scope: APPLICATION_SCOPE }
        );
    }

    // ------------------------------------------------------------ keys

    _handleDocumentKeydown(event) {
        if (!event.defaultPrevented && isHotkey(event)) {
            event.preventDefault();
            this._openAndFocus();
        }
    }

    /** Keys anywhere inside the panel: Esc minimizes and returns focus. Tab is left alone. */
    _panelKeydown = (event) => {
        if (event.key === 'Escape' && !event.defaultPrevented) {
            event.preventDefault();
            this._close();
        }
    };

    handleComposerKeydown(event) {
        // Keep Lightning's single-key shortcuts from firing while typing; so the hotkey and Esc
        // never reach document or the panel listener, and are handled here.
        event.stopPropagation();
        if (isHotkey(event)) {
            event.preventDefault();
            this._openAndFocus();
            return;
        }
        if (event.key === 'Escape') {
            this._panelKeydown(event);
            return;
        }
        if (event.key === 'Enter' && !event.shiftKey && !event.isComposing && event.keyCode !== 229) {
            event.preventDefault();
            this._submitDraft();
        }
    }

    handleComposerKeyOther(event) {
        event.stopPropagation();
    }

    handleComposerChange(event) {
        this.draft = event.detail.value;
    }

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
            const composer = this._composer();
            if (composer) {
                composer.focus();
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

    _composer() {
        return this.template.querySelector('.abp-composer');
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

    get isAccountPage() {
        const id = this.pageRecordId;
        return this.pageObjectApiName === ACCOUNT_OBJECT.objectApiName || (!!id && id.startsWith(ACCOUNT_PREFIX));
    }

    /** Context for a question: the page's record, then the briefed account. */
    get contextRecordId() {
        return this.pageRecordId || (this.briefedAccount ? this.briefedAccount.id : null);
    }

    _syncContext() {
        const id = this.pageRecordId;
        if (id === this._lastContextId) {
            return;
        }
        this._lastContextId = id;
        this.pageAccount = null;
        // The account changed: an earlier account's briefs must not stay on screen.
        this.historyAccount = null;
        this.historyItems = [];
        if (!id || !this.isAccountPage) {
            return;
        }
        resolve({ accountName: null, recordId: id })
            .then((r) => {
                if (r && r.status === 'RESOLVED' && this._lastContextId === id) {
                    this.pageAccount = { id: r.accountId, name: r.accountName };
                    this._loadHistory(this.pageAccount);
                }
            })
            .catch(() => {
                // The brief button still works; it resolves again on click.
            });
    }

    get briefButtonLabel() {
        return this.pageAccount ? 'Brief ' + this.pageAccount.name : 'Brief this account';
    }

    // ------------------------------------------------------------ include chips

    get includeChips() {
        return this.sourceList.map((s) => ({ key: s.key, title: s.title, selected: this.selectedKeys.includes(s.key) }));
    }

    get hasSources() {
        return this.sourceList.length > 0;
    }

    get includeSummary() {
        if (!this.selectedKeys.length) {
            return 'Sections: all';
        }
        return 'Sections: ' + this.sourceList.filter((s) => this.selectedKeys.includes(s.key)).map((s) => s.title).join(', ');
    }

    handleChip(event) {
        const key = event.currentTarget.dataset.key;
        this.selectedKeys = this.selectedKeys.includes(key)
            ? this.selectedKeys.filter((k) => k !== key)
            : [...this.selectedKeys, key];
    }

    // ------------------------------------------------------------ the one request path

    get sendDisabled() {
        return !this.draft || !this.draft.trim();
    }

    get hasTurns() {
        return this.turns.length > 0;
    }

    /**
     * Runs one request. The latest wins: work gets isCurrent() and checks it after every await,
     * so a superseded reply changes nothing and makes no further call. A repeat of the request
     * in flight (same key) is ignored. Resolves to the short line the live region announces.
     */
    _request({ key, label, loading, work, onError }) {
        if (this.pending && key === this._inFlightKey) {
            return Promise.resolve();
        }
        this._requestId += 1;
        const token = this._requestId;
        const isCurrent = () => token === this._requestId;
        this._inFlightKey = key;
        this.pending = true;
        this.notice = '';
        this.liveMessage = loading;
        return Promise.resolve()
            .then(() => work(isCurrent))
            .then((done) => {
                if (isCurrent() && done) {
                    this.liveMessage = done;
                }
            })
            .catch((error) => {
                if (!isCurrent()) {
                    return;
                }
                const text = errorText(error);
                if (onError) {
                    onError(text);
                } else {
                    this._push({ isText: true, isError: true, question: label, text });
                }
                this.liveMessage = text;
            })
            .finally(() => {
                if (isCurrent()) {
                    this.pending = false;
                    this._inFlightKey = null;
                }
            });
    }

    handleSend() {
        this._submitDraft();
    }

    _submitDraft() {
        const text = (this.draft || '').trim();
        if (!text) {
            return;
        }
        this.draft = '';
        this.submit(text);
    }

    /** Runs one composer text: '/brief <name>' briefs an account, anything else is a question. */
    submit(text, contextRecordId) {
        const q = (text || '').trim();
        if (!q) {
            return Promise.resolve();
        }
        this.drillStack = [];
        if (BRIEF_COMMAND.test(q)) {
            const name = q.replace(BRIEF_COMMAND, '').trim();
            return this._request({
                key: 'brief:' + name.toLowerCase(),
                label: q,
                loading: 'Loading brief for ' + name,
                work: async (isCurrent) => {
                    const r = await resolve({ accountName: name, recordId: null });
                    return this._afterResolve(r, q, isCurrent);
                }
            });
        }
        const context = contextRecordId || this.contextRecordId || null;
        return this._request({
            key: 'ask:' + q,
            label: q,
            loading: 'Loading answer',
            work: async (isCurrent) => {
                const r = await explore({ question: q, contextRecordId: context, historyJson: this._historyJson() });
                if (!isCurrent()) {
                    return null;
                }
                this._push(this._exploreTurn(r, q));
                return r.status === 'ERROR' ? r.answer : 'Answer ready';
            }
        });
    }

    handleBriefThisAccount() {
        const label = this.briefButtonLabel;
        const account = this.pageAccount;
        const recordId = this.pageRecordId;
        this.drillStack = [];
        return this._request({
            key: 'record:' + recordId,
            label,
            loading: 'Loading brief for ' + (account ? account.name : 'this account'),
            work: async (isCurrent) => {
                if (account) {
                    return this._brief(account.id, account.name, label, isCurrent);
                }
                const r = await resolve({ accountName: null, recordId });
                return this._afterResolve(r, label, isCurrent);
            }
        });
    }

    handleCandidate(event) {
        const { id, label } = event.currentTarget.dataset;
        return this._request({
            key: 'record:' + id,
            label,
            loading: 'Loading brief for ' + label,
            work: async (isCurrent) => {
                const r = await resolve({ accountName: null, recordId: id });
                return this._afterResolve(r, label, isCurrent);
            }
        });
    }

    handleFollowup(event) {
        this.submit(event.currentTarget.dataset.text);
    }

    _nextKey(prefix) {
        this._seq += 1;
        return prefix + this._seq;
    }

    _push(turn) {
        const key = turn.key || this._nextKey('t');
        this.turns = [...this.turns, { ...turn, key }];
        this._scrollAfterRender = key;
    }

    _afterResolve(r, label, isCurrent) {
        if (!isCurrent()) {
            return null;
        }
        if (r.status === 'RESOLVED') {
            return this._brief(r.accountId, r.accountName, label, isCurrent);
        }
        if (r.status === 'AMBIGUOUS') {
            const turn = this._ambiguousTurn(r, label);
            this._push(turn);
            return turn.header || 'Pick an account';
        }
        // NOT_FOUND: the resolver's text, verbatim.
        this._push({ isText: true, question: label, text: r.message, historyAnswer: r.message });
        return r.message;
    }

    _ambiguousTurn(r, label) {
        const lines = (r.message || '').split('\n');
        const candidates = [];
        const notes = [];
        lines.slice(1).forEach((line, i) => {
            const id = idInLine(line);
            if (id) {
                // Show "Name — City" without the raw Id; the Id stays in data-id.
                const display = line.replace(id, '').replace(/[\s—-]+$/, '').trim();
                candidates.push({ key: 'c' + i, id, label: line.split(' — ')[0], display: display || line });
            } else if (line.trim()) {
                notes.push({ key: 'n' + i, text: line });
            }
        });
        // Two candidates that read the same keep their Id so they can be told apart.
        candidates.forEach((c) => {
            if (candidates.filter((o) => o.display === c.display).length > 1) {
                c.display = c.display + ' — ' + c.id;
            }
        });
        return { isAmbiguous: true, question: label, header: lines[0], candidates, notes, historyAnswer: r.message };
    }

    async _brief(accountId, accountName, label, isCurrent) {
        const r = await getBrief({
            accountId,
            question: null,
            include: this.selectedKeys.length ? [...this.selectedKeys] : null
        });
        if (!isCurrent()) {
            return null;
        }
        this.briefedAccount = { id: accountId, name: accountName };
        const turn = this._briefTurn(r, label, accountName);
        this._push(turn);
        this._loadHistory(this.briefedAccount);
        return turn.verbatim ? r.message : 'Brief ready: ' + (turn.header || accountName);
    }

    _briefTurn(r, label, accountName) {
        const key = this._nextKey('t');
        const verbatim = r.status === 'NOT_FOUND' || r.status === 'ERROR';
        const answer = (r.answer || '').trim();
        const nl = answer.indexOf('\n');
        const sections = (r.sections || []).map((s, i) => {
            const sectionKey = (s.key || 's') + i;
            return {
                key: sectionKey,
                title: s.title,
                label: s.title + ' · ' + s.shown + ' of ' + s.total,
                status: s.status,
                badgeClass: BADGE_CLASS[s.status] || '',
                lines: (s.body || '').split('\n').map((line, j) => {
                    // A line that ends with a record Id drills to it; the Id stays in data-id, not the text.
                    const id = idInLine(line);
                    const text = id ? withoutId(line, id) : line;
                    return { key: 'l' + j, text: text === '' ? ' ' : text, drillId: id, isDrill: !!id, focusKey: key + '-' + sectionKey + '-l' + j };
                })
            };
        });
        return {
            key,
            isBrief: true,
            question: label,
            accountName,
            verbatim,
            message: r.message,
            messageIsError: r.status === 'ERROR',
            showMessage: verbatim || (r.status === 'EMPTY' && !!r.message && r.message !== answer),
            header: verbatim ? '' : nl >= 0 ? answer.substring(0, nl).trim() : answer,
            rest: verbatim || nl < 0 ? '' : answer.substring(nl + 1).trim(),
            hasSections: sections.length > 0,
            sections,
            ignoredText: r.ignored && r.ignored.length ? 'Not sections: ' + r.ignored.join(', ') : '',
            historyAnswer: verbatim ? r.message : answer
        };
    }

    _historyJson() {
        const items = this.turns
            .filter((t) => t.question && t.historyAnswer)
            .slice(-HISTORY_TURNS)
            .map((t) => ({ question: t.question, answer: t.historyAnswer }));
        return items.length ? JSON.stringify(items) : null;
    }

    _exploreTurn(r, q) {
        const key = this._nextKey('t');
        const tables = (r.resultSets || []).map((rs, i) => this._table(rs, key + '-rs' + i));
        const trail = (r.trail || []).map((text, i) => ({ key: 'q' + i, text }));
        return {
            key,
            isExplore: true,
            question: q,
            isError: r.status === 'ERROR',
            answer: r.answer,
            tables,
            hasTrail: trail.length > 0,
            trail,
            trailLabel: 'Ran ' + trail.length + (trail.length === 1 ? ' query' : ' queries'),
            followups: (r.followups || []).map((text, i) => ({ key: 'f' + i, text })),
            hasFollowups: !!(r.followups && r.followups.length),
            historyAnswer: r.answer
        };
    }

    /** A result table. A row with an Id drills through a real button in its first cell. */
    _table(rs, key) {
        const columns = rs.columns || [];
        const rows = (rs.rows || []).map((row, i) => {
            const rowKey = key + '-r' + i;
            const clickable = !!row.Id;
            return {
                key: rowKey,
                id: row.Id || null,
                cells: columns.map((c, j) => {
                    const value = cellText(row[c]);
                    return { key: 'c' + j, value, isAction: clickable && j === 0, actionText: value || 'Open record', focusKey: rowKey };
                })
            };
        });
        const count = rs.total > rs.shown ? rs.shown + ' of ' + rs.total : String(rs.shown);
        return {
            key,
            title: rs.objectName + ' · ' + count + (rs.shown === 1 ? ' row' : ' rows'),
            columns: columns.map((c, j) => ({ key: 'h' + j, label: c })),
            rows,
            hasRows: rows.length > 0
        };
    }

    // ------------------------------------------------------------ drill

    get isDrilling() {
        return this.drillStack.length > 0;
    }

    /** The conversation stays rendered while drilling, so its state and the origin row survive. */
    get conversationClass() {
        return this.isDrilling ? 'slds-hide' : '';
    }

    get drillTop() {
        return this.drillStack.length ? this.drillStack[this.drillStack.length - 1] : null;
    }

    get breadcrumbs() {
        return this.drillStack.map((d, i) => ({ key: d.key, label: d.label, index: String(i) }));
    }

    handleRowClick(event) {
        const { id, focus } = event.currentTarget.dataset;
        if (id) {
            this._drill(id, null, this.isDrilling, focus);
        }
    }

    handleLineDrill(event) {
        const { id, focus } = event.currentTarget.dataset;
        this._drill(id, null, false, focus);
    }

    handleRelated(event) {
        const top = this.drillTop;
        if (top) {
            this._drill(top.recordId, event.currentTarget.dataset.object, true, null);
        }
    }

    handleCrumb(event) {
        event.preventDefault();
        const index = Number(event.currentTarget.dataset.index);
        this.drillStack = this.drillStack.slice(0, index + 1);
        this._focusAfterRender = '.abp-drill-heading';
    }

    handleBackToConversation(event) {
        if (event) {
            event.preventDefault();
        }
        this.drillStack = [];
        this._focusAfterRender = this._drillOrigin ? '[data-focus="' + this._drillOrigin + '"]' : '.abp-composer';
        this._drillOrigin = null;
    }

    handleViewRecord() {
        const top = this.drillTop;
        if (!top) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: top.recordId, actionName: 'view' }
        });
    }

    _drill(recordId, relatedObject, push, origin) {
        return this._request({
            key: 'drill:' + recordId + ':' + (relatedObject || ''),
            label: relatedObject || recordId,
            loading: relatedObject ? 'Loading ' + relatedObject + ' records' : 'Loading record',
            onError: (text) => {
                this.notice = text;
            },
            work: async (isCurrent) => {
                const d = await drill({ recordId, relatedObject: relatedObject || null });
                if (!isCurrent()) {
                    return null;
                }
                const entry = this._drillEntry(d, recordId, relatedObject);
                if (!push || !this.drillStack.length) {
                    this.drillStack = [entry];
                    this._drillOrigin = origin || null;
                } else {
                    this.drillStack = [...this.drillStack, entry];
                }
                this._focusAfterRender = '.abp-drill-heading';
                return 'Showing ' + entry.label;
            }
        });
    }

    _drillEntry(d, recordId, relatedObject) {
        const key = this._nextKey('d');
        const rs = d.result || {};
        if (relatedObject) {
            return {
                key,
                recordId,
                isRecord: false,
                label: relatedObject,
                table: this._table(rs, key)
            };
        }
        const row = (rs.rows && rs.rows[0]) || {};
        const nameField = NAME_FIELDS.find((f) => row[f]);
        return {
            key,
            recordId,
            isRecord: true,
            objectName: rs.objectName,
            label: nameField ? cellText(row[nameField]) : rs.objectName,
            fields: (rs.columns || [])
                .filter((c) => c !== 'Id')
                .map((c, i) => ({ key: 'f' + i, label: c, value: cellText(row[c]) || '—' })),
            related: (d.related || []).map((name) => ({ key: name, name })),
            hasRelated: !!(d.related && d.related.length)
        };
    }

    // ------------------------------------------------------------ history

    /** The account whose earlier briefs are shown: the open Account page's, or the last briefed. */
    get historyAccountId() {
        return this.historyAccount ? this.historyAccount.id : null;
    }

    get hasHistory() {
        return this.historyItems.length > 0;
    }

    get historyLabel() {
        const name = this.historyAccount && this.historyAccount.name ? ' of ' + this.historyAccount.name : '';
        return 'Earlier briefs' + name + ' (' + this.historyItems.length + ')';
    }

    _loadHistory(account) {
        if (!account || !account.id) {
            return;
        }
        if (account.id !== this.historyAccountId) {
            this.historyItems = [];
        }
        this.historyAccount = account;
        const accountId = account.id;
        history({ accountId })
            .then((turns) => {
                // A reply for an account that is no longer current is dropped.
                if (accountId !== this.historyAccountId) {
                    return;
                }
                this.historyItems = (turns || []).map((t, i) => ({
                    key: 'h' + i,
                    at: t.at || null,
                    status: t.status,
                    question: t.question,
                    headline: t.headline
                }));
            })
            .catch(() => {
                if (accountId === this.historyAccountId) {
                    this.historyItems = [];
                }
            });
    }

    // ------------------------------------------------------------ agent bridge

    get showAgentButton() {
        return !!this.botId;
    }

    async handleAskAgent() {
        const last = this.turns.length ? this.turns[this.turns.length - 1].question : '';
        const question = (this.draft || '').trim() || last || '';
        try {
            await openAgent(this.botId);
            if (question) {
                await executeAgent(question, this.botId);
            }
        } catch (error) {
            this.notice = 'Could not open the agent. ' + errorText(error);
        }
    }

    // ------------------------------------------------------------ message channel

    /** AccountBriefOpen: a prompt runs with the message's recordId as context; an Account Id alone briefs it. */
    _handleMessage(message) {
        if (!message) {
            return Promise.resolve();
        }
        const recordId = message.recordId || null;
        this._openAndFocus();
        const prompt = (message.prompt || '').trim();
        if (prompt) {
            return this.submit(prompt, recordId);
        }
        if (recordId && recordId.startsWith(ACCOUNT_PREFIX)) {
            this.drillStack = [];
            return this._request({
                key: 'record:' + recordId,
                label: 'Brief',
                loading: 'Loading brief',
                work: async (isCurrent) => {
                    const r = await resolve({ accountName: null, recordId });
                    return this._afterResolve(r, 'Brief ' + (r.accountName || ''), isCurrent);
                }
            });
        }
        return Promise.resolve();
    }
}
