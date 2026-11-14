/**
 * customerSummaryCard: one test per card type from the JSON examples of FE-18's page and BE-39's page,
 * the three fallbacks, the four events, the folds, the keyboard (one Tab stop per list), the safety
 * rules (no markup, no Id in the markup, no href) and zero accessibility violations (@sa11y/jest).
 * Ported from spikes/cards/ (cardSpikeCard's tests), which stay as they are.
 */
import { createElement } from 'lwc';
import CustomerSummaryCard from 'c/customerSummaryCard';
import { TYPES } from '../cardContract';
import { FIXTURES, BE39_FIXTURES, FALLBACKS } from './fixtures';

const fs = require('fs');
const path = require('path');

const BUNDLE = path.join(__dirname, '..');
const SOURCE_JS = fs.readFileSync(path.join(BUNDLE, 'customerSummaryCard.js'), 'utf8');
const SOURCE_CONTRACT = fs.readFileSync(path.join(BUNDLE, 'cardContract.js'), 'utf8');
const SOURCE_HTML = fs.readFileSync(path.join(BUNDLE, 'customerSummaryCard.html'), 'utf8');
const SOURCE_CSS = fs.readFileSync(path.join(BUNDLE, 'customerSummaryCard.css'), 'utf8');
const THEME = ['--cs-color-primary', '--cs-color-accent', '--cs-color-surface', '--cs-color-ink', '--cs-font-display', '--cs-font-body', '--cs-radius'];

const ALL = FIXTURES.concat(BE39_FIXTURES);

const flush = () => Promise.resolve();

function mount(card, density = 'comfortable') {
    const el = createElement('c-customer-summary-card', { is: CustomerSummaryCard });
    el.density = density;
    el.card = card;
    document.body.appendChild(el);
    return el;
}

function fixture(type, status) {
    return FIXTURES.find((c) => c.type === type && (!status || c.status === status));
}

function be39(type) {
    return BE39_FIXTURES.find((c) => c.type === type);
}

function q(el, sel) {
    return el.shadowRoot.querySelector(sel);
}

function qa(el, sel) {
    return Array.from(el.shadowRoot.querySelectorAll(sel));
}

function key(target, name) {
    const event = new KeyboardEvent('keydown', { key: name, bubbles: true, composed: true, cancelable: true });
    target.dispatchEvent(event);
    return event;
}

/** Runs body with the action types drawn, as they will be once FE-14 ships them. */
async function withActions(body) {
    TYPES.actionDraft.ready = true;
    TYPES.actionResult.ready = true;
    try {
        await body();
    } finally {
        TYPES.actionDraft.ready = false;
        TYPES.actionResult.ready = false;
    }
}

afterEach(() => {
    while (document.body.firstChild) {
        document.body.removeChild(document.body.firstChild);
    }
});

describe('one renderer per type (FE-18 page)', () => {
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

    test('table at compact: stacked rows, 5 then "Show 1 more"; the count stays pinned', () => {
        const el = mount(fixture('table'), 'compact');
        expect(q(el, 'table')).toBeNull();
        expect(qa(el, '.cs-stack-row')).toHaveLength(5);
        expect(q(el, '.cs-more').textContent).toBe('Show 1 more');
        expect(q(el, '.cs-count').textContent).toBe('Showing 6 of 212 rows');
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

    test('notice and error: prose; the notice agrees with the table; the error is marked', () => {
        expect(q(mount(fixture('notice')), '.cs-p').textContent).toContain('Showing 6 of 212 rows');
        const err = mount(fixture('error'));
        expect(q(err, 'article').className).toContain('cs-card-error');
        expect(q(err, 'article').getAttribute('aria-label')).toBe('Error');
    });

    test('actionDraft and actionResult: not drawn yet, so each shows its own text', () => {
        ['actionDraft', 'actionResult'].forEach((type) => {
            const el = mount(fixture(type), 'compact');
            expect(q(el, '.cs-fallback')).not.toBeNull();
            expect(qa(el, '.cs-line').map((l) => l.textContent).join('\n')).toBe(fixture(type).text);
            expect(q(el, '.cs-controls')).toBeNull();
        });
    });
});

describe('one renderer per type (BE-39 page)', () => {
    test('choice from the resolver: two Edge Communications, the second chosen by its Id', () => {
        const el = mount(be39('choice'), 'compact');
        const choose = jest.fn();
        el.addEventListener('cardchoose', choose);
        expect(q(el, '.cs-title-text').textContent).toBe('Several accounts match "Edge". Which one?');
        expect(qa(el, '.cs-item')).toHaveLength(2);
        qa(el, '.cs-item button')[1].click();
        expect(choose.mock.calls[0][0].detail).toMatchObject({ cardKey: 'cho', fieldKey: null, ref: 'a2', recordId: 'record-id:a2' });
    });

    test('notice from the resolver: NOT_FOUND as a word, the sentence as prose', () => {
        const el = mount(be39('notice'), 'compact');
        expect(q(el, '.cs-p').textContent).toBe('No account matches "Edgx". Try a fuller or different account name.');
        expect(q(el, '.cs-badge').textContent).toBe('Not found');
        expect(q(el, 'article').getAttribute('aria-label')).toBe('Note');
    });

    test('record from a drill: fields, the account as a link, related objects as chips', () => {
        const el = mount(be39('record'), 'compact');
        const open = jest.fn();
        const ask = jest.fn();
        el.addEventListener('cardopen', open);
        el.addEventListener('cardask', ask);
        expect(q(el, '.cs-title-text').textContent).toBe('Panel Deal');
        expect(qa(el, '.cs-dt').map((d) => d.textContent)).toEqual(['Account', 'Stage', 'Amount', 'Close Date']);
        q(el, '.cs-field button.cs-link').click();
        expect(open.mock.calls[0][0].detail).toEqual({ ref: 'a1', recordId: 'record-id:a1', objectName: 'Account' });
        const chips = qa(el, '[aria-label="Related records"] button');
        expect(chips.map((b) => b.textContent)).toEqual(['Tasks', 'Opportunity Contact Roles']);
        chips[1].click();
        expect(ask.mock.calls[0][0].detail).toEqual({ text: 'Opportunity Contact Roles' });
    });
});

describe('rich text is drawn from body runs', () => {
    test('a section with no lines draws its body runs, links included', () => {
        const card = {
            type: 'section',
            version: 1,
            key: 'sec-x',
            title: 'Calls',
            status: 'OK',
            text: 'Calls\nOne call about Edge SLA',
            body: [{ kind: 'p', runs: [{ text: 'One ' }, { text: 'call', strong: true }, { text: ' about ' }, { text: 'Edge SLA', ref: 'o1' }] }],
            refs: [{ key: 'o1', recordId: 'record-id:o1', objectName: 'Opportunity', label: 'Edge SLA' }]
        };
        const el = mount(card);
        q(el, '.cs-toggle').click();
        return flush().then(() => {
            expect(q(el, '.cs-p strong').textContent).toBe('call');
            expect(q(el, '.cs-p button.cs-link').textContent).toBe('Edge SLA');
        });
    });

    test('markup in a value stays text', () => {
        const el = mount({ type: 'text', version: 1, body: [{ kind: 'p', runs: [{ text: '<img src=x onerror=alert(1)>' }] }], text: 'x' });
        expect(q(el, 'img')).toBeNull();
        expect(q(el, '.cs-p').textContent).toBe('<img src=x onerror=alert(1)>');
    });

    test('a link to a ref the card does not carry is plain text', () => {
        const el = mount({ type: 'text', version: 1, body: [{ kind: 'p', runs: [{ text: 'Edge SLA', ref: 'zz' }] }], text: 'Edge SLA', refs: [] });
        expect(q(el, 'button')).toBeNull();
        expect(q(el, '.cs-p').textContent).toBe('Edge SLA');
    });
});

describe('the four events', () => {
    test('cardopen: a record link gives its ref, Id and object, and bubbles out of the shadow', () => {
        const el = mount(fixture('text'));
        const open = jest.fn();
        document.body.addEventListener('cardopen', open);
        q(el, 'button.cs-link').click();
        document.body.removeEventListener('cardopen', open);
        expect(open).toHaveBeenCalledTimes(1);
        expect(open.mock.calls[0][0].detail).toEqual({ ref: 'o1', recordId: 'record-id:o1', objectName: 'Opportunity' });
    });

    test('cardchoose and cardaction: a draft field choice and its controls, once the action types are drawn', () =>
        withActions(async () => {
            const el = mount(fixture('actionDraft'));
            await flush();
            expect(q(el, '.cs-dd-missing').textContent).toBe('Needed');
            expect(qa(el, '.cs-choices button').map((b) => b.textContent)).toEqual(['Jordan Lee', 'Jordan Park']);
            expect(qa(el, '.cs-controls button').map((b) => b.textContent)).toEqual(['Confirm', 'Edit', 'Cancel']);
            const action = jest.fn();
            const choose = jest.fn();
            document.body.addEventListener('cardaction', action);
            document.body.addEventListener('cardchoose', choose);
            qa(el, '.cs-controls button')[0].click();
            qa(el, '.cs-choices button')[1].click();
            document.body.removeEventListener('cardaction', action);
            document.body.removeEventListener('cardchoose', choose);
            expect(action.mock.calls[0][0].detail).toEqual({ cardKey: 'drf', control: 'confirm' });
            expect(choose.mock.calls[0][0].detail).toEqual({ cardKey: 'drf', fieldKey: 'WhoId', ref: 'c4', recordId: 'record-id:c4' });
        }));

    test('cardopen from an action result, once drawn', () =>
        withActions(async () => {
            const el = mount(fixture('actionResult'));
            const open = jest.fn();
            el.addEventListener('cardopen', open);
            q(el, '.cs-field button.cs-link').click();
            expect(open.mock.calls[0][0].detail).toEqual({ ref: 't9', recordId: 'record-id:t9', objectName: 'Task' });
            expect(q(el, '.cs-controls button').textContent).toBe('Open task');
        }));

    test('cardask: a follow-up chip, bubbling and composed', () => {
        const el = mount(fixture('followups'));
        const ask = jest.fn();
        document.body.addEventListener('cardask', ask);
        qa(el, '.cs-chip')[1].click();
        document.body.removeEventListener('cardask', ask);
        expect(ask).toHaveBeenCalledTimes(1);
        expect(ask.mock.calls[0][0].bubbles).toBe(true);
        expect(ask.mock.calls[0][0].composed).toBe(true);
    });
});

describe('fallbacks render the card text', () => {
    test.each(FALLBACKS.map((c) => [c.key, c]))('%s', (name, card) => {
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

    test('no card at all renders an empty fallback without throwing', () => {
        const el = mount(null, 'compact');
        expect(q(el, '.cs-fallback')).not.toBeNull();
    });
});

describe('density', () => {
    test('defaults to compact', () => {
        const el = createElement('c-customer-summary-card', { is: CustomerSummaryCard });
        el.card = fixture('table');
        document.body.appendChild(el);
        expect(el.density).toBe('compact');
        expect(q(el, 'table')).toBeNull();
        expect(qa(el, '.cs-stack-row')).toHaveLength(5);
    });

    test('a list folds at 5 compact and at 10 comfortable, the count line pinned', () => {
        const items = Array.from({ length: 12 }, (v, i) => ({ label: 'Contact ' + i, ref: 'c' + i }));
        const refs = items.map((i) => ({ key: i.ref, recordId: 'record-id:' + i.ref, objectName: 'Contact', label: i.label }));
        const card = { type: 'recordList', version: 1, key: 'lst', title: 'Contacts', text: 'Contacts', items, refs, total: 40, shown: 12 };
        const compact = mount(card, 'compact');
        expect(qa(compact, '.cs-item')).toHaveLength(5);
        expect(q(compact, '.cs-more').textContent).toBe('Show 7 more');
        expect(q(compact, '.cs-count').textContent).toBe('Showing 12 of 40 records');
        const comfortable = mount(card, 'comfortable');
        expect(qa(comfortable, '.cs-item')).toHaveLength(10);
        expect(q(comfortable, '.cs-more').textContent).toBe('Show 2 more');
        expect(q(comfortable, '.cs-count').textContent).toBe('Showing 12 of 40 records');
    });
});

describe('keyboard: one Tab stop per list', () => {
    test('a list of record links is one Tab stop; arrows, Home and End move inside it', async () => {
        const el = mount(fixture('recordList'));
        await flush();
        const links = () => qa(el, '.cs-items button.cs-link');
        expect(links().map((b) => b.getAttribute('tabindex'))).toEqual(['0', '-1', '-1']);
        key(links()[0], 'ArrowDown');
        expect(links().map((b) => b.getAttribute('tabindex'))).toEqual(['-1', '0', '-1']);
        key(links()[1], 'End');
        expect(links().map((b) => b.getAttribute('tabindex'))).toEqual(['-1', '-1', '0']);
        key(links()[2], 'Home');
        expect(links().map((b) => b.getAttribute('tabindex'))).toEqual(['0', '-1', '-1']);
    });

    test('a table whose rows link is one Tab stop through its row heads; its scroll area adds none', async () => {
        const el = mount(fixture('table'));
        await flush();
        const heads = qa(el, 'tbody th button.cs-link');
        expect(heads.map((b) => b.getAttribute('tabindex'))).toEqual(['0', '-1', '-1', '-1', '-1', '-1']);
        expect(q(el, '.cs-table-wrap').hasAttribute('tabindex')).toBe(false);
    });

    test('a table with no row links keeps a focusable scroll area so a keyboard can scroll it', () => {
        const el = mount(fixture('comparison'));
        expect(q(el, '.cs-table-wrap').getAttribute('tabindex')).toBe('0');
    });

    test('stacked rows are one Tab stop', async () => {
        const el = mount(fixture('table'), 'compact');
        await flush();
        const heads = qa(el, '.cs-stack button.cs-link');
        expect(heads.map((b) => b.getAttribute('tabindex'))).toEqual(['0', '-1', '-1', '-1', '-1']);
    });

    test('focusLink focuses the link to a ref, and says false when there is none', async () => {
        const card = fixture('recordList');
        const el = mount(card);
        await flush();
        const second = qa(el, '.cs-items button.cs-link')[1];
        expect(el.focusLink(second.dataset.ref)).toBe(true);
        expect(el.shadowRoot.activeElement).toBe(second);
        expect(el.focusLink('no-such-ref')).toBe(false);
    });
});

describe('safety', () => {
    test('no record Id is in the rendered markup, at either density, with every fold open', async () => {
        for (const density of ['compact', 'comfortable']) {
            for (const card of ALL) {
                const el = mount(card, density);
                qa(el, '.cs-toggle').forEach((t) => t.getAttribute('aria-expanded') === 'false' && t.click());
                // eslint-disable-next-line no-await-in-loop
                await flush();
                qa(el, '.cs-more').forEach((m) => m.click());
                // eslint-disable-next-line no-await-in-loop
                await flush();
                expect(el.shadowRoot.innerHTML).not.toContain('record-id:');
                document.body.removeChild(el);
            }
        }
    });

    test('no inner-html, no innerHTML, no href and no parser call on card text in the source', () => {
        expect(SOURCE_HTML).not.toMatch(/inner-html/i);
        expect(SOURCE_HTML).not.toMatch(/href/i);
        expect(SOURCE_JS).not.toMatch(/innerHTML|outerHTML|insertAdjacentHTML/);
        expect(SOURCE_CONTRACT).not.toMatch(/innerHTML|outerHTML|insertAdjacentHTML/);
        expect(SOURCE_JS).not.toMatch(/parseRich|parseInline/);
    });

    test('every colour, font and radius comes from the theme variables', () => {
        const css = SOURCE_CSS.replace(/\/\*[\s\S]*?\*\//g, '');
        const read = new Set([...css.matchAll(/var\((--[\w-]+)/g)].map((m) => m[1]));
        const own = new Set([...css.matchAll(/(--cs-card-[\w-]+)\s*:/g)].map((m) => m[1]));
        const foreign = [...read].filter((v) => !THEME.includes(v) && !own.has(v) && v !== '--slds-g-color-error-1');
        expect(foreign).toEqual([]);
        const withoutVars = css.replace(/var\(--[\w-]+,\s*[^)]*\)/g, '');
        expect(withoutVars.match(/#[0-9A-Fa-f]{3,8}\b/g)).toBeNull();
        expect(withoutVars.match(/\brgba?\(|\bhsla?\(/g)).toBeNull();
        const fonts = [...withoutVars.matchAll(/font-family:([^;]*);/g)].map((m) => m[1].trim()).filter((f) => f && f !== 'inherit');
        expect(fonts).toEqual([]);
        const radii = [...css.matchAll(/border-radius:\s*([^;]+);/g)].map((m) => m[1].trim());
        radii.forEach((r) => expect(r).toMatch(/^var\(--cs-(card-)?radius/));
    });

    test('a record link, a chip and a fold button meet the 24 px target size', () => {
        const css = SOURCE_CSS.replace(/\/\*[\s\S]*?\*\//g, '');
        const rule = /([^{}]*)\{[^}]*min-height:\s*24px;[^}]*min-width:\s*24px;[^}]*\}/.exec(css);
        expect(rule).not.toBeNull();
        ['.cs-link', '.cs-toggle', '.cs-chip', '.cs-btn', '.cs-more'].forEach((sel) => expect(rule[1]).toContain(sel));
    });
});

describe('accessibility', () => {
    test.each(ALL.map((c) => [c.type + ':' + c.key + ':' + c.status, c]))('%s has no violations, compact and comfortable', async (name, card) => {
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

    test('the drawn action types have no violations', () =>
        withActions(async () => {
            mount(fixture('actionDraft'), 'compact');
            mount(fixture('actionResult'), 'comfortable');
            await flush();
            await expect(document.body).toBeAccessible();
        }));
});
