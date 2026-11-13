import { createElement } from 'lwc';
import CardSpikeGallery from 'c/cardSpikeGallery';
import { FIXTURES } from 'c/cardSpikeFixtures';

describe('cardSpikeGallery', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    test('every fixture and the three fallbacks, once per width', () => {
        const el = createElement('c-card-spike-gallery', { is: CardSpikeGallery });
        document.body.appendChild(el);
        const compact = el.shadowRoot.querySelectorAll('.cg-340 c-card-spike-card');
        const wide = el.shadowRoot.querySelectorAll('.cg-640 c-card-spike-card');
        expect(compact.length).toBe(FIXTURES.length + 3);
        expect(wide.length).toBe(FIXTURES.length + 3);
        expect(el.shadowRoot.querySelectorAll('[data-capture]').length).toBe(6);
    });

    test('a card event is named in the live line without its Id', async () => {
        const el = createElement('c-card-spike-gallery', { is: CardSpikeGallery });
        document.body.appendChild(el);
        const card = el.shadowRoot.querySelector('.cg-640 c-card-spike-card');
        card.dispatchEvent(new CustomEvent('cardopen', { detail: { ref: 'o1', recordId: 'record-id:o1', objectName: 'Opportunity' }, bubbles: true, composed: true }));
        await Promise.resolve();
        const line = el.shadowRoot.querySelector('.cg-note').textContent;
        expect(line).toBe('Last card event: cardopen · Opportunity');
        await expect(el).toBeAccessible();
    });
});
