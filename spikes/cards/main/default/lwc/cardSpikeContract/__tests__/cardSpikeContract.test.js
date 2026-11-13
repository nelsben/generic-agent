/**
 * The FE-18 contract: the rich-text grammar's test vectors, the plain-text rule per type, the three
 * fallbacks, and that the research page's JSON examples are these fixtures, byte for byte as JSON.
 */
const fs = require('fs');
const path = require('path');
import { parseRich, parseInline, plainText, viewOf, checkCard, TYPES } from 'c/cardSpikeContract';
import { FIXTURES } from 'c/cardSpikeFixtures';

const PAGE = path.join(__dirname, '..', '..', '..', '..', '..', '..', '..', 'docs', 'research', 'fr2-card-architecture.md');
const REFS = { o1: { key: 'o1', recordId: 'record-id:o1', objectName: 'Opportunity', label: 'Edge SLA' } };

describe('rich text: the grammar vectors in the page', () => {
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
        ['**unclosed', [{ text: '**unclosed' }]]
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

    test.each(FIXTURES.map((c) => [c.type + ':' + c.key, c]))('%s: text is its rule, no Id, no markup, JSON round trip', (name, card) => {
        expect(checkCard(card)).toEqual([]);
        expect(JSON.parse(JSON.stringify(card))).toEqual(card);
        const view = viewOf(card, 'compact');
        expect(view.isFallback).toBe(false);
    });

    test('no fixture holds a Map- or Object-typed member: every cell is a string', () => {
        FIXTURES.filter((c) => c.rows).forEach((c) => c.rows.forEach((r) => r.cells.forEach((v) => expect(typeof v).toBe('string'))));
    });

    test('a table card agrees with its own counts', () => {
        const t = FIXTURES.find((c) => c.type === 'table');
        expect(t.rows.length).toBe(t.shown);
        expect(plainText(t)).toContain('(6 of 212 rows)');
        expect(viewOf(t, 'comfortable').countText).toBe('Showing 6 of 212 rows');
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

    test('a card with no text falls back to its rule', () => {
        const v = viewOf({ type: 'nope', version: 1 });
        expect(v.isFallback).toBe(true);
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
        expect(viewOf(t, 'compact')).toMatchObject({ canFold: true, foldAt: 5, hiddenCount: 1 });
        expect(viewOf(t, 'comfortable')).toMatchObject({ canFold: false });
    });
});

describe('the research page', () => {
    test('quotes every fixture as its JSON example, unchanged', () => {
        const page = fs.readFileSync(PAGE, 'utf8');
        const blocks = [...page.matchAll(/<!-- card:([A-Za-z]+):([a-z0-9-]+) -->\s*```json\n([\s\S]*?)\n```/g)];
        const byKey = Object.fromEntries(blocks.map((m) => [m[2], JSON.parse(m[3])]));
        FIXTURES.forEach((c) => expect(byKey[c.key]).toEqual(c));
        expect(blocks.length).toBe(FIXTURES.length);
    });
});
