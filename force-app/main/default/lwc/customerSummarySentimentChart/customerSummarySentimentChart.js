/**
 * customerSummarySentimentChart: how the sentiment of the account's summaries changed over time (FR2, FE-19;
 * ledger F77). An inline SVG, no library.
 *
 * LABELS ONLY. docs/research/fr2-sentiment.md (BE-36) found the score not steady enough to chart: a change to
 * one prompt rule moved a label two steps, so a line would show prompt edits, not the customer. So this draws
 * no score line and no numeric axis: each summary is a point on the band of its label (At risk to Very
 * positive), oldest on the left, points evenly spaced in order, nothing joining them. The chart says so on the
 * screen. The score is never read.
 *
 * Who sees what (F79, F87): CustomerOutcomes returns the sentiment label of any summary on an account the viewer
 * can see, and the reason only for the author or a type that shares its text. The reason shows on focus or
 * hover of a point and only when it came back; otherwise the label alone.
 *
 * Fewer than two points (a summary with no label, or "Not enough activity", is not a point) shows a plain note.
 * A text table lists every summary for screen readers. Nothing is inserted, backdated or recorded here.
 *
 *   @api recordId, objectApiName  the page's record; an Account sets the account shown
 *   @api refresh()                loads the summaries again
 */
import { LightningElement, api } from 'lwc';
import listOutcomes from '@salesforce/apex/CustomerOutcomes.listOutcomes';

const ACCOUNT_PREFIX = '001';
const LIMIT = 50;
// Bottom to top; the order of BE-36's five labels. The tone is a second cue beside the band, never the only one.
const BANDS = [
    { label: 'At risk', tone: 'neg' },
    { label: 'Concerned', tone: 'neg' },
    { label: 'Neutral', tone: 'mid' },
    { label: 'Positive', tone: 'pos' },
    { label: 'Very positive', tone: 'pos' }
];
const NOTE = 'Not enough to chart yet. At least two summaries with a sentiment label are needed to show a change over time.';
const NO_ACCOUNT = 'Open an account to see its sentiment over time.';
const LABELS_ONLY =
    'Labels only: the score is not steady enough to chart as a line yet, so each summary is a point on its label, oldest on the left.';
const FAILED = "Couldn't load this account's summaries. Try again in a minute.";
const LABEL_ONLY_NOTE = "Label only: the reason for this label stays with the summary's author.";

// The chart is drawn 1:1 in the 215 px context column of the rail, so these units are CSS px there (FE-32).
const WIDTH = 215;
const LEFT = 78;
const RIGHT = 12;
const TOP = 10;
const BAND = 26;
const AXIS = 22;
const HEIGHT = TOP + BAND * BANDS.length + AXIS;
const PLOT_WIDTH = WIDTH - LEFT - RIGHT;
// L6: at most one point per 8 px of plot width: 125 px of plot in the rail gives 15 points.
const PX_PER_POINT = 8;
const MAX_POINTS = Math.floor(PLOT_WIDTH / PX_PER_POINT);

/**
 * L6: groups the plotted summaries (oldest first) into at most MAX_POINTS buckets. Each summary stands alone
 * when they fit; otherwise by day when the days fit; otherwise into equal spans of time from the first summary
 * to the last. Empty spans are dropped.
 */
function bucketsOf(rows) {
    if (rows.length <= MAX_POINTS) {
        return rows.map((s) => [s]);
    }
    const days = [];
    const byDay = new Map();
    rows.forEach((s) => {
        const day = dayOf(s.createdDate);
        if (!byDay.has(day)) {
            byDay.set(day, []);
            days.push(day);
        }
        byDay.get(day).push(s);
    });
    if (days.length <= MAX_POINTS) {
        return days.map((day) => byDay.get(day));
    }
    const t0 = stamp(rows[0]);
    const span = (stamp(rows[rows.length - 1]) - t0) / MAX_POINTS;
    const out = Array.from({ length: MAX_POINTS }, () => []);
    rows.forEach((s) => {
        const i = span > 0 ? Math.min(MAX_POINTS - 1, Math.floor((stamp(s) - t0) / span)) : 0;
        out[i].push(s);
    });
    return out.filter((b) => b.length);
}

function dayOf(value) {
    const d = value ? new Date(value) : null;
    if (!d || Number.isNaN(d.getTime())) {
        return '';
    }
    const two = (n) => String(n).padStart(2, '0');
    return d.getFullYear() + '-' + two(d.getMonth() + 1) + '-' + two(d.getDate());
}

function stamp(o) {
    const t = o && o.createdDate ? new Date(o.createdDate).getTime() : 0;
    return Number.isNaN(t) ? 0 : t;
}

export default class CustomerSummarySentimentChart extends LightningElement {
    @api objectApiName;

    state = 'idle';
    summaries = []; // oldest first
    focusedIndex = -1;

    _accountId = null;
    _requestId = 0;
    _connected = false;

    @api
    get recordId() {
        return this._accountId;
    }
    set recordId(value) {
        const id = value && String(value).startsWith(ACCOUNT_PREFIX) ? value : null;
        if (id !== this._accountId) {
            this._accountId = id;
            this.focusedIndex = -1;
            if (this._connected) {
                this._load();
            }
        }
    }

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
            this.summaries = [];
            return;
        }
        this.state = 'loading';
        let call;
        try {
            call = Promise.resolve(listOutcomes({ accountId: this._accountId, types: ['Summary'], limitSize: LIMIT }));
        } catch (e) {
            call = Promise.reject(e);
        }
        call.then(
            (rows) => {
                if (request === this._requestId) {
                    this.summaries = (Array.isArray(rows) ? rows : []).slice().sort((a, b) => stamp(a) - stamp(b));
                    this.state = 'ready';
                }
            },
            () => {
                if (request === this._requestId) {
                    this.summaries = [];
                    this.state = 'error';
                }
            }
        );
    }

    // ------------------------------------------------------------ view

    get isError() {
        return this.state === 'error';
    }
    get isLoading() {
        return this.state === 'loading';
    }
    get errorText() {
        return FAILED;
    }
    get labelsOnlyText() {
        return LABELS_ONLY;
    }
    get noteText() {
        return this._accountId ? NOTE : NO_ACCOUNT;
    }

    /**
     * The points: the plotted summaries (a summary whose label is one of the five bands), oldest first, grouped
     * into at most MAX_POINTS buckets (L6). A bucket of one is a summary; a bucket of more sits at the mean of its
     * labels, named by the band nearest that mean, and its count is in its accessible text.
     */
    get points() {
        const bandOf = new Map(BANDS.map((b, n) => [b.label, n]));
        const plotted = this.summaries.filter((s) => bandOf.has(s.sentimentLabel));
        const buckets = bucketsOf(plotted);
        const n = buckets.length;
        return buckets.map((rows, i) => {
            const mean = rows.reduce((sum, s) => sum + bandOf.get(s.sentimentLabel), 0) / rows.length;
            const band = Math.round(mean);
            const x = n === 1 ? LEFT + PLOT_WIDTH / 2 : LEFT + (PLOT_WIDTH * i) / (n - 1);
            const y = TOP + BAND * (BANDS.length - 1 - mean) + BAND / 2;
            const first = dayOf(rows[0].createdDate);
            const last = dayOf(rows[rows.length - 1].createdDate);
            const count = rows.length;
            const single = count === 1 ? rows[0] : null;
            const date = first === last ? first : first + ' to ' + last;
            const label = BANDS[band].label;
            return {
                key: 'p' + i,
                index: i,
                x: Math.round(x * 10) / 10,
                y: Math.round(y * 10) / 10,
                date,
                label,
                count,
                className: 'cs-pt cs-pt_' + BANDS[band].tone + (i === this.focusedIndex ? ' cs-pt_on' : ''),
                ariaLabel: single ? date + ', ' + label : date + ', mean ' + label + ', ' + count + ' summaries',
                reason: single && single.textShown && single.sentimentReason ? single.sentimentReason : '',
                textShown: single ? Boolean(single.textShown) : true
            };
        });
    }
    get showChart() {
        return this.state === 'ready' && this.points.length >= 2;
    }
    get showNote() {
        return this.state === 'idle' || (this.state === 'ready' && this.points.length < 2);
    }

    get viewBox() {
        return '0 0 ' + WIDTH + ' ' + HEIGHT;
    }
    get bands() {
        return BANDS.map((b, n) => {
            const y = TOP + BAND * (BANDS.length - 1 - n);
            return { key: 'b' + n, label: b.label, lineY: y + BAND / 2, textY: y + BAND / 2 + 4, boxY: y, boxH: BAND, odd: n % 2 === 1 };
        });
    }
    get plotLeft() {
        return LEFT;
    }
    get plotRight() {
        return WIDTH - RIGHT;
    }
    get labelX() {
        return LEFT - 8;
    }
    get plotWidth() {
        return WIDTH - LEFT - RIGHT;
    }
    get axisY() {
        return TOP + BAND * BANDS.length + 15;
    }
    get firstDate() {
        const p = this.points;
        return p.length ? p[0].date : '';
    }
    /** L6: the end tick is left blank when it would read the same date as the start tick. */
    get lastDate() {
        const p = this.points;
        const last = p.length ? p[p.length - 1].date : '';
        return last === this.firstDate ? '' : last;
    }
    get chartLabel() {
        return 'Sentiment label, ' + this.points.length + ' points, from ' + this.firstDate + ' to ' + this.points[this.points.length - 1].date;
    }

    /** The table for screen readers: every summary, newest first, even one with no label. */
    get hasReasonColumn() {
        return this.summaries.some((s) => s.textShown && s.sentimentReason);
    }
    get tableRows() {
        const withReason = this.hasReasonColumn;
        return this.summaries
            .slice()
            .reverse()
            .map((s, n) => ({
                key: 'r' + n,
                date: dayOf(s.createdDate),
                label: s.sentimentLabel || 'No label',
                reason: s.textShown && s.sentimentReason ? s.sentimentReason : '',
                showReason: withReason
            }));
    }

    // ------------------------------------------------------------ the point in focus

    get focusText() {
        const p = this.points[this.focusedIndex];
        if (!p) {
            return '';
        }
        if (p.count > 1) {
            return p.date + ', mean ' + p.label + ' across ' + p.count + ' summaries. Each summary is listed in the table below.';
        }
        return p.date + ', ' + p.label + (p.reason ? '. ' + p.reason : p.textShown ? '' : '. ' + LABEL_ONLY_NOTE);
    }

    handlePointOn(event) {
        const n = Number(event.currentTarget.dataset.index);
        this.focusedIndex = Number.isNaN(n) ? -1 : n;
    }
    handlePointOff(event) {
        if (Number(event.currentTarget.dataset.index) === this.focusedIndex) {
            this.focusedIndex = -1;
        }
    }
    handleRetry() {
        this._load();
    }
}
