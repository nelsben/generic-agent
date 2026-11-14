/**
 * customerSummaryHistoryTimeline (FE-19): the account's outcomes, newest first, drawn by the shared card
 * (FE-18's timeline card). Covers the empty, one-entry and many-entry data, the filter by type, show more
 * (the card's own fold), opening an entry (its text for its author or a type that shares it, a short note for
 * anyone else, F79 and F87), the related record link, the failure line, the markup rules and zero
 * accessibility violations (@sa11y/jest).
 */
import { createElement } from 'lwc';
import CustomerSummaryHistoryTimeline from 'c/customerSummaryHistoryTimeline';
import listOutcomes from '@salesforce/apex/CustomerOutcomes.listOutcomes';
import getOutcome from '@salesforce/apex/CustomerOutcomes.getOutcome';

const mockNavigate = jest.fn();

jest.mock('lightning/navigation', () => {
    const Navigate = Symbol('Navigate');
    const NavigationMixin = (Base) =>
        class extends Base {
            [Navigate](pageRef) {
                mockNavigate(pageRef);
            }
        };
    NavigationMixin.Navigate = Navigate;
    return { NavigationMixin };
});
jest.mock('@salesforce/apex/CustomerOutcomes.listOutcomes', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/CustomerOutcomes.getOutcome', () => ({ default: jest.fn() }), { virtual: true });

const ACCOUNT = '001000000000001AAA';

function outcome(n, extra) {
    const day = String(28 - n).padStart(2, '0');
    return {
        id: 'a0B00000000000' + String(n).padStart(2, '0') + 'AAA',
        accountId: ACCOUNT,
        type: 'Summary',
        typeLabel: 'Summary',
        createdDate: '2026-10-' + day + 'T15:00:00.000Z',
        mine: true,
        textShown: true,
        title: 'Summary ' + n,
        headline: 'Headline ' + n,
        sentimentLabel: 'Neutral',
        sentimentScore: 0,
        sentimentReason: 'Reason ' + n,
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
    const el = createElement('c-customer-summary-history-timeline', { is: CustomerSummaryHistoryTimeline });
    el.recordId = ACCOUNT;
    document.body.appendChild(el);
    await flush();
    return el;
}

const cardOf = (el) => el.shadowRoot.querySelector('c-customer-summary-card');
const noteOf = (el) => el.shadowRoot.querySelector('[data-testid="empty"]');

afterEach(() => {
    while (document.body.firstChild) {
        document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
});

describe('customerSummaryHistoryTimeline', () => {
    test('asks for the account\'s outcomes once, by the page\'s record', async () => {
        await mount([]);
        expect(listOutcomes).toHaveBeenCalledTimes(1);
        expect(listOutcomes.mock.calls[0][0].accountId).toBe(ACCOUNT);
    });

    test('no outcomes: a plain note and no card', async () => {
        const el = await mount([]);
        expect(cardOf(el)).toBeNull();
        expect(noteOf(el).textContent).toMatch(/nothing recorded for this account yet/i);
        await expect(el).toBeAccessible();
    });

    test('no account on the page: a plain note and no call', async () => {
        const el = createElement('c-customer-summary-history-timeline', { is: CustomerSummaryHistoryTimeline });
        document.body.appendChild(el);
        await flush();
        expect(listOutcomes).not.toHaveBeenCalled();
        expect(noteOf(el).textContent).toMatch(/open an account/i);
    });

    test('one outcome: a timeline card with type, date and title', async () => {
        const el = await mount([outcome(1, { sentimentLabel: 'Concerned' })]);
        const card = cardOf(el).card;
        expect(card.type).toBe('timeline');
        expect(card.items).toHaveLength(1);
        expect(card.items[0].at).toBe('2026-10-27');
        expect(card.items[0].label).toBe('Summary 1');
        expect(card.items[0].detail).toBe('Summary · Concerned');
        // The plain-text fallback carries no Id.
        expect(card.text).toContain('2026-10-27');
        await expect(el).toBeAccessible();
    });

    test('many outcomes: newest first whatever order they arrive in, and the card folds them (show more)', async () => {
        const rows = [];
        for (let n = 1; n <= 14; n++) {
            rows.push(outcome(n));
        }
        const el = await mount(rows.slice().reverse());
        const card = cardOf(el).card;
        expect(card.items).toHaveLength(14);
        expect(card.items[0].label).toBe('Summary 1');
        expect(card.items[13].label).toBe('Summary 14');
        const inner = cardOf(el).shadowRoot;
        expect(inner.querySelectorAll('li.cs-item')).toHaveLength(10);
        const more = Array.from(inner.querySelectorAll('button')).find((b) => /show 4 more/i.test(b.textContent));
        expect(more).toBeTruthy();
        more.click();
        await flush();
        expect(inner.querySelectorAll('li.cs-item')).toHaveLength(14);
        await expect(el).toBeAccessible();
    });

    test('a filter by type narrows the card, and All types brings it back', async () => {
        const el = await mount([
            outcome(1),
            outcome(2, { type: 'Action', typeLabel: 'Action', title: 'Task created', sentimentLabel: null, sentimentScore: null }),
            outcome(3)
        ]);
        const select = el.shadowRoot.querySelector('select[data-filter]');
        expect(Array.from(select.options).map((o) => o.textContent)).toEqual(['All types', 'Action', 'Summary']);
        select.value = 'Action';
        select.dispatchEvent(new CustomEvent('change'));
        await flush();
        expect(cardOf(el).card.items).toHaveLength(1);
        expect(cardOf(el).card.items[0].label).toBe('Task created');
        select.value = '';
        select.dispatchEvent(new CustomEvent('change'));
        await flush();
        expect(cardOf(el).card.items).toHaveLength(3);
    });

    test('one type only: no filter', async () => {
        const el = await mount([outcome(1), outcome(2)]);
        expect(el.shadowRoot.querySelector('select[data-filter]')).toBeNull();
    });

    test('opening an entry the viewer wrote shows its text and its related record link', async () => {
        const rows = [outcome(1, { relatedRecordId: '006000000000001AAA', sentimentReason: 'Renewal slipping' })];
        getOutcome.mockResolvedValue({ ...rows[0], body: 'Line one\nLine two' });
        const el = await mount(rows);
        const ref = cardOf(el).card.refs[0].key;
        cardOf(el).dispatchEvent(new CustomEvent('cardopen', { detail: { ref, recordId: rows[0].id, objectName: 'entry' }, bubbles: true, composed: true }));
        await flush();
        expect(getOutcome).toHaveBeenCalledWith({ outcomeId: rows[0].id });
        const detail = el.shadowRoot.querySelector('[data-testid="detail"]');
        expect(detail.textContent).toContain('Headline 1');
        expect(detail.textContent).toContain('Line one');
        expect(detail.textContent).toContain('Line two');
        expect(detail.textContent).toContain('Renewal slipping');
        expect(detail.querySelector('[data-testid="withheld"]')).toBeNull();
        detail.querySelector('button[data-action="record"]').click();
        expect(mockNavigate).toHaveBeenCalledWith({
            type: 'standard__recordPage',
            attributes: { recordId: '006000000000001AAA', actionName: 'view' }
        });
        await expect(el).toBeAccessible();
    });

    test('opening someone else\'s entry shows type, date and label and a note that the text stays with its author', async () => {
        const rows = [
            outcome(1, { mine: false, textShown: false, title: 'Summary', headline: null, sentimentReason: null, sentimentLabel: 'Positive' })
        ];
        getOutcome.mockResolvedValue({ ...rows[0] });
        const el = await mount(rows);
        // The card shows the fixed phrase, never a title.
        expect(cardOf(el).card.items[0].label).toBe('Summary');
        const ref = cardOf(el).card.refs[0].key;
        cardOf(el).dispatchEvent(new CustomEvent('cardopen', { detail: { ref }, bubbles: true, composed: true }));
        await flush();
        const detail = el.shadowRoot.querySelector('[data-testid="detail"]');
        expect(detail.textContent).toContain('Summary');
        expect(detail.textContent).toContain('2026-10-27');
        expect(detail.textContent).toContain('Positive');
        expect(detail.querySelector('[data-testid="withheld"]').textContent).toMatch(/stays with its author/i);
        expect(detail.querySelector('button[data-action="record"]')).toBeNull();
        expect(detail.querySelector('[data-testid="body"]')).toBeNull();
        await expect(el).toBeAccessible();
    });

    test('a type that shares its text shows it to anyone', async () => {
        const rows = [outcome(1, { mine: false, textShown: true, headline: 'Shared headline' })];
        getOutcome.mockResolvedValue({ ...rows[0], body: 'Shared body' });
        const el = await mount(rows);
        const ref = cardOf(el).card.refs[0].key;
        cardOf(el).dispatchEvent(new CustomEvent('cardopen', { detail: { ref }, bubbles: true, composed: true }));
        await flush();
        const detail = el.shadowRoot.querySelector('[data-testid="detail"]');
        expect(detail.textContent).toContain('Shared body');
        expect(detail.querySelector('[data-testid="withheld"]')).toBeNull();
    });

    test('an entry that is gone says so, and Close hides the detail', async () => {
        const rows = [outcome(1)];
        getOutcome.mockResolvedValue(null);
        const el = await mount(rows);
        const ref = cardOf(el).card.refs[0].key;
        cardOf(el).dispatchEvent(new CustomEvent('cardopen', { detail: { ref }, bubbles: true, composed: true }));
        await flush();
        expect(el.shadowRoot.querySelector('[data-testid="detail"]').textContent).toMatch(/no longer available/i);
        el.shadowRoot.querySelector('button[data-action="close"]').click();
        await flush();
        expect(el.shadowRoot.querySelector('[data-testid="detail"]')).toBeNull();
    });

    test('a failed load shows one fixed sentence and Try again', async () => {
        listOutcomes.mockRejectedValueOnce(new Error('boom with detail'));
        const el = createElement('c-customer-summary-history-timeline', { is: CustomerSummaryHistoryTimeline });
        el.recordId = ACCOUNT;
        document.body.appendChild(el);
        await flush();
        const err = el.shadowRoot.querySelector('[data-testid="error"]');
        expect(err.textContent).toMatch(/couldn't load/i);
        expect(err.textContent).not.toContain('boom');
        listOutcomes.mockResolvedValue([outcome(1)]);
        el.shadowRoot.querySelector('button[data-action="retry"]').click();
        await flush();
        expect(cardOf(el)).not.toBeNull();
    });

    test('no record Id reaches the markup, and no href is built', async () => {
        const rows = [outcome(1, { relatedRecordId: '006000000000001AAA' })];
        const el = await mount(rows);
        expect(el.shadowRoot.innerHTML).not.toContain(rows[0].id);
        expect(el.shadowRoot.innerHTML).not.toContain('006000000000001AAA');
        expect(el.shadowRoot.innerHTML).not.toMatch(/href=/);
    });

    test('exposes the record page target for accounts', () => {
        const fs = require('fs');
        const path = require('path');
        const meta = fs.readFileSync(path.join(__dirname, '..', 'customerSummaryHistoryTimeline.js-meta.xml'), 'utf8');
        expect(meta).toContain('<target>lightning__RecordPage</target>');
        expect(meta).toContain('<object>Account</object>');
    });
});
