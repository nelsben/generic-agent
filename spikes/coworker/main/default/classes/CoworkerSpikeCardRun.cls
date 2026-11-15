/** FE-24 spike only. One run of a line: AnswerCard.Run as a top-level class. The Booleans are set only when true. */
@JsonAccess(serializable='always' deserializable='always')
global with sharing class CoworkerSpikeCardRun {
    @AuraEnabled global String text;
    @AuraEnabled global Boolean strong;
    @AuraEnabled global Boolean em;
    @AuraEnabled global Boolean code;
    /** A ref key from the card's refs; never an Id. */
    @AuraEnabled global String ref;
}
