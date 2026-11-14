/**
 * customerSummaryConversation: the conversation every Customer Summary surface shares (FR2, FE-12).
 *
 * Public interface (the host sets the context and the brand; the conversation owns everything else):
 *   @api recordId            the record the surface sits on, or null. On an Account it is resolved
 *                            once: the header's Summarize button, the quick actions and the empty
 *                            state name the account, and questions run with it as context.
 *   @api objectApiName       that record's object, when the host knows it.
 *   @api brand               the BrandSettings values (agentName, companyName, logoUrl, ...). The host
 *                            sets the --cs-* theme variables; this reads the names and the logo.
 *   @api sessionId           the conversation's session id. A value the host sets is kept and fires
 *                            nothing; without one, the first request makes one.
 *   @api focusComposer()     moves focus to the composer.
 *   @api ask(text, contextRecordId)  runs one composer text, with that record as its context.
 *   @api summarize(recordId) briefs the account with that Id.
 *   @api density             'compact' (the default) or 'comfortable' (the rail); anything else is
 *                            compact. Every answer card is drawn at this density.
 *   @api sessionsOpen        true shows the sessions control open (the FE-15 rail reuses it); the
 *                            header's History button opens and closes it too.
 *   event sessionchange      detail { sessionId }: fired whenever the session id changes here,
 *                            including when an earlier conversation is reopened or a new one started.
 *
 * Sessions (FE-22): the History button lists this account's earlier conversations, newest first
 * (CustomerSummaryHistory.listSessions). Reopening one loads its turns in order (getSession), as
 * text, since memory keeps no cards; it sets sessionId and fires sessionchange. "New conversation"
 * starts a clean thread with a new id. An empty list, a failed load and a conversation whose account
 * the user can no longer see each say so in one sentence.
 *
 * Scope chip (FE-22): above the composer, "About <account>" (or "About this record") with a button
 * to ask the whole org instead, or "Whole org" with a button to summarize an account. A whole-org
 * question goes to explore with contextRecordId null. The quick actions and a host ask with a record
 * keep their record whatever the chip says.
 *
 * Cards (FE-22): an answer, a summary, a resolver notice and a drill that carry cards draw them with
 * c-customer-summary-card, in place of their text rendering; with no cards they render as before.
 * The resolver's cards arrive as JSON text and the others as a list; unreadable cards leave the text.
 * cardopen drills here by the Id it carries (never an href); cardask is asked like a follow-up, and
 * a related object on a drill's record card drills to its rows. cardchoose and cardaction on any
 * other card are not handled here: they bubble out to the host. An AMBIGUOUS resolve keeps its
 * candidate buttons.
 *
 * Write actions (FE-14, FR2; docs/research/fr2-action-cards.md). What this adds to the interface:
 *   Calls (CustomerSummaryPanelController, BE-27): draftFromText({ accountId, text }),
 *     draftAction({ actionType, accountId, inputJson }), commitAction({ draftJson }) and
 *     undoAction({ undoToken }). Nothing is written before Confirm, and Confirm is the only commit.
 *   What leads to a draft: on an Account, the quick actions "Create a follow-up" (draftAction
 *     create_task) and "Log a call" (draftAction log_call), each with inputJson '{}'. A composer text
 *     (typed, or spoken into the composer by the mic) whose first real word is an action verb, with an
 *     account in view and the scope chip not on the whole org, calls draftFromText first: the same
 *     pre-check as CustomerSummaryActionCatalog.looksLikeAction (BE-22's two word lists), so a question
 *     makes no draft call. NOT_AN_ACTION, or a reply that is not a draft, goes down the normal ask path
 *     (explore). ERROR is the error turn. The account: the page's account, else the briefed account
 *     when the surface sits on no record; a host ask with a record uses that record if it is an Account.
 *   Turns: kind 'actionDraft' holds BE-39's actionDraft card and kind 'actionResult' its actionResult
 *     card, each drawn by c-customer-summary-card with action-mode set ('open', 'busy' or 'closed'), so
 *     the draft's fields are editable there. No other card shape; a reply without its card is text.
 *   Events from those cards, handled here and still bubbling out to the host:
 *     cardedit { cardKey, fieldKey, value }  drafts again in place with draftAction: the draft's
 *       inputJson with that field's words laid over it (new words for a contact or an opportunity drop
 *       the one it had). The card is busy, Confirm disabled, until the new draft is in.
 *     cardchoose on a draft field  drafts again with that record's Id (contactId or opportunityId).
 *     cardaction 'confirm'  commitAction once with { action, accountId, inputJson } from the draft, only
 *       when the draft is READY; the card is busy while it runs and a second Confirm is ignored. OK: the
 *       draft closes and an actionResult turn follows. REFUSED, ERROR or a failed call: the error turn
 *       with the plain-English message (the fixed ERROR line for a failed call), and the draft stays open.
 *     cardaction 'cancel'  closes the draft: "Cancelled. Nothing was saved." Nothing is called.
 *     cardaction 'edit'  the card moves focus to the first field to fill; nothing is called.
 *     cardaction 'open', and a record link on a result  navigate to the record's page (NavigationMixin,
 *       standard__recordPage, by Id; no href). A link on a draft drills, as on any card.
 *     cardaction 'undo'  undoAction with the result's token. Undo is offered for 15 s after an update
 *       (the result carries an undoToken); then it is taken off the card. OK: a "Change undone" result
 *       turn follows. The timers stop when the conversation is removed.
 *
 * Requests: every entry point (composer, chip, follow-up, candidate, Summarize, drill, the host's
 * ask and summarize) goes through _request. The latest wins: each carries a token, and a reply
 * whose token is no longer the latest is dropped. A repeat of the request in flight is ignored.
 * The calls are CustomerSummaryPanelController's ask, brief and explorer paths, unchanged.
 *
 * Text: model text is never markup. Answers render as runs (**strong**, *em*, plain) bound as text.
 *
 * Keys: the composer stops every key from reaching the page, so Lightning's single-key shortcuts
 * don't fire while typing, except Esc and Cmd/Ctrl-K, which the host handles. During an IME
 * composition Esc stays here too: it ends the composition and closes nothing. A result table and
 * a brief section's lines are one Tab stop each, with the arrow keys, Home and End inside.
 */
import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import resolve from '@salesforce/apex/CustomerSummaryPanelController.resolve';
import getBrief from '@salesforce/apex/CustomerSummaryPanelController.getBrief';
import explore from '@salesforce/apex/CustomerSummaryPanelController.explore';
import drill from '@salesforce/apex/CustomerSummaryPanelController.drill';
import history from '@salesforce/apex/CustomerSummaryPanelController.history';
import sources from '@salesforce/apex/CustomerSummaryPanelController.sources';
import draftAction from '@salesforce/apex/CustomerSummaryPanelController.draftAction';
import draftFromText from '@salesforce/apex/CustomerSummaryPanelController.draftFromText';
import commitAction from '@salesforce/apex/CustomerSummaryPanelController.commitAction';
import undoAction from '@salesforce/apex/CustomerSummaryPanelController.undoAction';
import listSessions from '@salesforce/apex/CustomerSummaryHistory.listSessions';
import getSession from '@salesforce/apex/CustomerSummaryHistory.getSession';

const BRIEF_COMMAND = /^\/brief\s+/i;
const ACCOUNT_OBJECT = 'Account';
const ACCOUNT_PREFIX = '001';
const HISTORY_TURNS = 5;
// The write actions' quick actions (FE-14), shown on an Account.
const ACTION_CHIPS_ENABLED = true;
// A quick action that drafts a write: its action (CustomerSummaryActionCatalog) and its label.
const ACTION_CHIPS = {
    followup: { action: 'create_task', label: 'Create a follow-up' },
    call: { action: 'log_call', label: 'Log a call' }
};
// The pre-check draftFromText runs (CustomerSummaryActionCatalog, BE-22's lists, kept as they ran): skip the
// filler words, then test the first word left. A verb anywhere else ("Which open deals...") is a question.
const ACTION_FILLER = new Set(['uh', 'um', 'so', 'ok', 'okay', 'hey', 'please', 'can', 'could', 'would', 'you', 'i', 'need', 'to', 'want', "let's"]);
const ACTION_VERBS = new Set(['create', 'add', 'schedule', 'set', 'book', 'log', 'remind', 'update', 'change', 'open', 'push', 'move', 'make']);
// The draft statuses that carry a draft card. NOT_AN_ACTION and ERROR carry none.
const DRAFT_STATUSES = new Set(['READY', 'NEEDS_INPUT', 'REFUSED']);
// A draft field's API name to the input key draftAction reads (CustomerSummaryActions). An update's other fields
// are its changes, by API name; the record an update changes ('Id') is its contact or opportunity.
const FIELD_INPUT = {
    Subject: 'subject',
    Description: 'description',
    ActivityDate: 'dueDate',
    StartDateTime: 'startDateTime',
    EndDateTime: 'endDateTime',
    Priority: 'priority',
    WhoId: 'contact',
    ContactId: 'contact'
};
const UNDO_MS = 15000;
const CANCELLED_TEXT = 'Cancelled. Nothing was saved.';
// An 18-character record Id inside a line of text, e.g. an AMBIGUOUS candidate line.
const ID_IN_LINE = /(^|[^A-Za-z0-9])([0-9][0-9A-Za-z]{17})(?![A-Za-z0-9])/;
// The record Id Apex puts at the end of a brief line that describes one record (CustomerSummarySection.withId).
const RECORD_ID_AT_END = / — ([0-9][0-9A-Za-z]{17})$/;
const ID_CHECKSUM = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ012345';
const NAME_FIELDS = ['Name', 'CaseNumber', 'Subject'];
// The controller's fixed ERROR line; shown when a failure carries no handled text, and for every failed drill.
const ERROR_TEXT = "I couldn't finish that right now. Try again in a minute.";
// The thread follows new turns while the reader is within this many px of the bottom.
const PIN_SLACK_PX = 24;
// **strong** or *em*; an em run starts with a non-space, so '5 * 3' stays plain.
const RUN = /\*\*([^*\n]+)\*\*|\*([^*\s\n][^*\n]*)\*/g;
const ROVE_STEP = { ArrowDown: 1, ArrowRight: 1, ArrowUp: -1, ArrowLeft: -1 };
const SESSION_LIMIT = 20;
const SESSIONS_NO_ACCOUNT = 'Open or summarize an account to see your earlier conversations about it.';
const SESSIONS_LOADING = 'Loading earlier conversations.';
const SESSIONS_FAILED = "Couldn't load your earlier conversations. Try again in a minute.";
const SESSION_HIDDEN = "That conversation can't be opened: you can no longer see its account.";
const SESSION_FAILED = "Couldn't open that conversation. Try again in a minute.";

/**
 * One exchange in the thread. kind is one of 'text', 'ambiguous', 'brief', 'explore',
 * 'actionDraft' or 'actionResult'. The action kinds carry their one card in cards, the card's
 * actionMode ('open', 'busy', 'closed'), a note under it, and the draft ({ action, accountId,
 * inputJson, status }) or the result ({ recordId, objectName, undoToken }).
 * @typedef {{ key: string, kind: string, question: string, isError: boolean }} Turn
 */

/** True when the first word that is not filler is an action verb: the text is worth a draft call. */
function looksLikeAction(text) {
    const cleaned = String(text || '')
        .toLowerCase()
        .replace(/’/g, "'")
        .replace(/[,:;.!?"]/g, ' ');
    const word = cleaned.split(/\s+/).find((w) => w && !ACTION_FILLER.has(w));
    return !!word && ACTION_VERBS.has(word);
}

/** The draft card a draft reply carries, or null when the reply is not a draft. */
function draftCardOf(d) {
    if (!d || typeof d !== 'object' || !DRAFT_STATUSES.has(d.status)) {
        return null;
    }
    return cardsOf(d.cards).find((c) => c.type === 'actionDraft') || null;
}

function inputOf(json) {
    try {
        const input = JSON.parse(json || '{}');
        return input && typeof input === 'object' && !Array.isArray(input) ? input : {};
    } catch (e) {
        return {};
    }
}

/** Removes every key that matches one of names, whatever its case (the server reads keys lowercased). */
function dropKeys(input, names) {
    const lower = names.map((n) => n.toLowerCase());
    Object.keys(input).forEach((k) => {
        if (lower.includes(k.toLowerCase())) {
            delete input[k];
        }
    });
}

/** The input key a draft field's words go to; 'changes' for an update's change; null for none. */
function inputKeyOf(action, fieldKey) {
    if (fieldKey === 'Id') {
        return action === 'update_contact' ? 'contact' : action === 'update_opportunity' ? 'opportunity' : null;
    }
    if (FIELD_INPUT[fieldKey]) {
        return FIELD_INPUT[fieldKey];
    }
    return String(action || '').startsWith('update_') && fieldKey !== 'changes' ? 'changes' : null;
}

/**
 * The draft's input with one field's new words laid over it; null when the field is not one a draft
 * takes words for. New words for a contact or an opportunity drop the Id it had, since an Id wins.
 */
function withWords(draft, fieldKey, value) {
    const key = inputKeyOf(draft.action, fieldKey);
    if (!key) {
        return null;
    }
    const input = inputOf(draft.inputJson);
    if (key === 'changes') {
        const changes = { ...(input.changes && typeof input.changes === 'object' ? input.changes : {}) };
        dropKeys(changes, [fieldKey]);
        if (value) {
            changes[fieldKey] = value;
        }
        input.changes = changes;
        return input;
    }
    dropKeys(input, key === 'contact' || key === 'opportunity' ? [key, key + 'Id'] : [key]);
    if (value) {
        input[key] = value;
    }
    return input;
}

/** The draft's input with a chosen record set by Id for its field; null for a field with no record. */
function withChoice(draft, fieldKey, recordId) {
    const key = inputKeyOf(draft.action, fieldKey);
    if (!recordId || (key !== 'contact' && key !== 'opportunity')) {
        return null;
    }
    const input = inputOf(draft.inputJson);
    dropKeys(input, [key, key + 'Id']);
    input[key + 'Id'] = recordId;
    return input;
}

/** A result card's controls without Undo, once its 15 s are up or it was used. */
function withoutUndo(card) {
    return { ...card, controls: (card.controls || []).filter((k) => k && k.key !== 'undo') };
}

function summaryState(open) {
    return {
        summaryOpen: open,
        summaryExpanded: String(open),
        summaryIcon: open ? 'utility:chevrondown' : 'utility:chevronright',
        restClass: open ? 'abp-pre abp-agent-text slds-m-top_xx-small' : 'abp-pre abp-agent-text slds-m-top_xx-small slds-hide'
    };
}

const BADGE_CLASS = {
    OK: 'slds-theme_success',
    ERROR: 'slds-theme_error'
};

/**
 * The panel's one fixed sentence for every failed request. Platform text ("Disconnected or Canceled") and
 * Apex messages never reach the rep: the controllers already return ERROR_TEXT for anything unexpected, and
 * the one deliberate message (a drill's ExploreException) is already replaced by the drill's own onError.
 */
function errorText() {
    return ERROR_TEXT;
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

/** True for an 18-character Salesforce Id whose last three characters are its case checksum. */
function isRecordId(value) {
    if (!/^[0-9A-Za-z]{18}$/.test(value || '')) {
        return false;
    }
    let suffix = '';
    for (let chunk = 0; chunk < 3; chunk++) {
        let flags = 0;
        for (let i = 0; i < 5; i++) {
            const c = value.charAt(chunk * 5 + i);
            if (c >= 'A' && c <= 'Z') {
                flags += 1 << i;
            }
        }
        suffix += ID_CHECKSUM.charAt(flags);
    }
    return suffix === value.slice(15);
}

/**
 * A brief section line as the rep reads it, and the record it drills to. Only a trailing ' — <Id>'
 * that is a real record Id drills: it is cut from the text, indent kept. Anything else, an
 * Id-shaped number included, stays whole and drills nowhere.
 */
function briefLine(line) {
    const end = RECORD_ID_AT_END.exec(line);
    if (end && isRecordId(end[1]) && line.slice(0, end.index).trim()) {
        return { id: end[1], text: line.slice(0, end.index) };
    }
    return { id: null, text: line };
}

/** Text as runs: **strong**, *em* and plain, each bound as text. */
function toRuns(text) {
    const s = text || '';
    const runs = [];
    let last = 0;
    let m;
    RUN.lastIndex = 0;
    while ((m = RUN.exec(s)) !== null) {
        if (m.index > last) {
            runs.push({ text: s.slice(last, m.index) });
        }
        runs.push(m[1] !== undefined ? { text: m[1], strong: true } : { text: m[2], em: true });
        last = RUN.lastIndex;
    }
    if (last < s.length) {
        runs.push({ text: s.slice(last) });
    }
    return runs.map((r, i) => ({ key: 'r' + i, ...r }));
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

function isComposing(event) {
    return event.isComposing || event.keyCode === 229;
}

/**
 * The cards on a reply: a list as it is, JSON text (the resolver's) parsed. Anything unreadable is
 * no cards, so the reply's text renders as before.
 */
function cardsOf(value) {
    let list = value;
    if (typeof value === 'string') {
        try {
            list = JSON.parse(value);
        } catch (e) {
            return [];
        }
    }
    return Array.isArray(list) ? list.filter((c) => c && typeof c === 'object' && !Array.isArray(c)) : [];
}

function timeOf(value) {
    const t = Date.parse(value || '');
    return Number.isNaN(t) ? 0 : t;
}

function newSessionId() {
    return 'cs-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 8);
}

export default class CustomerSummaryConversation extends NavigationMixin(LightningElement) {
    @api brand = null;

    draft = '';
    pending = false;
    pendingQuestion = '';
    turns = [];
    drillStack = [];
    sourceList = [];
    selectedKeys = [];
    pageAccount = null;
    briefedAccount = null;
    historyAccount = null;
    historyItems = [];
    notice = '';
    liveMessage = '';
    // Every accordion starts collapsed; never reassigned, so a rerender keeps open sections open.
    closedSections = [];
    // The two tools headings are native disclosures (FE-26); both start closed.
    toolsOpen = { include: false, history: false };

    _recordId = null;
    _objectApiName = null;
    _sessionId = null;
    _connected = false;
    _lastContextId;
    _seq = 0;
    _requestId = 0;
    _inFlightKey = null;
    _drillOrigin = null;
    _focusAfterRender = null;
    _scrollAfterRender = null;
    _pinned = true;
    _lastTop = 0;
    _voiceBase = null;
    _density = 'compact';
    _sessionsOpen = false;
    _sessionsState = 'idle';
    _sessionsAccountId = null;
    _sessionsNote = '';
    _sessionRows = [];
    _scopeOrg = false;
    _focusCardAfterRender = null;
    // Write actions (FE-14): a commit in flight, each draft's latest re-draft, and each result's Undo timer.
    _committing = false;
    _redraftSeq = {};
    _undoTimers = {};

    // ------------------------------------------------------------ public interface

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value || null;
        this._syncContext();
    }

    @api
    get objectApiName() {
        return this._objectApiName;
    }
    set objectApiName(value) {
        this._objectApiName = value || null;
        this._syncContext();
    }

    @api
    get sessionId() {
        return this._sessionId;
    }
    set sessionId(value) {
        this._sessionId = value || null;
    }

    @api
    get density() {
        return this._density;
    }
    set density(value) {
        this._density = value === 'comfortable' ? 'comfortable' : 'compact';
    }

    @api
    get sessionsOpen() {
        return this._sessionsOpen;
    }
    set sessionsOpen(value) {
        const open = !!value;
        if (open === this._sessionsOpen) {
            return;
        }
        this._sessionsOpen = open;
        if (open) {
            this._loadSessions();
        }
    }

    @api
    focusComposer() {
        const composer = this._composer();
        if (composer) {
            composer.focus();
        }
    }

    /** Runs one composer text with contextRecordId as its context: the host's message-channel prompt. */
    @api
    ask(text, contextRecordId) {
        return this.submit(text, contextRecordId);
    }

    /** Briefs the account with this Id: the host's message-channel Account Id. */
    @api
    summarize(recordId) {
        if (!recordId) {
            return Promise.resolve();
        }
        this.drillStack = [];
        return this._request({
            key: 'record:' + recordId,
            label: 'Summary',
            loading: 'Loading summary',
            work: async (isCurrent) => {
                const r = await resolve({ accountName: null, recordId });
                return this._afterResolve(r, 'Summarize ' + (r.accountName || ''), isCurrent);
            }
        });
    }

    _ensureSession() {
        if (this._sessionId) {
            return;
        }
        this._setSession(newSessionId());
    }

    // ------------------------------------------------------------ wires and lifecycle

    @wire(sources)
    wiredSources({ data }) {
        if (data) {
            this.sourceList = data.map((s) => ({ key: s.key, title: s.title }));
        }
    }

    connectedCallback() {
        this._connected = true;
        this._syncContext();
    }

    disconnectedCallback() {
        this._connected = false;
        Object.keys(this._undoTimers).forEach((key) => clearTimeout(this._undoTimers[key]));
        this._undoTimers = {};
    }

    renderedCallback() {
        this._syncRoving();
        if (this._focusCardAfterRender) {
            const { card, ref } = this._focusCardAfterRender;
            this._focusCardAfterRender = null;
            const host = Array.from(this.template.querySelectorAll('c-customer-summary-card')).find((c) => c.dataset.card === card);
            if (!(host && host.focusLink(ref))) {
                this.focusComposer();
            }
        }
        if (this._focusAfterRender) {
            const target = this.template.querySelector(this._focusAfterRender);
            this._focusAfterRender = null;
            if (target) {
                target.focus();
            }
        }
        if (this._scrollAfterRender) {
            const selector = this._scrollAfterRender;
            this._scrollAfterRender = null;
            const target = this.template.querySelector(selector);
            if (target && target.scrollIntoView && this._pinned) {
                target.scrollIntoView({ block: selector === '.abp-pending' ? 'nearest' : 'start' });
                const body = this._body();
                this._lastTop = body ? body.scrollTop : 0;
            }
        }
    }

    // ------------------------------------------------------------ brand

    get agentName() {
        return this.brand && this.brand.agentName ? this.brand.agentName : '';
    }

    get hasBrand() {
        return !!this.brand;
    }

    get logoUrl() {
        return this.brand && this.brand.logoUrl ? this.brand.logoUrl : '';
    }

    get logoAlt() {
        return this.brand && this.brand.companyName ? this.brand.companyName + ' logo' : '';
    }

    /** The mic's agent name; undefined leaves the mic's own default. */
    get micAgentName() {
        return this.agentName || undefined;
    }

    get replyLabel() {
        return this.agentName || 'Agent';
    }

    // ------------------------------------------------------------ page context

    get isAccountPage() {
        const id = this._recordId;
        return !!id && (this._objectApiName === ACCOUNT_OBJECT || id.startsWith(ACCOUNT_PREFIX));
    }

    /** Context for a question: the page's record, then the briefed account. */
    get contextRecordId() {
        return this._recordId || (this.briefedAccount ? this.briefedAccount.id : null);
    }

    get accountName() {
        return this.pageAccount ? this.pageAccount.name : '';
    }

    _syncContext() {
        if (!this._connected) {
            return;
        }
        const id = this._recordId;
        if (id === this._lastContextId) {
            return;
        }
        this._lastContextId = id;
        this.pageAccount = null;
        this._scopeOrg = false;
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
                    this._loadSessions();
                }
            })
            .catch(() => {
                // The Summarize button still works; it resolves again on click.
            });
    }

    get briefButtonLabel() {
        return this.pageAccount ? 'Summarize ' + this.pageAccount.name : 'Summarize this account';
    }

    // ------------------------------------------------------------ empty state and quick actions

    get showEmpty() {
        return !this.turns.length && !this.pending;
    }

    get emptyTitle() {
        const agent = this.agentName;
        if (this.isAccountPage) {
            const account = this.accountName || 'this account';
            return agent ? 'Ask ' + agent + ' about ' + account : 'Ask about ' + account;
        }
        return agent ? 'Ask ' + agent + ' anything' : 'Ask anything';
    }

    get emptyText() {
        const company = this.brand && this.brand.companyName;
        return (
            'Ask anything about ' + (company ? company + "'s" : 'your') +
            ' data, or type /brief and an account name. Cmd/Ctrl-K focuses this box.'
        );
    }

    get suggestions() {
        const name = this.accountName;
        const list = this.isAccountPage
            ? ['Who are the key contacts at ' + (name || 'this account') + '?', 'What changed on ' + (name || 'this account') + ' this month?']
            : ['Which accounts have deals closing this quarter?', 'Which open cases are high priority?'];
        return list.map((text, i) => ({ key: 's' + i, text }));
    }

    /**
     * On an Account: Summarize, Open deals, Recent activity, then the write actions Create a follow-up and
     * Log a call. Elsewhere: Ask anything, and the last account's summary.
     */
    get quickChips() {
        const chips = [];
        if (this.isAccountPage) {
            chips.push({ key: 'summarize', label: 'Summarize' });
            chips.push({ key: 'deals', label: 'Open deals' });
            chips.push({ key: 'activity', label: 'Recent activity' });
            if (ACTION_CHIPS_ENABLED) {
                chips.push({ key: 'followup', label: ACTION_CHIPS.followup.label });
                chips.push({ key: 'call', label: ACTION_CHIPS.call.label });
            }
        } else {
            chips.push({ key: 'ask', label: 'Ask anything' });
            if (this.briefedAccount) {
                chips.push({ key: 'last', label: 'Summarize ' + this.briefedAccount.name });
            }
        }
        return chips;
    }

    handleQuick(event) {
        const name = this.accountName || 'this account';
        switch (event.currentTarget.dataset.key) {
            case 'summarize':
                return this.handleBriefThisAccount();
            case 'deals':
                return this.submit('Which open deals does ' + name + ' have?', this._recordId);
            case 'activity':
                return this.submit('What is the recent activity on ' + name + '?', this._recordId);
            case 'followup':
                return this._startDraft(ACTION_CHIPS.followup);
            case 'call':
                return this._startDraft(ACTION_CHIPS.call);
            case 'last':
                return this._briefAccount(this.briefedAccount);
            default:
                this.focusComposer();
                return Promise.resolve();
        }
    }

    _prefill(text) {
        this._setDraft(text);
        this.focusComposer();
        return Promise.resolve();
    }

    /** The composer's value is set here, not bound: a textarea takes no value attribute. */
    _setDraft(text) {
        this.draft = text;
        const composer = this._composer();
        if (composer) {
            composer.value = text;
            this._grow(composer);
        }
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

    get includeExpanded() {
        return String(this.toolsOpen.include);
    }

    get includeClosed() {
        return !this.toolsOpen.include;
    }

    get includeIcon() {
        return this.toolsOpen.include ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get historyExpanded() {
        return String(this.toolsOpen.history);
    }

    get historyClosed() {
        return !this.toolsOpen.history;
    }

    get historyIcon() {
        return this.toolsOpen.history ? 'utility:chevrondown' : 'utility:chevronright';
    }

    handleToolToggle(event) {
        const tool = event.currentTarget.dataset.tool;
        this.toolsOpen = { ...this.toolsOpen, [tool]: !this.toolsOpen[tool] };
    }

    handleChip(event) {
        const key = event.currentTarget.dataset.key;
        this.selectedKeys = this.selectedKeys.includes(key)
            ? this.selectedKeys.filter((k) => k !== key)
            : [...this.selectedKeys, key];
    }

    // ------------------------------------------------------------ composer

    get sendDisabled() {
        return !this.draft || !this.draft.trim();
    }

    handleComposerInput(event) {
        this.draft = event.target.value;
        this._grow(event.target);
    }

    handleComposerKeydown(event) {
        const composing = isComposing(event);
        // Esc and the hotkey belong to the host, unless an IME composition is open: then Esc ends it, nothing more.
        if (!composing && (event.key === 'Escape' || isHotkey(event))) {
            return;
        }
        event.stopPropagation();
        if (event.key === 'Enter' && !event.shiftKey && !composing) {
            event.preventDefault();
            this._submitDraft();
        }
    }

    handleComposerKeyOther(event) {
        event.stopPropagation();
    }

    handleSend() {
        this._submitDraft();
    }

    handleRecordingState(event) {
        const recording = !!(event.detail && event.detail.recording);
        this._voiceBase = recording ? (this.draft || '').trim() : null;
    }

    /** The mic's transcript fills the composer after what was typed. It never sends. */
    handleTranscript(event) {
        const transcript = ((event.detail && event.detail.transcript) || '').trim();
        if (this._voiceBase === null) {
            this._voiceBase = (this.draft || '').trim();
        }
        this._setDraft([this._voiceBase, transcript].filter(Boolean).join(' '));
    }

    _grow(box) {
        if (!box || !box.style) {
            return;
        }
        // The stylesheet caps the height at about six lines; past that the box scrolls.
        box.style.height = 'auto';
        if (box.scrollHeight) {
            box.style.height = box.scrollHeight + 'px';
        }
    }

    _submitDraft() {
        const text = (this.draft || '').trim();
        if (!text) {
            return;
        }
        this._setDraft('');
        this._voiceBase = null;
        // A send from the reader follows the thread again.
        this._pinned = true;
        this.submit(text);
    }

    _composer() {
        return this.template.querySelector('.abp-composer');
    }

    _body() {
        return this.template.querySelector('.abp-body');
    }

    // ------------------------------------------------------------ thread and scrolling

    get hasTurns() {
        return this.turns.length > 0;
    }

    get threadTurns() {
        const agent = this.replyLabel;
        return this.turns.map((t) => ({
            ...t,
            label: t.isError ? 'Error' : agent,
            replyClass: t.isError ? 'abp-reply abp-reply-error' : 'abp-reply'
        }));
    }

    handleBodyScroll(event) {
        const body = event.currentTarget;
        const top = body.scrollTop;
        if (body.scrollHeight - top - body.clientHeight <= PIN_SLACK_PX) {
            this._pinned = true;
        } else if (top < this._lastTop - 2) {
            // The reader scrolled up: new turns no longer pull the thread down.
            this._pinned = false;
        }
        this._lastTop = top;
    }

    // ------------------------------------------------------------ roving tabindex

    /** Each [data-roving] group keeps exactly one item at tabindex 0. */
    _syncRoving() {
        this.template.querySelectorAll('[data-roving]').forEach((group) => {
            const items = Array.from(group.querySelectorAll('[data-roving-item]'));
            if (!items.length) {
                return;
            }
            let current = items.findIndex((i) => i.getAttribute('tabindex') === '0');
            if (current < 0) {
                current = 0;
            }
            items.forEach((item, n) => {
                const value = n === current ? '0' : '-1';
                if (item.getAttribute('tabindex') !== value) {
                    item.setAttribute('tabindex', value);
                }
            });
        });
    }

    handleRovingKeydown(event) {
        const step = ROVE_STEP[event.key];
        if (step === undefined && event.key !== 'Home' && event.key !== 'End') {
            return;
        }
        const items = Array.from(event.currentTarget.querySelectorAll('[data-roving-item]'));
        const index = items.indexOf(event.target);
        if (index < 0) {
            return;
        }
        event.preventDefault();
        let next;
        if (event.key === 'Home') {
            next = 0;
        } else if (event.key === 'End') {
            next = items.length - 1;
        } else {
            next = Math.min(items.length - 1, Math.max(0, index + step));
        }
        items.forEach((item, n) => item.setAttribute('tabindex', n === next ? '0' : '-1'));
        items[next].focus();
    }

    handleRovingFocusin(event) {
        const items = Array.from(event.currentTarget.querySelectorAll('[data-roving-item]'));
        const index = items.indexOf(event.target);
        if (index >= 0) {
            items.forEach((item, n) => item.setAttribute('tabindex', n === index ? '0' : '-1'));
        }
    }

    // ------------------------------------------------------------ the one request path

    /**
     * Runs one request. The latest wins: work gets isCurrent() and checks it after every await,
     * so a superseded reply changes nothing and makes no further call. A repeat of the request
     * in flight (same key) is ignored. Resolves to the short line the live region announces.
     * onError(text) handles a failure itself; a string it returns is announced in place of text.
     */
    _request({ key, label, loading, work, onError, keepSession }) {
        if (this.pending && key === this._inFlightKey) {
            return Promise.resolve();
        }
        if (!keepSession) {
            this._ensureSession();
        }
        this._requestId += 1;
        const token = this._requestId;
        const isCurrent = () => token === this._requestId;
        this._inFlightKey = key;
        this.pending = true;
        this.pendingQuestion = key.startsWith('drill:') ? '' : label;
        this.notice = '';
        this.liveMessage = loading;
        this._scrollAfterRender = '.abp-pending';
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
                let announced = text;
                if (onError) {
                    announced = onError(text) || text;
                } else {
                    this._push({ kind: 'text', isText: true, isError: true, question: label, text });
                }
                this.liveMessage = announced;
            })
            .finally(() => {
                if (isCurrent()) {
                    this.pending = false;
                    this.pendingQuestion = '';
                    this._inFlightKey = null;
                }
            });
    }

    get hasPendingQuestion() {
        return !!this.pendingQuestion;
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
                loading: 'Loading summary for ' + name,
                work: async (isCurrent) => {
                    const r = await resolve({ accountName: name, recordId: null });
                    return this._afterResolve(r, q, isCurrent);
                }
            });
        }
        // The chip's whole-org scope drops the page's context; a record the caller passes is kept.
        const context = contextRecordId || (this._scopeOrg ? null : this.contextRecordId) || null;
        // A text that names an action, with an account in view, is drafted first (FE-14).
        const actionAccount = looksLikeAction(q) ? this._actionAccountFor(contextRecordId) : null;
        return this._request({
            key: 'ask:' + q,
            label: q,
            loading: actionAccount ? 'Drafting' : 'Loading answer',
            work: async (isCurrent) => {
                if (actionAccount) {
                    const d = await draftFromText({ accountId: actionAccount, text: q });
                    if (!isCurrent()) {
                        return null;
                    }
                    if (draftCardOf(d)) {
                        return this._showDraft(d, q);
                    }
                    if (d && d.status === 'ERROR') {
                        const text = d.message || ERROR_TEXT;
                        this._push({ kind: 'text', isText: true, isError: true, question: q, text });
                        return text;
                    }
                    // NOT_AN_ACTION, or a reply that is not a draft: the question goes down the ask path.
                }
                const r = await explore({ question: q, contextRecordId: context, historyJson: this._historyJson() });
                if (!isCurrent()) {
                    return null;
                }
                this._push(this._exploreTurn(r, q));
                return r.status === 'ERROR' ? r.answer : 'Answer ready';
            }
        });
    }

    // ------------------------------------------------------------ write actions (FE-14)

    /** The account a typed action goes on: a passed Account, else the account in view, unless the chip says whole org. */
    _actionAccountFor(passed) {
        if (passed) {
            return String(passed).startsWith(ACCOUNT_PREFIX) ? passed : null;
        }
        return this._scopeOrg ? null : this._accountInView();
    }

    /** The page's account, else the briefed account when the surface sits on no record. */
    _accountInView() {
        if (this.pageAccount) {
            return this.pageAccount.id;
        }
        if (this.isAccountPage) {
            return this._recordId;
        }
        return !this._recordId && this.briefedAccount ? this.briefedAccount.id : null;
    }

    /** A quick action that drafts a write: draftAction with no fields yet. Nothing is written. */
    _startDraft(chip) {
        const accountId = this._accountInView();
        if (!accountId) {
            this.focusComposer();
            return Promise.resolve();
        }
        this._pinned = true;
        this.drillStack = [];
        return this._request({
            key: 'draft:' + chip.action,
            label: chip.label,
            loading: 'Drafting',
            work: async (isCurrent) => {
                const d = await draftAction({ actionType: chip.action, accountId, inputJson: '{}' });
                if (!isCurrent()) {
                    return null;
                }
                if (draftCardOf(d)) {
                    return this._showDraft(d, chip.label);
                }
                const text = (d && d.status === 'ERROR' && d.message) || ERROR_TEXT;
                this._push({ kind: 'text', isText: true, isError: true, question: chip.label, text });
                return text;
            }
        });
    }

    _showDraft(d, question) {
        const card = draftCardOf(d);
        this._push({
            kind: 'actionDraft',
            isAction: true,
            isActionDraft: true,
            isActionResult: false,
            question,
            draft: { action: d.action, accountId: d.accountId, inputJson: d.inputJson || '{}', status: d.status },
            cards: [{ key: 'k0', cardId: 'k0', card }],
            hasCards: true,
            actionMode: 'open',
            note: '',
            historyAnswer: card.text || ''
        });
        return d.status === 'READY' ? 'Draft ready: ' + (card.title || 'confirm or edit') : (card.title || 'Draft') + ': ' + (d.status === 'REFUSED' ? 'not allowed' : 'fields to fill');
    }

    _setTurn(key, patch) {
        this.turns = this.turns.map((t) => (t.key === key ? { ...t, ...patch } : t));
    }

    _turnByKey(key) {
        return this.turns.find((t) => t.key === key) || null;
    }

    /** The action turn a card event came from, found by the card host's data-card (never by cardKey). */
    _actionTurnOf(event) {
        const host = event.target;
        const card = host && host.dataset ? host.dataset.card : null;
        if (!card) {
            return null;
        }
        return this.turns.find((t) => t.isAction && (t.cards || []).some((c) => c.cardId === card)) || null;
    }

    /** Drafts again in place with the new input; the card is busy, so Confirm waits, until it is in. */
    _redraft(turn, input) {
        const key = turn.key;
        const seq = (this._redraftSeq[key] || 0) + 1;
        this._redraftSeq[key] = seq;
        const draft = turn.draft;
        this._setTurn(key, { actionMode: 'busy', note: '' });
        this.liveMessage = 'Updating the draft';
        return Promise.resolve()
            .then(() => draftAction({ actionType: draft.action, accountId: draft.accountId, inputJson: JSON.stringify(input) }))
            .then((d) => {
                if (this._redraftSeq[key] !== seq) {
                    return;
                }
                const card = draftCardOf(d);
                if (!card) {
                    const text = (d && d.message) || ERROR_TEXT;
                    this._setTurn(key, { actionMode: 'open', note: text });
                    this.liveMessage = text;
                    return;
                }
                this._setTurn(key, {
                    draft: { action: d.action || draft.action, accountId: d.accountId || draft.accountId, inputJson: d.inputJson || '{}', status: d.status },
                    cards: [{ key: 'k0', cardId: key + '-k0', card }],
                    actionMode: 'open',
                    note: '',
                    historyAnswer: card.text || ''
                });
                this.liveMessage = d.status === 'READY' ? 'Draft ready to confirm' : 'Draft updated: fields to fill';
            })
            .catch(() => {
                if (this._redraftSeq[key] === seq) {
                    this._setTurn(key, { actionMode: 'open', note: ERROR_TEXT });
                    this.liveMessage = ERROR_TEXT;
                }
            });
    }

    handleCardEdit(event) {
        const turn = this._actionTurnOf(event);
        const detail = event.detail || {};
        if (!turn || !turn.isActionDraft || turn.actionMode !== 'open') {
            return;
        }
        const input = withWords(turn.draft, detail.fieldKey, String(detail.value || '').trim());
        if (input) {
            this._redraft(turn, input);
        }
    }

    handleCardChoose(event) {
        const turn = this._actionTurnOf(event);
        const detail = event.detail || {};
        if (!turn || !turn.isActionDraft || turn.actionMode !== 'open') {
            return;
        }
        const input = withChoice(turn.draft, detail.fieldKey, detail.recordId);
        if (input) {
            this._redraft(turn, input);
        }
    }

    handleCardAction(event) {
        const turn = this._actionTurnOf(event);
        const control = event.detail && event.detail.control;
        if (!turn) {
            return;
        }
        if (turn.isActionDraft) {
            if (control === 'confirm') {
                this._confirm(turn);
            } else if (control === 'cancel' && turn.actionMode === 'open') {
                this._setTurn(turn.key, { actionMode: 'closed', note: CANCELLED_TEXT });
                this.liveMessage = CANCELLED_TEXT;
            }
            return;
        }
        if (control === 'open') {
            this._openRecord(turn.result.recordId, turn.result.objectName);
        } else if (control === 'undo') {
            this._undo(turn);
        }
    }

    /** Confirm: commitAction once, with the draft's action, account and input. Only a READY draft. */
    _confirm(turn) {
        if (this._committing || turn.actionMode !== 'open' || turn.draft.status !== 'READY') {
            return Promise.resolve();
        }
        this._committing = true;
        const key = turn.key;
        const draft = turn.draft;
        this._setTurn(key, { actionMode: 'busy', note: '' });
        this.liveMessage = 'Saving';
        const draftJson = JSON.stringify({ action: draft.action, accountId: draft.accountId, inputJson: draft.inputJson });
        return Promise.resolve()
            .then(() => commitAction({ draftJson }))
            .then((r) => {
                const card = r && r.status === 'OK' ? cardsOf(r.cards).find((c) => c.type === 'actionResult') : null;
                if (!card) {
                    this._notSaved(key, (r && r.message) || ERROR_TEXT);
                    return;
                }
                this._setTurn(key, { actionMode: 'closed' });
                this._showResult(r, card, 'Confirm');
            })
            .catch(() => this._notSaved(key, ERROR_TEXT))
            .finally(() => {
                this._committing = false;
            });
    }

    /** A refusal or a failure: the error turn says why, and the draft stays open to fix or cancel. */
    _notSaved(key, text) {
        this._setTurn(key, { actionMode: 'open' });
        this._pinned = true;
        this._push({ kind: 'text', isText: true, isError: true, question: 'Confirm', text });
        this.liveMessage = text;
    }

    _showResult(r, card, question) {
        const key = this._nextKey('t');
        this._pinned = true;
        this._push({
            key,
            kind: 'actionResult',
            isAction: true,
            isActionDraft: false,
            isActionResult: true,
            question,
            result: { recordId: r.recordId, objectName: r.objectName, undoToken: r.undoToken || null },
            cards: [{ key: 'k0', cardId: 'k0', card }],
            hasCards: true,
            actionMode: 'open',
            note: '',
            historyAnswer: card.text || ''
        });
        this.liveMessage = card.title || 'Saved';
        if (r.undoToken) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            this._undoTimers[key] = setTimeout(() => this._endUndo(key), UNDO_MS);
        }
    }

    /** Takes Undo off a result: its 15 s are up, or it was used. */
    _endUndo(key) {
        clearTimeout(this._undoTimers[key]);
        delete this._undoTimers[key];
        const turn = this._turnByKey(key);
        if (!turn || !turn.result || !turn.result.undoToken) {
            return;
        }
        this._setTurn(key, {
            result: { ...turn.result, undoToken: null },
            cards: turn.cards.map((c) => ({ ...c, card: withoutUndo(c.card) })),
            actionMode: turn.actionMode === 'busy' ? 'open' : turn.actionMode
        });
    }

    _undo(turn) {
        const token = turn.result && turn.result.undoToken;
        if (!token || turn.actionMode !== 'open') {
            return Promise.resolve();
        }
        const key = turn.key;
        this._setTurn(key, { actionMode: 'busy' });
        this.liveMessage = 'Undoing';
        return Promise.resolve()
            .then(() => undoAction({ undoToken: token }))
            .then((r) => {
                this._endUndo(key);
                const card = r && r.status === 'OK' ? cardsOf(r.cards).find((c) => c.type === 'actionResult') : null;
                if (card) {
                    this._showResult({ ...r, undoToken: null }, withoutUndo(card), 'Undo');
                    return;
                }
                const text = (r && r.message) || ERROR_TEXT;
                this._push({ kind: 'text', isText: true, isError: true, question: 'Undo', text });
                this.liveMessage = text;
            })
            .catch(() => {
                this._setTurn(key, { actionMode: 'open' });
                this._push({ kind: 'text', isText: true, isError: true, question: 'Undo', text: ERROR_TEXT });
                this.liveMessage = ERROR_TEXT;
            });
    }

    /** The record's page, by Id. Nothing is built from card text and no href is written. */
    _openRecord(recordId, objectName) {
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, objectApiName: objectName, actionName: 'view' }
        });
    }

    handleBriefThisAccount() {
        const label = this.briefButtonLabel;
        const account = this.pageAccount;
        const recordId = this._recordId;
        this.drillStack = [];
        return this._request({
            key: 'record:' + recordId,
            label,
            loading: 'Loading summary for ' + (account ? account.name : 'this account'),
            work: async (isCurrent) => {
                if (account) {
                    return this._brief(account.id, account.name, label, isCurrent);
                }
                const r = await resolve({ accountName: null, recordId });
                return this._afterResolve(r, label, isCurrent);
            }
        });
    }

    _briefAccount(account) {
        if (!account) {
            return Promise.resolve();
        }
        const label = 'Summarize ' + account.name;
        this.drillStack = [];
        return this._request({
            key: 'record:' + account.id,
            label,
            loading: 'Loading summary for ' + account.name,
            work: (isCurrent) => this._brief(account.id, account.name, label, isCurrent)
        });
    }

    handleCandidate(event) {
        const { id, label } = event.currentTarget.dataset;
        return this._request({
            key: 'record:' + id,
            label,
            loading: 'Loading summary for ' + label,
            work: async (isCurrent) => {
                const r = await resolve({ accountName: null, recordId: id });
                return this._afterResolve(r, label, isCurrent);
            }
        });
    }

    handleFollowup(event) {
        this._pinned = true;
        this.submit(event.currentTarget.dataset.text);
    }

    _nextKey(prefix) {
        this._seq += 1;
        return prefix + this._seq;
    }

    _push(turn) {
        const key = turn.key || this._nextKey('t');
        const cardList = (turn.cards || []).map((c) => ({ ...c, cardId: key + '-' + c.cardId }));
        this.turns = [...this.turns, { isError: false, ...turn, cards: cardList, key }];
        this._scrollAfterRender = '[data-turn="' + key + '"]';
    }

    /** A reply's cards as the template draws them: { cards: [{ key, cardId, card }], hasCards }. */
    _cardsOn(value) {
        const cards = cardsOf(value).map((card, i) => ({ key: 'k' + i, cardId: 'k' + i, card }));
        return { cards, hasCards: cards.length > 0 };
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
        this._push({ kind: 'text', isText: true, question: label, text: r.message, historyAnswer: r.message, ...this._cardsOn(r.cards) });
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
        return { kind: 'ambiguous', isAmbiguous: true, question: label, header: lines[0], candidates, notes, historyAnswer: r.message };
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
        this._scopeOrg = false;
        const turn = this._briefTurn(r, label, accountName);
        this._push(turn);
        this._loadHistory(this.briefedAccount);
        if (this._sessionsOpen) {
            this._loadSessions();
        }
        // With cards, the headline on screen is the summary card's title: announce that one.
        const summary = (turn.cards || []).find((c) => c.card.type === 'summary');
        return turn.verbatim ? r.message : 'Summary ready: ' + ((summary && summary.card.title) || turn.header || accountName);
    }

    _briefTurn(r, label, accountName) {
        const key = this._nextKey('t');
        const verbatim = r.status === 'NOT_FOUND' || r.status === 'ERROR';
        const answer = (r.answer || '').trim();
        const nl = answer.indexOf('\n');
        const rest = verbatim || nl < 0 ? '' : answer.substring(nl + 1).trim();
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
                    const { id, text } = briefLine(line);
                    return { key: 'l' + j, text: text === '' ? ' ' : text, drillId: id, isDrill: !!id, focusKey: key + '-' + sectionKey + '-l' + j };
                })
            };
        });
        return {
            key,
            kind: 'brief',
            isBrief: true,
            isError: r.status === 'ERROR',
            question: label,
            accountName,
            verbatim,
            message: r.message,
            messageIsError: r.status === 'ERROR',
            showMessage: verbatim || (r.status === 'EMPTY' && !!r.message && r.message !== answer),
            header: verbatim ? '' : nl >= 0 ? answer.substring(0, nl).trim() : answer,
            rest,
            restRuns: toRuns(rest),
            restId: key + '-rest',
            ...summaryState(false),
            hasSections: sections.length > 0,
            sections,
            ignoredText: r.ignored && r.ignored.length ? 'Not sections: ' + r.ignored.join(', ') : '',
            historyAnswer: verbatim ? r.message : answer,
            ...this._cardsOn(r.cards)
        };
    }

    /** Shows or hides the rest of a brief's summary. The text stays in the DOM either way. */
    handleSummaryToggle(event) {
        const key = event.currentTarget.dataset.key;
        this.turns = this.turns.map((t) => (t.key === key ? { ...t, ...summaryState(!t.summaryOpen) } : t));
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
            kind: 'explore',
            isExplore: true,
            question: q,
            isError: r.status === 'ERROR',
            answer: r.answer,
            answerRuns: toRuns(r.answer),
            tables,
            hasTrail: trail.length > 0,
            trail,
            trailLabel: 'Ran ' + trail.length + (trail.length === 1 ? ' query' : ' queries'),
            followups: (r.followups || []).map((text, i) => ({ key: 'f' + i, text })),
            hasFollowups: !!(r.followups && r.followups.length),
            historyAnswer: r.answer,
            ...this._cardsOn(r.cards)
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
        const shown = rs.shown;
        const count = rs.total > shown ? 'Showing ' + shown + ' of ' + rs.total + ' rows' : shown + (shown === 1 ? ' row' : ' rows');
        return {
            key,
            title: rs.objectName + ' · ' + count,
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
        return this.isDrilling ? 'abp-thread slds-hide' : 'abp-thread';
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
        const origin = this._drillOrigin;
        this._drillOrigin = null;
        if (origin && typeof origin === 'object') {
            // A drill from a card returns to the card's link it started from.
            this._focusCardAfterRender = origin;
            return;
        }
        this._focusAfterRender = origin ? '[data-focus="' + origin + '"]' : '.abp-composer';
    }

    handleViewRecord() {
        const top = this.drillTop;
        if (!top) {
            return;
        }
        // The conversation can sit on a stage moved out of the page's navigation context (the panel moves it onto
        // document.body), where Navigate does nothing. The panel listens for this and navigates; with no listener
        // that prevents the default, the conversation navigates itself.
        const proceed = this.dispatchEvent(
            new CustomEvent('csopenrecord', {
                detail: { recordId: top.recordId },
                bubbles: true,
                composed: true,
                cancelable: true
            })
        );
        if (!proceed) {
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
            // A failed drill shows the fixed sentence, never the platform's text.
            onError: () => {
                this.notice = ERROR_TEXT;
                return ERROR_TEXT;
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
        const drawn = this._cardsOn(d.cards);
        const cards = drawn.cards.map((c) => ({ ...c, cardId: key + '-' + c.cardId }));
        if (relatedObject) {
            return {
                key,
                recordId,
                isRecord: false,
                label: relatedObject,
                table: this._table(rs, key),
                cards,
                hasCards: drawn.hasCards,
                showTable: !drawn.hasCards
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
            hasRelated: !!(d.related && d.related.length),
            cards,
            hasCards: drawn.hasCards,
            showFields: !drawn.hasCards
        };
    }

    // ------------------------------------------------------------ card events

    /** A record link on a card: drill here by the Id the event carries. Nothing navigates by href. */
    handleCardOpen(event) {
        event.stopPropagation();
        const detail = event.detail || {};
        if (!detail.recordId) {
            return;
        }
        // A result's record link opens the record it wrote (FE-14).
        const action = this._actionTurnOf(event);
        if (action && action.isActionResult) {
            this._openRecord(detail.recordId, detail.objectName);
            return;
        }
        const host = event.target;
        const card = host && host.dataset ? host.dataset.card : null;
        const origin = card && !this.isDrilling ? { card, ref: detail.ref } : null;
        this._drill(detail.recordId, null, this.isDrilling, origin);
    }

    /**
     * A follow-up chip, or a related object on a drill's record card. The record card's related
     * items are the drill's related objects in order, so the chip's index names the object.
     */
    handleCardAsk(event) {
        event.stopPropagation();
        const text = ((event.detail && event.detail.text) || '').trim();
        if (!text) {
            return;
        }
        const top = this.drillTop;
        if (top && top.isRecord) {
            const record = (top.cards || []).map((c) => c.card).find((c) => c.type === 'record');
            const related = ((record && record.items) || []).filter((i) => i && i.kind === 'related');
            const index = related.findIndex((i) => i.label === text);
            if (index >= 0 && top.related[index]) {
                this._drill(top.recordId, top.related[index].name, true, null);
                return;
            }
        }
        this._pinned = true;
        this.submit(text);
    }

    // ------------------------------------------------------------ scope chip

    /** What a question is about when the chip says so: the account, this record, or nothing. */
    get scopeName() {
        if (this.isAccountPage) {
            return this.accountName || 'this account';
        }
        if (this._recordId) {
            return 'this record';
        }
        return this.briefedAccount ? this.briefedAccount.name : '';
    }

    get hasScopeContext() {
        return !!this.contextRecordId;
    }

    get scopeLabel() {
        return !this.hasScopeContext || this._scopeOrg ? 'Whole org' : 'About ' + this.scopeName;
    }

    get scopeSwitchLabel() {
        if (!this.hasScopeContext) {
            return 'Ask about an account';
        }
        return this._scopeOrg ? 'Ask about ' + this.scopeName : 'Ask the whole org';
    }

    handleScopeSwitch() {
        if (!this.hasScopeContext) {
            // No account yet: start a summary, which gives the questions after it their account.
            return this._prefill('/brief ');
        }
        this._scopeOrg = !this._scopeOrg;
        this.liveMessage = this._scopeOrg ? 'Questions now go to the whole org' : 'Questions now about ' + this.scopeName;
        return Promise.resolve();
    }

    // ------------------------------------------------------------ sessions

    /** The account whose conversations are listed: the open Account page's, else the last summarized. */
    get sessionsAccount() {
        if (this.isAccountPage) {
            return this.pageAccount;
        }
        return this._recordId ? null : this.briefedAccount;
    }

    get sessionsExpanded() {
        return String(this._sessionsOpen);
    }

    get sessionsHidden() {
        return !this._sessionsOpen;
    }

    get sessionsHeading() {
        const account = this.sessionsAccount;
        return account ? 'Earlier conversations about ' + account.name : 'Earlier conversations';
    }

    get sessionItems() {
        return this._sessionRows.map((row, i) => ({
            key: 'ss' + i,
            index: String(i),
            title: row.title,
            at: row.at,
            hasAt: !!row.at,
            turnLabel: row.turnCount + (row.turnCount === 1 ? ' turn' : ' turns')
        }));
    }

    get hasSessions() {
        return !!this.sessionsAccount && this._sessionsState === 'ready' && this._sessionRows.length > 0;
    }

    /** The one sentence the control shows instead of, or above, the list; empty when the list says it all. */
    get sessionsMessage() {
        const account = this.sessionsAccount;
        if (!account) {
            return SESSIONS_NO_ACCOUNT;
        }
        if (this._sessionsNote) {
            return this._sessionsNote;
        }
        switch (this._sessionsState) {
            case 'loading':
                return SESSIONS_LOADING;
            case 'error':
                return SESSIONS_FAILED;
            case 'ready':
                return this._sessionRows.length ? '' : 'No earlier conversations about ' + account.name + ' yet.';
            default:
                return '';
        }
    }

    handleSessionsToggle() {
        this.sessionsOpen = !this._sessionsOpen;
    }

    /** Lists the account's conversations, newest first. A reply for another account is dropped. */
    _loadSessions() {
        this._sessionsNote = '';
        const account = this.sessionsAccount;
        if (!this._connected || !this._sessionsOpen || !account || !account.id) {
            return;
        }
        const accountId = account.id;
        if (accountId !== this._sessionsAccountId) {
            this._sessionRows = [];
        }
        this._sessionsAccountId = accountId;
        this._sessionsState = 'loading';
        listSessions({ accountId, limitSize: SESSION_LIMIT })
            .then((rows) => {
                if (accountId !== this._sessionsAccountId) {
                    return;
                }
                this._sessionRows = (rows || [])
                    .filter((r) => r && r.id)
                    .map((r) => ({
                        id: r.id,
                        title: r.title || 'Untitled conversation',
                        at: r.lastActive || r.startedAt || null,
                        turnCount: r.turnCount || 0
                    }))
                    .sort((a, b) => timeOf(b.at) - timeOf(a.at));
                this._sessionsState = 'ready';
                this.liveMessage = this.sessionsMessage || this._sessionRows.length + ' earlier conversations';
            })
            .catch(() => {
                if (accountId === this._sessionsAccountId) {
                    this._sessionRows = [];
                    this._sessionsState = 'error';
                    this.liveMessage = SESSIONS_FAILED;
                }
            });
    }

    /** Reopens one earlier conversation: its turns, in order, become the thread. */
    handleSessionOpen(event) {
        const row = this._sessionRows[Number(event.currentTarget.dataset.index)];
        if (!row) {
            return Promise.resolve();
        }
        const sessionId = row.id;
        this._sessionsNote = '';
        return this._request({
            key: 'session:' + sessionId,
            label: '',
            loading: 'Opening conversation',
            keepSession: true,
            onError: () => {
                this._sessionsNote = SESSION_FAILED;
                return SESSION_FAILED;
            },
            work: async (isCurrent) => {
                const detail = await getSession({ sessionId });
                if (!isCurrent()) {
                    return null;
                }
                if (!detail) {
                    this._sessionsNote = SESSION_HIDDEN;
                    return SESSION_HIDDEN;
                }
                this.drillStack = [];
                this._drillOrigin = null;
                this._scopeOrg = false;
                this.turns = (detail.turns || []).map((t) => {
                    const text = t.headline || '';
                    return {
                        key: this._nextKey('t'),
                        kind: 'text',
                        isText: true,
                        isError: t.status === 'ERROR',
                        question: t.question || 'Summary',
                        text,
                        historyAnswer: text,
                        cards: [],
                        hasCards: false
                    };
                });
                this._setSession(detail.id || sessionId);
                this._sessionsOpen = false;
                this._pinned = true;
                this._focusAfterRender = '.abp-composer';
                return 'Opened ' + (detail.title || row.title);
            }
        });
    }

    /** Starts a clean thread with a new session id. A reply still on its way is dropped. */
    handleNewConversation() {
        this._requestId += 1;
        this.pending = false;
        this.pendingQuestion = '';
        this._inFlightKey = null;
        this.turns = [];
        this.drillStack = [];
        this._drillOrigin = null;
        this._scopeOrg = false;
        this._sessionsNote = '';
        this._sessionsOpen = false;
        this._setSession(newSessionId());
        this._pinned = true;
        this.liveMessage = 'New conversation';
        this._focusAfterRender = '.abp-composer';
    }

    _setSession(id) {
        if (id === this._sessionId) {
            return;
        }
        this._sessionId = id;
        this.dispatchEvent(new CustomEvent('sessionchange', { detail: { sessionId: id } }));
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
        return 'Earlier summaries' + name + ' (' + this.historyItems.length + ')';
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
}
