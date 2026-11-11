/**
 * accountBriefPanel: a Cmd/Ctrl-K panel over the Account Brief engine.
 *
 * One engine, two front ends: every call goes through AccountBriefPanelController, which only
 * delegates to the Apex the agent uses (AccountBriefResolver, AccountBrief, AccountBriefMemory,
 * DataExplorer). The panel never renders model text as HTML: answers are text in pre-line blocks.
 *
 * Keys: a document keydown listener owns Cmd/Ctrl-K (focus the composer, opening the utility
 * first) and yields when another component already handled the event (defaultPrevented). The
 * composer stops propagation of every key so Lightning's single-key shortcuts don't fire while
 * typing; the focus trap (Tab wrap, Esc) is registered on this.template and also called from the
 * composer, since the composer's keys never reach it.
 */
import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { subscribe, unsubscribe, MessageContext, APPLICATION_SCOPE } from 'lightning/messageService';
import { getEnclosingUtilityId, open as openUtility, minimize as minimizeUtility } from 'lightning/platformUtilityBarApi';
import { open as openAgent, execute as executeAgent } from 'lightning/accApi';
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
const FOCUSABLE = 'button, [href], input, textarea, select, summary, [tabindex]:not([tabindex="-1"])';
const NAME_FIELDS = ['Name', 'CaseNumber', 'Subject'];

const BADGE = {
    OK: 'slds-badge slds-theme_success',
    EMPTY: 'slds-badge',
    ERROR: 'slds-badge slds-theme_error'
};

function errorText(error) {
    if (error && error.body && error.body.message) {
        return error.body.message;
    }
    if (error && error.message) {
        return error.message;
    }
    return 'Something went wrong. Try again in a minute.';
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
    historyItems = [];
    notice = '';

    _pageRef;
    _messageRecordId = null;
    _lastContextId;
    _seq = 0;
    _keyHandler;
    _subscription;

    @wire(MessageContext) messageContext;

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
        this.template.addEventListener('keydown', this._trapKeydown);
        this._subscribe();
        this._syncContext();
    }

    renderedCallback() {
        // MessageContext can arrive after connectedCallback.
        this._subscribe();
    }

    disconnectedCallback() {
        if (this._keyHandler) {
            document.removeEventListener('keydown', this._keyHandler);
            this._keyHandler = null;
        }
        this.template.removeEventListener('keydown', this._trapKeydown);
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
        if (event.defaultPrevented) {
            return;
        }
        if ((event.metaKey || event.ctrlKey) && (event.key === 'k' || event.key === 'K')) {
            event.preventDefault();
            this._openAndFocus();
        } else if (event.key === 'Escape' && this.template.activeElement) {
            // Focus is inside the panel but the trap did not take it: close.
            event.preventDefault();
            this._close();
        }
    }

    /** Focus trap on this.template: Tab wraps inside the panel, Esc blurs the composer or closes. */
    _trapKeydown = (event) => {
        if (event.defaultPrevented) {
            return;
        }
        if (event.key === 'Escape') {
            event.preventDefault();
            const composer = this._composer();
            if (composer && this.template.activeElement === composer) {
                composer.blur();
            } else {
                this._close();
            }
            return;
        }
        if (event.key !== 'Tab') {
            return;
        }
        const panel = this.template.querySelector('.abp-panel');
        const focusables = panel
            ? Array.from(panel.querySelectorAll(FOCUSABLE)).filter((el) => !el.disabled && !el.hidden)
            : [];
        if (!focusables.length) {
            return;
        }
        const first = focusables[0];
        const last = focusables[focusables.length - 1];
        const active = this.template.activeElement;
        if (event.shiftKey && active === first) {
            event.preventDefault();
            last.focus();
        } else if (!event.shiftKey && active === last) {
            event.preventDefault();
            first.focus();
        }
    };

    handleComposerKeydown(event) {
        // Keep Lightning's single-key shortcuts from firing while typing.
        event.stopPropagation();
        this._trapKeydown(event);
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            this._submitDraft();
        }
    }

    handleComposerKeyOther(event) {
        event.stopPropagation();
    }

    handleComposerInput(event) {
        this.draft = event.target.value;
    }

    async _openAndFocus() {
        try {
            const utilityId = await getEnclosingUtilityId(this);
            if (utilityId) {
                await openUtility(utilityId, { autoFocus: true });
            }
        } catch (e) {
            // Not in a utility bar, or the API is unavailable: just focus.
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
        const active = this.template.activeElement;
        if (active && active.blur) {
            active.blur();
        }
        try {
            const utilityId = await getEnclosingUtilityId(this);
            if (utilityId) {
                await minimizeUtility(utilityId);
            }
        } catch (e) {
            // Not in a utility bar: blurring is all Esc does.
        }
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
        return this.pageObjectApiName === 'Account' || (!!id && id.startsWith(ACCOUNT_PREFIX));
    }

    /** Context for a question: a message's record, the page's record, then the briefed account. */
    get contextRecordId() {
        return this._messageRecordId || this.pageRecordId || (this.briefedAccount ? this.briefedAccount.id : null);
    }

    _syncContext() {
        const id = this.pageRecordId;
        if (id === this._lastContextId) {
            return;
        }
        this._lastContextId = id;
        this.pageAccount = null;
        if (!id || !this.isAccountPage) {
            return;
        }
        resolve({ accountName: null, recordId: id })
            .then((r) => {
                if (r && r.status === 'RESOLVED' && this._lastContextId === id) {
                    this.pageAccount = { id: r.accountId, name: r.accountName };
                    this._loadHistory(r.accountId);
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
        return this.sourceList.map((s) => {
            const on = this.selectedKeys.includes(s.key);
            return {
                key: s.key,
                title: s.title,
                pressed: on ? 'true' : 'false',
                className: 'slds-button abp-chip ' + (on ? 'slds-button_brand' : 'slds-button_neutral')
            };
        });
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

    // ------------------------------------------------------------ submit

    get sendDisabled() {
        return this.pending || !this.draft || !this.draft.trim();
    }

    get hasTurns() {
        return this.turns.length > 0;
    }

    handleSend() {
        this._submitDraft();
    }

    _submitDraft() {
        const text = (this.draft || '').trim();
        if (!text || this.pending) {
            return;
        }
        this.draft = '';
        const composer = this._composer();
        if (composer) {
            composer.value = '';
        }
        this.submit(text);
    }

    /** Runs one composer text: '/brief <name>' briefs an account, anything else is a question. */
    submit(text, contextOverride) {
        const q = (text || '').trim();
        if (!q || this.pending) {
            return Promise.resolve();
        }
        this.drillStack = [];
        this.notice = '';
        if (BRIEF_COMMAND.test(q)) {
            const name = q.replace(BRIEF_COMMAND, '').trim();
            return this._run(q, () => resolve({ accountName: name, recordId: null }).then((r) => this._afterResolve(r, q)));
        }
        return this._run(q, () => this._explore(q, contextOverride));
    }

    handleBriefThisAccount() {
        const label = this.briefButtonLabel;
        if (this.pageAccount) {
            const acct = this.pageAccount;
            this._run(label, () => this._brief(acct.id, acct.name, label));
        } else {
            this._run(label, () => resolve({ accountName: null, recordId: this.pageRecordId }).then((r) => this._afterResolve(r, label)));
        }
    }

    handleCandidate(event) {
        const { id, label } = event.currentTarget.dataset;
        this._run(label, () => resolve({ accountName: null, recordId: id }).then((r) => this._afterResolve(r, label)));
    }

    handleFollowup(event) {
        this.submit(event.currentTarget.dataset.text);
    }

    async _run(label, work) {
        this.pending = true;
        try {
            await work();
        } catch (error) {
            this._push({ isText: true, isError: true, question: label, text: errorText(error) });
        } finally {
            this.pending = false;
        }
    }

    _push(turn) {
        this._seq += 1;
        this.turns = [...this.turns, { key: 't' + this._seq, ...turn }];
    }

    _afterResolve(r, label) {
        if (r.status === 'RESOLVED') {
            return this._brief(r.accountId, r.accountName, label);
        }
        if (r.status === 'AMBIGUOUS') {
            this._push(this._ambiguousTurn(r, label));
            return Promise.resolve();
        }
        // NOT_FOUND: the resolver's text, verbatim.
        this._push({ isText: true, question: label, text: r.message, historyAnswer: r.message });
        return Promise.resolve();
    }

    _ambiguousTurn(r, label) {
        const lines = (r.message || '').split('\n');
        const candidates = [];
        const notes = [];
        lines.slice(1).forEach((line, i) => {
            const id = idInLine(line);
            if (id) {
                candidates.push({ key: 'c' + i, id, label: line.split(' — ')[0], detail: line });
            } else if (line.trim()) {
                notes.push({ key: 'n' + i, text: line });
            }
        });
        return { isAmbiguous: true, question: label, header: lines[0], candidates, notes, historyAnswer: r.message };
    }

    async _brief(accountId, accountName, label) {
        const r = await getBrief({
            accountId,
            question: null,
            include: this.selectedKeys.length ? [...this.selectedKeys] : null
        });
        this.briefedAccount = { id: accountId, name: accountName };
        this._push(this._briefTurn(r, label, accountName));
        this._loadHistory(accountId);
    }

    _briefTurn(r, label, accountName) {
        const verbatim = r.status === 'NOT_FOUND' || r.status === 'ERROR';
        const answer = (r.answer || '').trim();
        const nl = answer.indexOf('\n');
        const sections = (r.sections || []).map((s, i) => ({
            key: (s.key || 's') + i,
            title: s.title,
            status: s.status,
            badgeClass: BADGE[s.status] || 'slds-badge',
            countText: s.shown + ' of ' + s.total,
            lines: (s.body || '').split('\n').map((line, j) => {
                const id = idInLine(line);
                return { key: 'l' + j, text: line === '' ? ' ' : line, drillId: id, isDrill: !!id };
            })
        }));
        return {
            isBrief: true,
            question: label,
            accountName,
            verbatim,
            message: r.message,
            showMessage: verbatim || (r.status === 'EMPTY' && !!r.message && r.message !== answer),
            header: verbatim ? '' : nl >= 0 ? answer.substring(0, nl).trim() : answer,
            rest: verbatim || nl < 0 ? '' : answer.substring(nl + 1).trim(),
            hasSections: sections.length > 0,
            sections,
            ignoredText: r.ignored && r.ignored.length ? 'Not sections: ' + r.ignored.join(', ') : '',
            historyAnswer: verbatim ? r.message : answer
        };
    }

    async _explore(q, contextOverride) {
        const r = await explore({
            question: q,
            contextRecordId: contextOverride || this.contextRecordId || null,
            historyJson: this._historyJson()
        });
        this._push(this._exploreTurn(r, q));
    }

    _historyJson() {
        const items = this.turns
            .filter((t) => t.question && t.historyAnswer)
            .slice(-HISTORY_TURNS)
            .map((t) => ({ question: t.question, answer: t.historyAnswer }));
        return items.length ? JSON.stringify(items) : null;
    }

    _exploreTurn(r, q) {
        const tables = (r.resultSets || []).map((rs, i) => this._table(rs, 'rs' + i));
        const trail = (r.trail || []).map((text, i) => ({ key: 'q' + i, text }));
        return {
            isExplore: true,
            question: q,
            isError: r.status === 'ERROR',
            answer: r.answer,
            tables,
            hasTrail: trail.length > 0,
            trail,
            trailLabel: 'Ran ' + trail.length + (trail.length === 1 ? ' query' : ' queries'),
            followups: (r.followups || []).map((text, i) => ({ key: 'f' + i, text })),
            historyAnswer: r.answer
        };
    }

    _table(rs, key) {
        const columns = rs.columns || [];
        const rows = (rs.rows || []).map((row, i) => ({
            key: key + 'r' + i,
            id: row.Id || null,
            clickable: !!row.Id,
            rowClass: row.Id ? 'abp-row-link' : '',
            tabindex: row.Id ? '0' : '-1',
            cells: columns.map((c, j) => ({ key: 'c' + j, value: cellText(row[c]) }))
        }));
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

    get drillTop() {
        return this.drillStack.length ? this.drillStack[this.drillStack.length - 1] : null;
    }

    get breadcrumbs() {
        return this.drillStack.map((d, i) => ({ key: d.key, label: d.label, index: String(i), current: i === this.drillStack.length - 1 }));
    }

    handleRowClick(event) {
        const id = event.currentTarget.dataset.id;
        if (id) {
            this._drill(id, null, this.isDrilling);
        }
    }

    handleRowKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleRowClick(event);
        }
    }

    handleLineDrill(event) {
        this._drill(event.currentTarget.dataset.id, null, false);
    }

    handleRelated(event) {
        const top = this.drillTop;
        if (top) {
            this._drill(top.recordId, event.currentTarget.dataset.object, true);
        }
    }

    handleCrumb(event) {
        const index = Number(event.currentTarget.dataset.index);
        this.drillStack = this.drillStack.slice(0, index + 1);
    }

    handleBackToConversation() {
        this.drillStack = [];
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

    async _drill(recordId, relatedObject, push) {
        if (this.pending) {
            return;
        }
        this.pending = true;
        this.notice = '';
        try {
            const d = await drill({ recordId, relatedObject: relatedObject || null });
            const entry = this._drillEntry(d, recordId, relatedObject);
            this.drillStack = push ? [...this.drillStack, entry] : [entry];
        } catch (error) {
            this.notice = errorText(error);
        } finally {
            this.pending = false;
        }
    }

    _drillEntry(d, recordId, relatedObject) {
        this._seq += 1;
        const rs = d.result || {};
        if (relatedObject) {
            return {
                key: 'd' + this._seq,
                recordId,
                isRecord: false,
                label: relatedObject,
                table: this._table(rs, 'd' + this._seq)
            };
        }
        const row = (rs.rows && rs.rows[0]) || {};
        const nameField = NAME_FIELDS.find((f) => row[f]);
        return {
            key: 'd' + this._seq,
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

    get historyAccountId() {
        return this.briefedAccount ? this.briefedAccount.id : this.pageAccount ? this.pageAccount.id : null;
    }

    get hasHistory() {
        return this.historyItems.length > 0;
    }

    get historyLabel() {
        return 'Earlier briefs (' + this.historyItems.length + ')';
    }

    _loadHistory(accountId) {
        if (!accountId) {
            return;
        }
        history({ accountId })
            .then((turns) => {
                this.historyItems = (turns || []).map((t, i) => ({
                    key: 'h' + i,
                    at: t.at ? new Date(t.at).toLocaleString() : '',
                    status: t.status,
                    question: t.question,
                    headline: t.headline
                }));
            })
            .catch(() => {
                this.historyItems = [];
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
            this.notice = 'Could not open the agent: ' + errorText(error);
        }
    }

    // ------------------------------------------------------------ message channel

    _handleMessage(message) {
        if (!message) {
            return;
        }
        this._messageRecordId = message.recordId || null;
        this._openAndFocus();
        const prompt = (message.prompt || '').trim();
        let done;
        if (prompt) {
            done = this.submit(prompt, this._messageRecordId);
        } else if (this._messageRecordId && this._messageRecordId.startsWith(ACCOUNT_PREFIX)) {
            const id = this._messageRecordId;
            done = this._run('Brief', () => resolve({ accountName: null, recordId: id }).then((r) => this._afterResolve(r, 'Brief ' + (r.accountName || ''))));
        }
        Promise.resolve(done).finally(() => {
            this._messageRecordId = null;
        });
    }
}
