/** FE-24 spike only. One line of a card's rich text: AnswerCard.Block as a top-level class. */
@JsonAccess(serializable='always' deserializable='always')
global with sharing class CoworkerSpikeCardBlock {
    /** p, li or ol. */
    @AuraEnabled global String kind;
    @AuraEnabled global List<CoworkerSpikeCardRun> runs = new List<CoworkerSpikeCardRun>();
}
