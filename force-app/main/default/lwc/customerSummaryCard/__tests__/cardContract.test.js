/**
 * The card contract module (ported from spikes/cards/ cardSpikeContract): the rich-text grammar's test
 * vectors, the plain-text rule per type, the fallbacks, the density rules, and that both research
 * pages' JSON examples are the fixtures. One fixture differs from FE-18's page on purpose: its notice
 * said "Showing 50 of 212 rows" beside a table of "Showing 6 of 212 rows"; the fixture says 6.
 */
import { parseRich, parseInline, plainText, viewOf, checkCard, TYPES, FAMILY } from '../cardContract';
import { FIXTURES, BE39_FIXTURES } from './fixtures';

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..', '..', '..', '..', '..', '..');
const FE18_PAGE = path.join(ROOT, 'docs', 'research', 'fr2-card-architecture.md');
const BE39_PAGE = path.join(ROOT, 'docs', 'research', 'fr2-card-contract-apex.md');
const REFS = {
    o1: { key: 'o1', recordId: 'record-id:o1', objectName: 'Opportunity', label: 'Edge SLA' },
    o3: { key: 'o3', recordId: 'record-id:o3', objectName: 'Opportunity', label: 'Edge SLA' }
};

function examples(page) {
    const text = fs.readFileSync(page, 'utf8');
    return [...text.matchAll(/```json\n([\s\S]*?)\n```/g)]
        .map((m) => {
            try {
                return JSON.parse(m[1]);
            } catch (e) {
                return null;
            }
        })
        .filter((c) => c && typeof c === 'object' && !Array.isArray(c) && c.type);
}

describe('rich text: the grammar vectors in the page (for text a surface writes itself)', () => {
    const vectors = [
        ['plain', [{ text: 'plain' }]],
        ['**bold** and *em*', [{ text: 'bold', strong: true }, { text: ' and ' }, { text: 'em', em: true }]],
        ['5 * 3 = 15', [{ text: '5 * 3 = 15' }]],
        ['2 * 3 * 4', [{ text: '2 * 3 * 4' }]],
        ['run `ExploreQuery` now', [{ text: 'run ' }, { text: 'ExploreQuery', code: true }, { text: ' now' }]],
        ['see [Edge SLA](ref:o1)', [{ text: 'see ' }, { text: 'Edge SLA', ref: 'o1' }]],
        ['see [Edge SLA](ref:zz)', [{ text: 'see ' }, { text: 'Edge SLA' }]],
        ['[site](https://example.com)', [{ text: '[site](https://example.com)' }]],
        ['<b>x</b>', [{ text: '<b>x</b>' }]],
        ['**unclosed', [{ text: '**unclosed' }]],
        ['**212** open, *high priority*', [{ text: '212', strong: true }, { text: ' open, ' }, { text: 'high priority', em: true }]],
        ['costs `$250,000`', [{ text: 'costs ' }, { text: '$250,000', code: true }]]
    ];
    test.each(vectors)('%s', (input, runs) => {
        expect(parseInline(input, REFS)).toEqual(runs);
    });

    test('blocks: paragraphs, bullets and numbered items; blank lines only separate', () => {
        const blocks = parseRich('Intro line\n\n- one\n* two\n1. first\n2) second\n   \nEnd', REFS);
        expect(blocks.map((b) => b.kind)).toEqual(['p', 'li', 'p', 'ol', 'ol', 'p']);
        expect(blocks[1].runs).toEqual([{ text: 'one' }]);
        expect(blocks[2].runs).toEqual([{ text: '* two' }]);
    });

    test('a bullet with a link keeps the link run', () => {
        const blocks = parseRich('- [Edge SLA](ref:o1) closes soon', [REFS.o1]);
        expect(blocks[0]).toEqual({ kind: 'li', runs: [{ text: 'Edge SLA', ref: 'o1' }, { text: ' closes soon' }] });
    });
});

describe('fixtures: one per type, each valid', () => {
    test('every registered type has a fixture', () => {
        const types = new Set(FIXTURES.map((c) => c.type));
        Object.keys(TYPES).forEach((t) => expect(types.has(t)).toBe(true));
    });

    test.each(FIXTURES.concat(BE39_FIXTURES).map((c) => [c.type + ':' + c.key + ':' + c.status, c]))(
        '%s: text is its rule, no Id, no markup, JSON round trip',
        (name, card) => {
            expect(checkCard(card)).toEqual([]);
            expect(JSON.parse(JSON.stringify(card))).toEqual(card);
            const view = viewOf(card, 'compact');
            expect(view.isFallback).toBe(TYPES[card.type].ready === false);
        }
    );

    test('every cell is a string', () => {
        FIXTURES.filter((c) => c.rows).forEach((c) => c.rows.forEach((r) => r.cells.forEach((v) => expect(typeof v).toBe('string'))));
    });

    test('the table and the notice beside it agree on their counts', () => {
        const t = FIXTURES.find((c) => c.type === 'table');
        const n = FIXTURES.find((c) => c.type === 'notice');
        expect(t.rows.length).toBe(t.shown);
        expect(plainText(t)).toContain('(6 of 212 rows)');
        expect(viewOf(t, 'comfortable').countText).toBe('Showing 6 of 212 rows');
        expect(n.text).toContain('Showing 6 of 212 rows');
        expect(plainText(n)).toBe(n.text);
    });
});

describe('fallbacks', () => {
    test('an unknown type shows its text', () => {
        const v = viewOf({ type: 'mapPins', version: 1, text: 'A\nB' }, 'compact');
        expect(v).toMatchObject({ isFallback: true, reason: 'unknown-type' });
        expect(v.lines.map((l) => l.text)).toEqual(['A', 'B']);
    });

    test('a version above the registry shows its text; version 1 of the same type renders', () => {
        expect(viewOf({ type: 'table', version: 2, text: 'T' }).reason).toBe('unknown-version');
        expect(viewOf({ type: 'table', version: 1, text: 'T', columns: [], rows: [] }).isFallback).toBe(false);
    });

    test('a builder that throws shows its text', () => {
        const v = viewOf({ type: 'recordList', version: 1, items: [null], text: 'Contacts' });
        expect(v).toMatchObject({ isFallback: true, reason: 'render-error' });
    });

    test('the action types are registered but not drawn yet: their text shows', () => {
        ['actionDraft', 'actionResult'].forEach((type) => {
            expect(TYPES[type].family).toBe(FAMILY.FIELDS);
            const card = FIXTURES.find((c) => c.type === type);
            const v = viewOf(card, 'compact');
            expect(v).toMatchObject({ isFallback: true, reason: 'not-ready' });
            expect(v.lines.map((l) => l.text).join('\n')).toBe(card.text);
        });
    });

    test('a card with no text falls back to its rule; nothing at all is an empty fallback', () => {
        expect(viewOf({ type: 'nope', version: 1 }).isFallback).toBe(true);
        expect(viewOf(null).reason).toBe('empty');
    });
});

describe('density', () => {
    test('a table of more than 3 columns stacks at compact and stays a table at comfortable', () => {
        const t = FIXTURES.find((c) => c.type === 'table');
        expect(viewOf(t, 'compact').stacked).toBe(true);
        expect(viewOf(t, 'comfortable').stacked).toBe(false);
        expect(viewOf(FIXTURES.find((c) => c.type === 'comparison'), 'compact').stacked).toBe(true);
        expect(viewOf(FIXTURES.find((c) => c.type === 'comparison'), 'comfortable').stacked).toBe(false);
    });

    test('folding: 5 rows at compact, 10 at comfortable; the count line is not folded', () => {
        const t = FIXTURES.find((c) => c.type === 'table');
        expect(viewOf(t, 'compact')).toMatchObject({ canFold: true, foldAt: 5, hiddenCount: 1, countText: 'Showing 6 of 212 rows' });
        expect(viewOf(t, 'comfortable')).toMatchObject({ canFold: false });
    });
});

describe('the research pages', () => {
    test("FE-18's page quotes every FE-18 fixture, the notice's count aside", () => {
        const byKey = {};
        examples(FE18_PAGE).forEach((c) => {
            byKey[c.type + ':' + c.key + ':' + c.status] = c;
        });
        FIXTURES.forEach((c) => {
            const expected = c.type === 'notice' ? JSON.parse(JSON.stringify(c).split('Showing 6 of 212').join('Showing 50 of 212')) : c;
            expect(byKey[c.type + ':' + c.key + ':' + c.status]).toEqual(expected);
        });
    });

    test("BE-39's page quotes the three cards only it adds", () => {
        const page = examples(BE39_PAGE);
        BE39_FIXTURES.forEach((c) => expect(page).toContainEqual(c));
    });
});
