/**
 * coworkerSpikeCardRenderer (FE-24): the thin renderer a spike Lightning type names for the Coworker check.
 * It takes the type's properties one by one (renderer.json maps each to an @api property), puts the card
 * back together and hands it to c-customer-summary-card at density compact.
 *
 * Done when (card FE-24): it renders a card from BE-39's JSON example, falls back to the card's text on
 * an unknown type, has no record Id in the markup, and passes toBeAccessible().
 *
 * BE-39's example is read from its own page (docs/research/fr2-card-contract-apex.md, "### `summary`
 * (sum)"), so this test draws the example as published, not a copy of it.
 */
import { createElement } from 'lwc';
import CoworkerSpikeCardRenderer from 'c/coworkerSpikeCardRenderer';

const mockNavigate = jest.fn();
jest.mock(
    'lightning/navigation',
    () => {
        const Navigate = Symbol('Navigate');
        const NavigationMixin = (Base) =>
            class extends Base {
                [Navigate](pageReference) {
                    mockNavigate(pageReference);
                }
            };
        NavigationMixin.Navigate = Navigate;
        return { NavigationMixin };
    }
);

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..', '..', '..', '..', '..', '..', '..');
const BE39_PAGE = path.join(ROOT, 'docs', 'research', 'fr2-card-contract-apex.md');

/** The first ```json block under the page's "### `summary` (sum)" heading. */
function be39Summary() {
    const page = fs.readFileSync(BE39_PAGE, 'utf8');
    const at = page.indexOf('### `summary` (sum)');
    if (at < 0) {
        throw new Error('BE-39 page has no summary example');
    }
    const block = /```json\n([\s\S]*?)\n```/.exec(page.slice(at));
    return JSON.parse(block[1]);
}

// A record Id as the platform writes one: 15 or 18 characters, starting with a key prefix.
const SAMPLE_ID = '001000000000001AAA';
const ID_PATTERN = /\b[a-zA-Z0-9]{3}0{3,}[a-zA-Z0-9]{9,12}\b/;

const flush = () => Promise.resolve();

/** Mounts the renderer the way renderer.json binds it: one attribute per type property. */
function mount(card) {
    const el = createElement('c-coworker-spike-card-renderer', { is: CoworkerSpikeCardRenderer });
    el.cardType = card.type;
    el.cardVersion = card.version;
    el.cardKey = card.key;
    el.cardTitle = card.title;
    el.cardMeta = card.meta;
    el.cardStatus = card.status;
    el.cardText = card.text;
    el.cardBody = card.body;
    el.cardRefs = card.refs;
    document.body.appendChild(el);
    return el;
}

function inner(el) {
    return el.shadowRoot.querySelector('c-customer-summary-card');
}

function cardRoot(el) {
    return inner(el).shadowRoot;
}

/** Every bit of markup the viewer could see: the wrapper's and the card's. */
function allMarkup(el) {
    return el.shadowRoot.innerHTML + cardRoot(el).innerHTML;
}

afterEach(() => {
    while (document.body.firstChild) {
        document.body.removeChild(document.body.firstChild);
    }
    mockNavigate.mockReset();
});

describe('coworkerSpikeCardRenderer', () => {
    test("renders BE-39's summary example through c-customer-summary-card at compact", () => {
        const card = be39Summary();
        const el = mount(card);
        return flush().then(() => {
            const child = inner(el);
            expect(child).not.toBeNull();
            expect(child.density).toBe('compact');
            expect(child.card).toEqual(card);
            const root = cardRoot(el);
            expect(root.querySelector('.cs-title-text').textContent).toBe(card.title);
            expect(Array.from(root.querySelectorAll('.cs-p strong')).map((s) => s.textContent)).toEqual(['Open deals:', 'Service health:']);
            expect(root.querySelectorAll('.cs-ul li')).toHaveLength(2);
        });
    });

    test("an unknown type falls back to the card's text", () => {
        const card = Object.assign(be39Summary(), { type: 'coworkerOnlyType' });
        const el = mount(card);
        return flush().then(() => {
            const root = cardRoot(el);
            expect(root.querySelector('.cs-title-text')).toBeNull();
            const shown = root.textContent;
            card.text.split('\n').forEach((line) => {
                expect(shown).toContain(line.replace(/^- /, ''));
            });
        });
    });

    test('no record Id in the markup; a record link is a button that navigates by Id', () => {
        const card = be39Summary();
        card.refs = [{ key: 'o1', recordId: SAMPLE_ID, objectName: 'Opportunity', label: 'Edge Emergency Generator' }];
        card.body = card.body.concat([{ kind: 'p', runs: [{ text: 'Largest deal: ' }, { text: 'Edge Emergency Generator', ref: 'o1' }] }]);
        const el = mount(card);
        return flush().then(() => {
            expect(allMarkup(el)).not.toContain(SAMPLE_ID);
            expect(ID_PATTERN.test(allMarkup(el))).toBe(false);
            expect(cardRoot(el).querySelector('a[href]')).toBeNull();
            const link = cardRoot(el).querySelector('button.cs-link');
            expect(link.textContent).toBe('Edge Emergency Generator');
            link.click();
            expect(mockNavigate).toHaveBeenCalledTimes(1);
            expect(mockNavigate.mock.calls[0][0]).toEqual({
                type: 'standard__recordPage',
                attributes: { recordId: SAMPLE_ID, objectApiName: 'Opportunity', actionName: 'view' }
            });
        });
    });

    test('no card at all shows nothing, and never throws', () => {
        const el = createElement('c-coworker-spike-card-renderer', { is: CoworkerSpikeCardRenderer });
        document.body.appendChild(el);
        return flush().then(() => {
            expect(inner(el)).toBeNull();
        });
    });

    test('passes toBeAccessible() for the example and for the fallback', async () => {
        const el = mount(be39Summary());
        await flush();
        await expect(el).toBeAccessible();
        document.body.removeChild(el);
        const fallback = mount(Object.assign(be39Summary(), { type: 'coworkerOnlyType' }));
        await flush();
        await expect(fallback).toBeAccessible();
    });
});
