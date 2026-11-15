/** FE-24 spike only. A record a card links to: AnswerCard.Ref as a top-level class, the only place an Id appears. */
@JsonAccess(serializable='always' deserializable='always')
global with sharing class CoworkerSpikeCardRef {
    @AuraEnabled global String key;
    @AuraEnabled global String recordId;
    @AuraEnabled global String objectName;
    @AuraEnabled global String label;
}
