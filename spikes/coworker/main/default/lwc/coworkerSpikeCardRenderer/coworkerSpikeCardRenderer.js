/**
 * coworkerSpikeCardRenderer (FE-24 spike): the output renderer of the spike Lightning type
 * coworkerSpikeSummaryCard. It puts one card of the FR2 card contract (FE-18, BE-39) back together from
 * the type's properties and hands it to the shared card component, c-customer-summary-card, at density
 * compact. It draws nothing itself.
 *
 * Interface (renderer.json maps each type property to one of these):
 *   @api cardType, cardVersion, cardKey, cardTitle, cardMeta, cardStatus, cardText, cardBody, cardRefs
 *       the card's type, version, key, title, meta, status, text, body and refs, as BE-39's AnswerCard
 *       serializes them. The names carry a "card" prefix so none is an HTML global attribute.
 *
 * A record link is a button in the card that fires cardopen with the record's Id in its detail; this
 * renderer, as the card's host, navigates to that record. No Id is written to the markup.
 *
 * An unknown type, a newer version or a card the shared component cannot draw shows the card's text:
 * that fallback is the shared component's own, so this renderer does not repeat it.
 *
 * It imports nothing from force-app. c-customer-summary-card is resolved by name in the org's c
 * namespace, where the product deploy already put it.
 */
import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class CoworkerSpikeCardRenderer extends NavigationMixin(LightningElement) {
    @api cardType;
    @api cardVersion;
    @api cardKey;
    @api cardTitle;
    @api cardMeta;
    @api cardStatus;
    @api cardText;
    @api cardBody;
    @api cardRefs;

    /** Whether there is anything to hand the card: a type or at least its text. */
    get hasCard() {
        return Boolean(this.cardType) || Boolean(this.cardText);
    }

    /** The card as the contract has it. Absent members stay absent, as in BE-39's JSON. */
    get card() {
        const card = {
            type: this.cardType,
            version: this.cardVersion,
            key: this.cardKey,
            title: this.cardTitle,
            meta: this.cardMeta,
            status: this.cardStatus,
            text: this.cardText,
            body: Array.isArray(this.cardBody) ? this.cardBody : [],
            refs: Array.isArray(this.cardRefs) ? this.cardRefs : []
        };
        Object.keys(card).forEach((k) => {
            if (card[k] === undefined || card[k] === null) {
                delete card[k];
            }
        });
        return card;
    }

    handleOpen(event) {
        event.stopPropagation();
        const detail = event.detail || {};
        if (!detail.recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: detail.recordId, objectApiName: detail.objectName, actionName: 'view' }
        });
    }
}
