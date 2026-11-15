/**
 * FE-24 spike only. One card of the FR2 card contract (FE-18, BE-39) as the Apex class behind the spike
 * Lightning type coworkerSpikeSummaryCard (lightningTypes/coworkerSpikeSummaryCard/schema.json).
 *
 * Its members are the members BE-39's summary card carries (docs/research/fr2-card-contract-apex.md,
 * "### `summary` (sum)"), with the same names and types as AnswerCard: type, version, key, title, meta,
 * status, text, body and refs. A Lightning type projects its structure from these @AuraEnabled members.
 * The Apex types guide asks for a top-level global class with @JsonAccess and no inner classes, so the
 * parts (block, run, ref) are their own top-level classes rather than AnswerCard's inner ones.
 *
 * No query, DML or callout here. The product's AnswerCard is not changed and not referenced.
 */
@JsonAccess(serializable='always' deserializable='always')
global with sharing class CoworkerSpikeSummaryCard {
    @AuraEnabled global String type;
    @AuraEnabled global Integer version;
    @AuraEnabled global String key;
    @AuraEnabled global String title;
    @AuraEnabled global String meta;
    @AuraEnabled global String status;
    @AuraEnabled global String text;
    @AuraEnabled global List<CoworkerSpikeCardBlock> body = new List<CoworkerSpikeCardBlock>();
    @AuraEnabled global List<CoworkerSpikeCardRef> refs = new List<CoworkerSpikeCardRef>();

    /**
     * The first card of the given type in a cards JSON list (the `cards` output of BE-39's invocables),
     * or null when there is none or the JSON cannot be read. Members this class lacks (items, total, ...)
     * are ignored by JSON.deserialize, so a section card read here would lose its items: only the summary
     * card is read.
     */
    global static CoworkerSpikeSummaryCard firstOf(String cardsJson, String cardType) {
        if (String.isBlank(cardsJson)) {
            return null;
        }
        try {
            List<CoworkerSpikeSummaryCard> cards = (List<CoworkerSpikeSummaryCard>) JSON.deserialize(
                cardsJson,
                List<CoworkerSpikeSummaryCard>.class
            );
            for (CoworkerSpikeSummaryCard c : cards) {
                if (c != null && c.type == cardType) {
                    if (c.body == null) {
                        c.body = new List<CoworkerSpikeCardBlock>();
                    }
                    if (c.refs == null) {
                        c.refs = new List<CoworkerSpikeCardRef>();
                    }
                    return c;
                }
            }
        } catch (Exception e) {
            return null;
        }
        return null;
    }

    /** A notice card: literal text, one `p` block per line, as AnswerCard.notice writes it. */
    global static CoworkerSpikeSummaryCard notice(String status, String message) {
        CoworkerSpikeSummaryCard c = new CoworkerSpikeSummaryCard();
        c.type = 'notice';
        c.version = 1;
        c.key = 'not';
        c.title = '';
        c.status = status;
        c.text = message == null ? '' : message;
        for (String line : c.text.split('\n')) {
            if (String.isBlank(line)) {
                continue;
            }
            CoworkerSpikeCardRun r = new CoworkerSpikeCardRun();
            r.text = line.trim();
            CoworkerSpikeCardBlock b = new CoworkerSpikeCardBlock();
            b.kind = 'p';
            b.runs.add(r);
            c.body.add(b);
        }
        return c;
    }
}
