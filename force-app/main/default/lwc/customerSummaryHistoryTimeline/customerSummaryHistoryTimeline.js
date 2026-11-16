/**
 * customerSummaryHistoryTimeline: the account's outcomes, newest first (FR2, FE-19; ledger F76).
 *
 * It reads CustomerOutcomes.listOutcomes (BE-35), builds one `timeline` card of FE-18's contract and hands it
 * to c-customer-summary-card, the shared renderer: no second renderer here. The card's own fold is "show
 * more" (10 entries at the comfortable density). The title of an entry is a link that opens its detail under
 * the card; the detail is where an entry's text and its related record link live.
 *
 * Who sees what (BE-35's rule, F79 and F87): CustomerOutcomes.view() already withholds a title, headline,
 * body, reason and record link from anyone but the author, unless the outcome's type shares its text
 * (textShown). This component only draws what it is given: for a withheld entry the detail says the type, the
 * date and the sentiment label, and that the text stays with its author.
 *
 * Interface:
 *   @api recordId, objectApiName  the page's record; an Account sets the account shown. objectApiName is
 *                                  accepted for the page and not needed: an Account Id is recognised by its prefix.
 *   @api density                   'comfortable' (the default: the rail and a page) or 'compact'
 *   @api refresh()                 loads the outcomes again
 *
 * Every value is bound as text; no record Id reaches the markup (it lives in the card's refs and in
 * a navigation call) and no href is built.
 */
import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import listOutcomes from '@salesforce/apex/CustomerOutcomes.listOutcomes';
import getOutcome from '@salesforce/apex/CustomerOutcomes.getOutcome';

const ACCOUNT_PREFIX = '001';
const LIMIT = 100;
const ALL = '';
const NO_ACCOUNT = 'Open an account to see its history.';
const EMPTY = 'Nothing recorded for this account yet. Summaries and actions appear here once they are made.';
const FAILED = "Couldn't load this account's history. Try again in a minute.";
const GONE = 'This entry is no longer available.';
const WITHHELD = 'The text of this entry stays with its author.';
const DETAIL_FAILED = "Couldn't open this entry. Try again in a minute.";

/** A Datetime as a local yyyy-mm-dd, the form the timeline card shows and dates itself with. */
function dayOf(value) {
    const d = value ? new Date(value) : null;
    if (!d || Number.isNaN(d.getTime())) {
        return '';
    }
    const two = (n) => String(n).padStart(2, '0');
    return d.getFullYear() + '-' + two(d.getMonth() + 1) + '-' + two(d.getDate());
}

function joined(parts) {
    return parts.filter((p) => p).join(' · ');
}

function stamp(o) {
    const t = o && o.createdDate ? new Date(o.createdDate).getTime() : 0;
    return Number.isNaN(t) ? 0 : t;
}

export default class CustomerSummaryHistoryTimeline extends NavigationMixin(LightningElement) {
    @api objectApiName;
    @api density = 'comfortable';

    state = 'idle'; // idle, loading, ready, error
    outcomes = [];
    filter = ALL;
    detail = null; // { state: 'loading' | 'ready' | 'gone' | 'error', outcome }

    _accountId = null;
    _requestId = 0;
    _detailId = 0;

    @api
    get recordId() {
        return this._accountId;
    }
    set recordId(value) {
        const id = value && String(value).startsWith(ACCOUNT_PREFIX) ? value : null;
        if (id !== this._accountId) {
            this._accountId = id;
            this.detail = null;
            this.filter = ALL;
            if (this._connected) {
                this._load();
            }
        }
    }

    _connected = false;

    connectedCallback() {
        this._connected = true;
        this._load();
    }

    disconnectedCallback() {
        this._connected = false;
    }

    @api
    refresh() {
        this._load();
    }

    _load() {
        const request = ++this._requestId;
        if (!this._accountId) {
            this.state = 'idle';
            this.outcomes = [];
            return;
        }
        this.state = 'loading';
        let call;
        try {
            call = Promise.resolve(listOutcomes({ accountId: this._accountId, types: null, limitSize: LIMIT }));
        } catch (e) {
            call = Promise.reject(e);
        }
        call.then(
            (rows) => {
                if (request !== this._requestId) {
                    return;
                }
                this.outcomes = (Array.isArray(rows) ? rows : []).slice().sort((a, b) => stamp(b) - stamp(a));
                this.state = 'ready';
                // FE-32: the rail shows this count on its History header, which is drawn before the timeline mounts.
                this.dispatchEvent(new CustomEvent('historycount', { detail: { count: this.outcomes.length } }));
            },
            () => {
                if (request !== this._requestId) {
                    return;
                }
                this.outcomes = [];
                this.state = 'error';
            }
        );
    }

    // ------------------------------------------------------------ view

    get hasAccount() {
        return Boolean(this._accountId);
    }
    get isLoading() {
        return this.state === 'loading';
    }
    get isError() {
        return this.state === 'error';
    }
    get isEmpty() {
        return this.hasAccount && this.state === 'ready' && this.outcomes.length === 0;
    }
    get showCard() {
        return this.state === 'ready' && this.shown.length > 0;
    }
    get emptyText() {
        return this.hasAccount ? EMPTY : NO_ACCOUNT;
    }
    get showEmpty() {
        return !this.hasAccount || this.isEmpty;
    }
    get errorText() {
        return FAILED;
    }
    get cardDensity() {
        return this.density === 'compact' ? 'compact' : 'comfortable';
    }

    get typeOptions() {
        const seen = new Map();
        this.outcomes.forEach((o) => {
            if (o.type && !seen.has(o.type)) {
                seen.set(o.type, o.typeLabel || o.type);
            }
        });
        if (seen.size < 2) {
            return [];
        }
        const sorted = Array.from(seen.entries()).sort((a, b) => a[1].localeCompare(b[1]));
        return [{ value: ALL, label: 'All types', selected: this.filter === ALL }].concat(
            sorted.map(([value, label]) => ({ value, label, selected: this.filter === value }))
        );
    }
    get hasFilter() {
        return this.typeOptions.length > 0;
    }

    get shown() {
        return this.filter === ALL ? this.outcomes : this.outcomes.filter((o) => o.type === this.filter);
    }

    /** The one timeline card: type, date and title for each entry; its link opens the entry's detail. */
    get card() {
        const entries = this.shown;
        const items = [];
        const refs = [];
        entries.forEach((o, n) => {
            const key = 'o' + n;
            const label = o.title || o.typeLabel || o.type || 'Entry';
            const typeLabel = o.typeLabel || o.type;
            items.push({
                at: dayOf(o.createdDate),
                kind: o.type || '',
                label,
                detail: joined([typeLabel && typeLabel !== label ? typeLabel : '', o.sentimentLabel]),
                ref: key
            });
            refs.push({ key, recordId: o.id, objectName: 'entry', label });
        });
        const title = 'Newest first';
        return {
            type: 'timeline',
            version: 1,
            key: 'history',
            title,
            status: 'OK',
            text: [title].concat(items.map((i) => i.at + ' · ' + i.label + (i.detail ? ' — ' + i.detail : ''))).join('\n'),
            body: [],
            items,
            refs,
            total: items.length,
            shown: items.length
        };
    }

    // ------------------------------------------------------------ events

    handleFilter(event) {
        this.filter = event.target.value || ALL;
        this.detail = null;
    }

    handleRetry() {
        this._load();
    }

    handleCardOpen(event) {
        event.stopPropagation();
        const ref = event.detail && event.detail.ref;
        const match = /^o(\d+)$/.exec(ref || '');
        const entry = match ? this.shown[Number(match[1])] : null;
        if (!entry) {
            return;
        }
        const request = ++this._detailId;
        this.detail = { state: 'loading', outcome: entry };
        let call;
        try {
            call = Promise.resolve(getOutcome({ outcomeId: entry.id }));
        } catch (e) {
            call = Promise.reject(e);
        }
        call.then(
            (full) => {
                if (request === this._detailId) {
                    this.detail = full ? { state: 'ready', outcome: full } : { state: 'gone', outcome: entry };
                }
            },
            () => {
                if (request === this._detailId) {
                    this.detail = { state: 'error', outcome: entry };
                }
            }
        );
    }

    handleCloseDetail() {
        this._detailId += 1;
        this.detail = null;
    }

    handleOpenRecord() {
        const id = this.detail && this.detail.outcome && this.detail.outcome.relatedRecordId;
        if (id) {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: id, actionName: 'view' } });
        }
    }

    // ------------------------------------------------------------ detail view

    get hasDetail() {
        return Boolean(this.detail);
    }
    get detailLoading() {
        return this.detail && this.detail.state === 'loading';
    }
    get detailGone() {
        return this.detail && this.detail.state === 'gone';
    }
    get detailError() {
        return this.detail && this.detail.state === 'error';
    }
    get detailReady() {
        return this.detail && this.detail.state === 'ready';
    }
    get goneText() {
        return GONE;
    }
    get detailErrorText() {
        return DETAIL_FAILED;
    }
    get withheldText() {
        return WITHHELD;
    }
    get detailOutcome() {
        const o = (this.detail && this.detail.outcome) || {};
        const typeLabel = o.typeLabel || o.type || '';
        const paragraphs = String(o.body || '')
            .split('\n')
            .map((p) => p.trim())
            .filter((p) => p);
        return {
            title: o.title || typeLabel,
            typeLabel,
            date: dayOf(o.createdDate),
            sentiment: o.sentimentLabel || '',
            hasSentiment: Boolean(o.sentimentLabel),
            textShown: Boolean(o.textShown),
            headline: o.headline || '',
            hasHeadline: Boolean(o.headline),
            paragraphs: paragraphs.map((text, n) => ({ key: 'p' + n, text })),
            hasBody: paragraphs.length > 0,
            reason: o.sentimentReason || '',
            hasReason: Boolean(o.sentimentReason),
            hasRecord: Boolean(o.textShown && o.relatedRecordId)
        };
    }
    get detailWithheld() {
        return this.detailReady && !this.detailOutcome.textShown;
    }
    get detailShown() {
        return this.detailReady && this.detailOutcome.textShown;
    }
}
