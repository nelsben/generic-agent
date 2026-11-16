/**
 * customerSummarySentimentChart (FE-19): sentiment over time from the account's summaries, as an inline SVG
 * of labelled points (no library). BE-36 found the score not steady enough to chart, so the chart shows the
 * labels only: a point per summary on a band per label, no line, and it says so. Covers the empty, one-point
 * and many-point data, the reason only where the viewer may see it, the text table for screen readers, the
 * theme variables and zero accessibility violations (@sa11y/jest).
 */
import { createElement } from 'lwc';
import CustomerSummarySentimentChart from 'c/customerSummarySentimentChart';
import listOutcomes from '@salesforce/apex/CustomerOutcomes.listOutcomes';

jest.mock('@salesforce/apex/CustomerOutcomes.listOutcomes', () => ({ default: jest.fn() }), { virtual: true });

const fs = require('fs');
const path = require('path');

const BUNDLE = path.join(__dirname, '..');
const ACCOUNT = '001000000000001AAA';
const LABELS = ['At risk', 'Concerned', 'Neutral', 'Positive', 'Very positive'];

function summary(day, label, extra) {
    return {
        id: 'a0B' + String(day).padStart(15, '0'),
        accountId: ACCOUNT,
        type: 'Summary',
        typeLabel: 'Summary',
        createdDate: '2026-10-' + String(day).padStart(2, '0') + 'T15:00:00.000Z',
        mine: true,
        textShown: true,
        title: 'Summary',
        sentimentLabel: label,
        sentimentScore: label ? LABELS.indexOf(label) - 2 : null,
        sentimentReason: label ? 'Reason for ' + label : null,
        ...(extra || {})
    };
}

async function flush() {
    for (let i = 0; i < 4; i++) {
        // eslint-disable-next-line no-await-in-loop
        await Promise.resolve();
    }
}

async function mount(rows) {
    listOutcomes.mockResolvedValue(rows);
    const el = createElement('c-customer-summary-sentiment-chart', { is: CustomerSummarySentimentChart });
    el.recordId = ACCOUNT;
    document.body.appendChild(el);
    await flush();
    return el;
}

const points = (el) => Array.from(el.shadowRoot.querySelectorAll('svg [data-point]'));

afterEach(() => {
    while (document.body.firstChild) {
        document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
});

describe('customerSummarySentimentChart', () => {
    test('asks for the account\'s summaries only', async () => {
        await mount([]);
        const args = listOutcomes.mock.calls[0][0];
        expect(args.accountId).toBe(ACCOUNT);
        expect(args.types).toEqual(['Summary']);
    });

    test('no summaries: a plain note, no chart', async () => {
        const el = await mount([]);
        expect(el.shadowRoot.querySelector('svg')).toBeNull();
        expect(el.shadowRoot.querySelector('[data-testid="note"]').textContent).toMatch(/at least two summaries/i);
        await expect(el).toBeAccessible();
    });

    test('one point: a plain note instead of a chart', async () => {
        const el = await mount([summary(10, 'Concerned')]);
        expect(el.shadowRoot.querySelector('svg')).toBeNull();
        expect(el.shadowRoot.querySelector('[data-testid="note"]').textContent).toMatch(/at least two summaries/i);
        await expect(el).toBeAccessible();
    });

    test('summaries with no label (or Not enough activity) are not points', async () => {
        const el = await mount([
            summary(12, 'Neutral'),
            summary(11, 'Not enough activity', { sentimentScore: null }),
            summary(10, null),
            summary(9, 'Concerned')
        ]);
        expect(points(el)).toHaveLength(2);
    });

    test('many points: one per summary, oldest on the left, labelled with date and label, no line', async () => {
        const rows = [summary(20, 'Very positive'), summary(18, 'Positive'), summary(15, 'Neutral'), summary(12, 'Concerned'), summary(10, 'At risk')];
        const el = await mount(rows);
        const pts = points(el);
        expect(pts).toHaveLength(5);
        const labels = pts.map((p) => p.getAttribute('aria-label'));
        expect(labels[0]).toMatch(/2026-10-10, At risk/);
        expect(labels[4]).toMatch(/2026-10-20, Very positive/);
        const xs = pts.map((p) => Number(p.getAttribute('data-x')));
        expect(xs).toEqual(xs.slice().sort((a, b) => a - b));
        const svg = el.shadowRoot.querySelector('svg');
        expect(svg.querySelector('polyline, path[data-line]')).toBeNull();
        expect(svg.getAttribute('role')).toBe('group');
        await expect(el).toBeAccessible();
    });

    // L6: at most one point per 8 px of plot width. The plot is 126 px in the 216 px rail (the svg is drawn 1:1 there).
    const RAIL_MAX_POINTS = 15;

    function daysApart(n, labelOf) {
        return Array.from({ length: n }, (_, i) =>
            summary(1, labelOf(i), { createdDate: new Date(Date.UTC(2026, 0, 1, 12) + i * 86400000).toISOString() })
        );
    }

    test('L6: 60 summaries on 60 days draw at most one point per 8 px of plot width, each with a count and a mean label', async () => {
        const el = await mount(daysApart(60, (i) => LABELS[i % 5]));
        const pts = points(el);
        expect(pts.length).toBeGreaterThanOrEqual(2);
        expect(pts.length).toBeLessThanOrEqual(RAIL_MAX_POINTS);
        const grouped = pts.filter((p) => p.getAttribute('aria-label').match(/\d+ summaries/));
        expect(grouped.length).toBeGreaterThan(0);
        expect(el.shadowRoot.querySelector('[data-testid="focus"]')).not.toBeNull();
        await expect(el).toBeAccessible();
    });

    test('L6: a multi-day bucket is labelled "from to" with ISO days, and the axis reads only the first and last row days', async () => {
        const el = await mount(daysApart(60, (i) => LABELS[i % 5]));
        // 60 days from 2026-01-01 to 2026-03-01 (the last row is offset 59 days).
        const ticks = Array.from(el.shadowRoot.querySelectorAll('svg text.cs-axis'))
            .map((t) => t.textContent)
            .filter(Boolean);
        expect(ticks).toEqual(['2026-01-01', '2026-03-01']);
        expect(el.shadowRoot.querySelector('svg').getAttribute('aria-label')).toBe(
            'Sentiment label, ' + points(el).length + ' points, from 2026-01-01 to 2026-03-01'
        );
        const ranged = points(el).map((p) => p.getAttribute('aria-label'));
        expect(ranged.some((l) => /^\d{4}-\d{2}-\d{2} to \d{4}-\d{2}-\d{2}, mean /.test(l))).toBe(true);
        expect(el.shadowRoot.querySelector('[data-testid="focus"]')).not.toBeNull();
    });

    test('L6: summaries on fewer days than the cap are bucketed by day, one point per day with its count', async () => {
        const rows = Array.from({ length: 60 }, (_, i) =>
            summary(1, LABELS[i % 5], { createdDate: new Date(Date.UTC(2026, 0, 1, 12) + Math.floor(i / 6) * 86400000).toISOString() })
        );
        const el = await mount(rows);
        const pts = points(el);
        expect(pts).toHaveLength(10);
        expect(pts[0].getAttribute('aria-label')).toMatch(/2026-01-01, .*, 6 summaries/);
    });

    test('L6: the table still lists every summary the chart was given', async () => {
        const rows = daysApart(60, (i) => LABELS[i % 5]);
        const el = await mount(rows);
        expect(el.shadowRoot.querySelectorAll('table tbody tr')).toHaveLength(60);
    });

    test('L6: axis text is at least 11 px, and two ticks never read the same date', async () => {
        const css = fs.readFileSync(path.join(BUNDLE, 'customerSummarySentimentChart.css'), 'utf8');
        const size = (sel) => {
            const m = css.match(new RegExp(sel.replace('.', '\\.') + ' \\{[^}]*font-size: (\\d+)px'));
            return m ? Number(m[1]) : 0;
        };
        expect(size('.cs-axis')).toBeGreaterThanOrEqual(11);
        expect(size('.cs-band-label')).toBeGreaterThanOrEqual(11);

        const el = await mount([summary(12, 'Neutral'), summary(12, 'Concerned')]);
        const ticks = Array.from(el.shadowRoot.querySelectorAll('svg text.cs-axis'))
            .map((t) => t.textContent)
            .filter(Boolean);
        expect(ticks).toEqual(['2026-10-12']);
    });

    test('says the chart shows labels only because the score is not steady enough', async () => {
        const el = await mount([summary(12, 'Neutral'), summary(10, 'Concerned')]);
        expect(el.shadowRoot.querySelector('[data-testid="labels-only"]').textContent).toMatch(/labels only/i);
        expect(el.shadowRoot.querySelector('[data-testid="labels-only"]').textContent).toMatch(/score is not steady enough/i);
    });

    test('a text table lists every summary for screen readers', async () => {
        const el = await mount([summary(12, 'Neutral'), summary(11, null), summary(10, 'Concerned')]);
        const rows = el.shadowRoot.querySelectorAll('table tbody tr');
        expect(rows).toHaveLength(3);
        expect(rows[0].textContent).toContain('2026-10-12');
        expect(rows[0].textContent).toContain('Neutral');
        expect(rows[1].textContent).toContain('No label');
        expect(el.shadowRoot.querySelector('table caption').textContent).toMatch(/sentiment/i);
    });

    test('focus or hover shows the reason where the viewer may see it', async () => {
        const el = await mount([summary(12, 'Neutral'), summary(10, 'Concerned')]);
        const pt = points(el)[0];
        expect(el.shadowRoot.querySelector('[data-testid="focus"]').textContent).not.toContain('Reason for Concerned');
        pt.dispatchEvent(new CustomEvent('focus'));
        await flush();
        expect(el.shadowRoot.querySelector('[data-testid="focus"]').textContent).toContain('Reason for Concerned');
        pt.dispatchEvent(new CustomEvent('blur'));
        await flush();
        expect(el.shadowRoot.querySelector('[data-testid="focus"]').textContent).not.toContain('Reason for Concerned');
        points(el)[1].dispatchEvent(new CustomEvent('mouseenter'));
        await flush();
        expect(el.shadowRoot.querySelector('[data-testid="focus"]').textContent).toContain('Reason for Neutral');
    });

    test('someone else\'s summary: the label alone, never a reason, in the chart or the table', async () => {
        const el = await mount([
            summary(12, 'Positive', { mine: false, textShown: false, sentimentReason: null, sentimentScore: undefined }),
            summary(10, 'Concerned', { mine: false, textShown: false, sentimentReason: 'must not appear' })
        ]);
        points(el)[0].dispatchEvent(new CustomEvent('focus'));
        await flush();
        const text = el.shadowRoot.textContent;
        expect(text).toContain('Concerned');
        expect(text).not.toContain('must not appear');
        expect(el.shadowRoot.querySelector('[data-testid="focus"]').textContent).toMatch(/label only/i);
    });

    test('a failed load shows one fixed sentence and Try again', async () => {
        listOutcomes.mockRejectedValueOnce(new Error('boom'));
        const el = createElement('c-customer-summary-sentiment-chart', { is: CustomerSummarySentimentChart });
        el.recordId = ACCOUNT;
        document.body.appendChild(el);
        await flush();
        expect(el.shadowRoot.querySelector('[data-testid="error"]').textContent).toMatch(/couldn't load/i);
        listOutcomes.mockResolvedValue([summary(12, 'Neutral'), summary(10, 'Concerned')]);
        el.shadowRoot.querySelector('button[data-action="retry"]').click();
        await flush();
        expect(points(el)).toHaveLength(2);
    });

    test('colours come from the --cs-* variables, and no Id reaches the markup', async () => {
        const css = fs.readFileSync(path.join(BUNDLE, 'customerSummarySentimentChart.css'), 'utf8');
        expect(css).toContain('var(--cs-color-ink');
        expect(css).toContain('var(--cs-color-primary');
        expect(css).toContain('var(--cs-color-surface');
        const html = fs.readFileSync(path.join(BUNDLE, 'customerSummarySentimentChart.html'), 'utf8');
        expect(html).not.toMatch(/fill="#|stroke="#/);
        const rows = [summary(12, 'Neutral'), summary(10, 'Concerned')];
        const el = await mount(rows);
        expect(el.shadowRoot.innerHTML).not.toContain(rows[0].id);
    });

    test('exposes the record page target for accounts', () => {
        const meta = fs.readFileSync(path.join(BUNDLE, 'customerSummarySentimentChart.js-meta.xml'), 'utf8');
        expect(meta).toContain('<target>lightning__RecordPage</target>');
        expect(meta).toContain('<object>Account</object>');
    });
});
