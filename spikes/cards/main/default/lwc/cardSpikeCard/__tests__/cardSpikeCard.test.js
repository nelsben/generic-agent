/**
 * cardSpikeCard: one test per card type from the page's JSON examples (the fixtures), the three
 * fallbacks, the events, the folds, the safety rules (no markup, no Id in view) and zero
 * accessibility violations (@sa11y/jest, the axe-core matcher this repo already uses for jest-axe).
 */
import { createElement } from 'lwc';
import CardSpikeCard from 'c/cardSpikeCard';
import { FIXTURES } from 'c/cardSpikeFixtures';
import { FALLBACKS } from 'c/cardSpikeGallery';

const flush = () => Promise.resolve();

function mount(card, density = 'comfortable') {
    const el = createElement('c-card-spike-card', { is: CardSpikeCard });
    el.density = density;
    el.card = card;
    document.body.appendChild(el);
    return el;
}

function fixture(type, status) {
    return FIXTURES.find((c) => c.type === type && (!status || c.status === status));
}

function q(el, sel) {
    return el.shadowRoot.querySelector(sel);
}

function qa(el, sel) {
    return Array.from(el.shadowRoot.querySelectorAll(sel));
}

afterEach(() => {
    while (document.body.firstChild) {
        document.body.removeChild(document.body.firstChild);
    }
});

describe('one renderer per type', () => {
    test('summary: headline pinned, body as runs with strong, em and a list', () => {
        const el = mount(fixture('summary'));
        expect(q(el, '.cs-title-text').textContent).toBe(fixture('summary').title);
        expect(qa(el, '.cs-p strong').map((s) => s.textContent)).toEqual(['Open deals:', 'Service health:']);
        expect(q(el, '.cs-p em').textContent).toBe('high priority');
        expect(qa(el, '.cs-ul li')).toHaveLength(2);
        expect(q(el, '.cs-toggle').getAttribute('aria-expanded')).toBe('true');
    });

    test('section: folded by default; opening shows each line, a record line is a link', () => {
        const el = mount(fixture('section', 'OK'));
        expect(q(el, '.cs-items')).toBeNull();
        q(el, '.cs-toggle').click();
        return flush().then(() => {
            expect(q(el, '.cs-toggle').getAttribute('aria-expanded')).toBe('true');
            expect(qa(el, '.cs-item')).toHaveLength(3);
            expect(qa(el, '.cs-item button.cs-link')[0].getAttribute('aria-label')).toBe('Open Opportunity Edge Emergency Generator');
        });
    });

    test('section ERROR: the fixed text and an error badge, the card marked as an error', () => {
        const el = mount(fixture('section', 'ERROR'));
        q(el, '.cs-toggle').click();
        return flush().then(() => {
            expect(q(el, '.cs-p').textContent).toBe("Couldn't load Calls right now.");
            expect(q(el, '.cs-badge').textContent).toBe('Error');
            expect(q(el, 'article').className).toContain('cs-card-error');
        });
    });

    test('text: code and a record link by ref', () => {
        const el = mount(fixture('text'));
        expect(q(el, 'code').textContent).toBe('$250,000');
        expect(q(el, 'button.cs-link').textContent).toBe('Edge Emergency Generator');
        expect(q(el, 'article').getAttribute('aria-label')).toBe('Answer');
    });

    test('table at comfortable: a real table with row headers, numbers right-aligned, the count pinned', () => {
        const el = mount(fixture('table'));
        expect(qa(el, 'thead th').map((t) => t.textContent)).toEqual(['Name', 'Stage', 'Amount', 'Close date']);
        expect(qa(el, 'tbody tr')).toHaveLength(6);
        expect(qa(el, 'tbody th[scope="row"] button')).toHaveLength(6);
        expect(qa(el, 'td.cs-num')).toHaveLength(6);
        expect(q(el, '.cs-count').textContent).toBe('Showing 6 of 212 rows');
    });

    test('table at compact: stacked rows, 5 then "Show 1 more"', () => {
        const el = mount(fixture('table'), 'compact');
        expect(q(el, 'table')).toBeNull();
        expect(qa(el, '.cs-stack-row')).toHaveLength(5);
        expect(q(el, '.cs-more').textContent).toBe('Show 1 more');
        q(el, '.cs-more').click();
        return flush().then(() => {
            expect(qa(el, '.cs-stack-row')).toHaveLength(6);
            expect(q(el, '.cs-more')).toBeNull();
            expect(q(el, '.cs-count').textContent).toBe('Showing 6 of 212 rows');
        });
    });

    test('metric: the first figure is the hero', () => {
        const el = mount(fixture('metric'));
        expect(q(el, '.cs-metric-hero .cs-metric-value').textContent).toBe('212');
        expect(qa(el, '.cs-metric')).toHaveLength(3);
    });

    test('record: fields, a lookup as a link, related objects as chips', () => {
        const el = mount(fixture('record'));
        expect(qa(el, '.cs-field')).toHaveLength(5);
        expect(q(el, '.cs-field button.cs-link').textContent).toBe('Edge Communications');
        expect(qa(el, '[aria-label="Related records"] button').map((b) => b.textContent)).toEqual(['Tasks', 'Events', 'Opportunity Contact Roles']);
    });

    test('recordList: items and its count line', () => {
        const el = mount(fixture('recordList'));
        expect(qa(el, '.cs-item')).toHaveLength(3);
        expect(q(el, '.cs-count').textContent).toBe('Showing 3 of 4 records');
    });

    test('timeline: a time element per item', () => {
        const el = mount(fixture('timeline'));
        expect(qa(el, 'time').map((t) => t.getAttribute('datetime'))).toEqual(['2026-11-10', '2026-11-04', '2026-10-28']);
    });

    test('comparison: one column per record at comfortable, one block per field at compact', () => {
        const wide = mount(fixture('comparison'));
        expect(qa(wide, 'thead th')).toHaveLength(3);
        expect(qa(wide, 'tbody tr')).toHaveLength(4);
        const narrow = mount(fixture('comparison'), 'compact');
        expect(q(narrow, 'table')).toBeNull();
        expect(qa(narrow, '.cs-stack-head').map((h) => h.textContent)).toEqual(['Stage', 'Amount', 'Close date', 'Last activity']);
        expect(qa(narrow, '.cs-stack-row')[0].querySelectorAll('dt')[1].textContent).toBe('Juniper Project B');
    });

    test('choice: each candidate fires cardchoose with its Id, never cardopen', () => {
        const el = mount(fixture('choice'));
        const choose = jest.fn();
        const open = jest.fn();
        el.addEventListener('cardchoose', choose);
        el.addEventListener('cardopen', open);
        qa(el, '.cs-item button')[1].click();
        expect(choose.mock.calls[0][0].detail).toEqual({ cardKey: 'cho', fieldKey: null, ref: 'a2', recordId: 'record-id:a2' });
        expect(open).not.toHaveBeenCalled();
        expect(q(el, '.cs-badge').textContent).toBe('Choose one');
    });

    test('followups: chips fire cardask with their text', () => {
        const el = mount(fixture('followups'));
        const ask = jest.fn();
        el.addEventListener('cardask', ask);
        qa(el, '.cs-chip')[0].click();
        expect(ask.mock.calls[0][0].detail).toEqual({ text: 'Which of these close this quarter?' });
    });

    test('trail: folded, numbered queries when open', () => {
        const el = mount(fixture('trail'));
        expect(q(el, '.cs-items')).toBeNull();
        q(el, '.cs-toggle').click();
        return flush().then(() => expect(qa(el, '.cs-item')).toHaveLength(2));
    });

    test('notice and error: prose; the error is marked', () => {
        expect(q(mount(fixture('notice')), '.cs-p').textContent).toContain('Showing 50 of 212 rows');
        const err = mount(fixture('error'));
        expect(q(err, 'article').className).toContain('cs-card-error');
        expect(q(err, 'article').getAttribute('aria-label')).toBe('Error');
    });

    test('actionDraft: a missing field, a choice, a note and the three controls', () => {
        const el = mount(fixture('actionDraft'));
        expect(q(el, '.cs-dd-missing').textContent).toBe('Needed');
        expect(qa(el, '.cs-choices button').map((b) => b.textContent)).toEqual(['Jordan Lee', 'Jordan Park']);
        expect(qa(el, '.cs-controls button').map((b) => b.textContent)).toEqual(['Confirm', 'Edit', 'Cancel']);
        const action = jest.fn();
        const choose = jest.fn();
        el.addEventListener('cardaction', action);
        el.addEventListener('cardchoose', choose);
        qa(el, '.cs-controls button')[0].click();
        qa(el, '.cs-choices button')[1].click();
        expect(action.mock.calls[0][0].detail).toEqual({ cardKey: 'drf', control: 'confirm' });
        expect(choose.mock.calls[0][0].detail).toEqual({ cardKey: 'drf', fieldKey: 'WhoId', ref: 'c4', recordId: 'record-id:c4' });
    });

    test('actionResult: the record link fires cardopen with its Id and object', () => {
        const el = mount(fixture('actionResult'));
        const open = jest.fn();
        el.addEventListener('cardopen', open);
        q(el, '.cs-field button.cs-link').click();
        expect(open.mock.calls[0][0].detail).toEqual({ ref: 't9', recordId: 'record-id:t9', objectName: 'Task' });
        expect(q(el, '.cs-controls button').textContent).toBe('Open task');
    });
});

describe('fallbacks render the card text', () => {
    test.each(FALLBACKS.map((c) => [c.key, c]))('%s', (key, card) => {
        const el = mount(card, 'compact');
        const box = q(el, '.cs-fallback');
        expect(box).not.toBeNull();
        expect(qa(el, '.cs-line').map((l) => l.textContent).join('\n')).toBe(card.text);
    });

    test('a card that changes to an unknown type falls back on the next render', () => {
        const el = mount(fixture('metric'));
        el.card = { ...fixture('metric'), type: 'sparkline' };
        return flush().then(() => expect(q(el, '.cs-fallback')).not.toBeNull());
    });
});

describe('safety', () => {
    test('no record Id is in the rendered text or any attribute but the click detail', () => {
        FIXTURES.forEach((card) => {
            const el = mount(card, 'comfortable');
            const html = el.shadowRoot.innerHTML;
            expect(html).not.toContain('record-id:');
            document.body.removeChild(el);
        });
    });

    test('markup in a value stays text', () => {
        const el = mount({ type: 'text', version: 1, body: [{ kind: 'p', runs: [{ text: '<img src=x onerror=alert(1)>' }] }], text: 'x' });
        expect(q(el, 'img')).toBeNull();
        expect(q(el, '.cs-p').textContent).toBe('<img src=x onerror=alert(1)>');
    });
});

describe('accessibility', () => {
    test.each(FIXTURES.map((c) => [c.type + ':' + c.key, c]))('%s has no violations, compact and comfortable', async (name, card) => {
        const a = mount(card, 'compact');
        const b = mount(card, 'comfortable');
        // Open the folds so their contents are checked too.
        qa(a, '.cs-toggle').forEach((t) => t.getAttribute('aria-expanded') === 'false' && t.click());
        qa(b, '.cs-toggle').forEach((t) => t.getAttribute('aria-expanded') === 'false' && t.click());
        await flush();
        await expect(a).toBeAccessible();
        await expect(b).toBeAccessible();
    });

    test('the fallbacks have no violations', async () => {
        FALLBACKS.forEach((c) => mount(c, 'compact'));
        await expect(document.body).toBeAccessible();
    });
});
