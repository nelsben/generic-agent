/**
 * cardSpikeGallery: every FE-18 fixture card at the compact width (340 px) and the rail width
 * (640 px), side by side, plus the three fallbacks (spike, not product code). The capture script in
 * spikes/cards/__tests__/ photographs each column. Brand variables are set on the wrapper the way a
 * surface sets them on its host; these are neutral stand-ins, not a brand.
 */
import { LightningElement } from 'lwc';
import { FIXTURES } from 'c/cardSpikeFixtures';

const GROUPS = [
    { key: 'summary', title: 'Summary', types: ['summary', 'section', 'metric', 'timeline'] },
    { key: 'explorer', title: 'Explorer', types: ['text', 'table', 'notice', 'trail', 'followups', 'comparison', 'record', 'recordList'] },
    { key: 'actions', title: 'Actions, choices and failures', types: ['choice', 'actionDraft', 'actionResult', 'error', 'fallback'] }
];

// The three fallbacks: a type this renderer does not know, a version above the registry's, and a
// card whose builder throws (an item that is not an object). Each shows its own plain text.
export const FALLBACKS = [
    { type: 'mapPins', version: 1, key: 'fb-type', title: 'Accounts near Austin', text: 'Accounts near Austin\n- Edge Communications — 2 km\n- Edgewater Freight — 9 km' },
    { type: 'table', version: 2, key: 'fb-version', title: 'Opportunity', text: 'Opportunity\nName | Stage\nEdge SLA | Qualification' },
    { type: 'recordList', version: 1, key: 'fb-throw', title: 'Contacts', items: [null], text: 'Contacts\n- Jordan Lee — VP Facilities' }
];

const BRAND = [
    '--cs-color-primary: #0b5cab',
    '--cs-color-accent: #e9f2fb',
    '--cs-color-surface: #ffffff',
    '--cs-color-ink: #181818',
    '--cs-font-display: Georgia, "Times New Roman", serif',
    '--cs-font-body: -apple-system, "Segoe UI", Helvetica, Arial, sans-serif',
    '--cs-radius: 6px'
].join('; ');

export default class CardSpikeGallery extends LightningElement {
    lastEvent = 'No card event yet.';
    brandStyle = BRAND;

    get groups() {
        return GROUPS.map((g) => {
            const cards = [];
            g.types.forEach((t) => {
                const source = t === 'fallback' ? FALLBACKS : FIXTURES.filter((c) => c.type === t);
                source.forEach((c) => cards.push({ key: g.key + '-' + c.key, card: c }));
            });
            return { ...g, cards, id340: 'cards-340-' + g.key, id640: 'cards-640-' + g.key };
        });
    }

    handleCardEvent(event) {
        const d = event.detail || {};
        // Names the event and the object, never the Id.
        this.lastEvent = 'Last card event: ' + event.type + (d.objectName ? ' · ' + d.objectName : '') + (d.control ? ' · ' + d.control : '') + (d.text ? ' · ' + d.text : '');
    }
}
