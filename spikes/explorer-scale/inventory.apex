// BE-31 inventory probe: how big a describe-driven catalog would be in this org, and what it costs to build.
// Read-only: describe calls and COUNT() queries only. Prints counts, never names of records or Ids.
Integer cpu0 = Limits.getCpuTime();
Map<String, Schema.SObjectType> g = Schema.getGlobalDescribe();
Integer total = g.size(), queryable = 0, custom = 0, customQueryable = 0, searchable = 0;
List<String> candidates = new List<String>();
for (String k : g.keySet()) {
    String n = k.toLowerCase();
    Boolean isCustom = n.endsWith('__c');
    if (isCustom) custom++;
    // Cheap filter by name first: system families never belong in a business catalog.
    if (n.endsWith('__share') || n.endsWith('history') || n.endsWith('feed') || n.endsWith('changeevent')
        || n.endsWith('__mdt') || n.endsWith('__e') || n.endsWith('__x') || n.endsWith('__b') || n.endsWith('__kav')
        || n.endsWith('tag') || n.endsWith('__chn')) continue;
    candidates.add(k);
}
Integer cpuGlobal = Limits.getCpuTime() - cpu0;
Integer described = 0, fieldsTotal = 0, encrypted = 0, longText = 0, notFilterable = 0, sensitiveNamed = 0, customFields = 0;
Integer promptChars = 0;
Integer cpu1 = Limits.getCpuTime();
Boolean stoppedEarly = false;
Set<String> sensitive = new Set<String>{'ssn','password','secret','token','salary','dateofbirth','birthdate','taxid','creditcard'};
for (String k : candidates) {
    if (Limits.getCpuTime() > 8500) { stoppedEarly = true; break; }
    Schema.DescribeSObjectResult d = g.get(k).getDescribe(SObjectDescribeOptions.DEFERRED);
    if (!d.isAccessible() || !d.isQueryable() || d.isDeprecatedAndHidden()) continue;
    queryable++;
    if (d.isCustom()) customQueryable++;
    if (d.isSearchable()) searchable++;
    described++;
    Integer lineChars = d.getName().length() + 2;
    for (Schema.SObjectField sf : d.fields.getMap().values()) {
        Schema.DescribeFieldResult fd = sf.getDescribe();
        if (!fd.isAccessible()) continue;
        fieldsTotal++;
        if (fd.isCustom()) customFields++;
        if (fd.isEncrypted()) encrypted++;
        if (!fd.isFilterable()) notFilterable++;
        if (fd.getType() == Schema.DisplayType.TEXTAREA && fd.getLength() > 255) longText++;
        String fl = fd.getName().toLowerCase().replace('_', '');
        for (String s : sensitive) { if (fl.contains(s)) { sensitiveNamed++; break; } }
        lineChars += fd.getName().length() + String.valueOf(fd.getType()).length() + 4;
    }
    promptChars += lineChars;
}
Integer cpuDescribe = Limits.getCpuTime() - cpu1;
System.debug(LoggingLevel.ERROR, 'INV :: globalDescribe objects=' + total + ' custom=' + custom + ' nameFilteredCandidates=' + candidates.size() + ' cpuMs=' + cpuGlobal);
System.debug(LoggingLevel.ERROR, 'INV :: described=' + described + ' accessibleQueryable=' + queryable + ' customQueryable=' + customQueryable + ' searchable=' + searchable + ' cpuMs=' + cpuDescribe + ' heapBytes=' + Limits.getHeapSize() + ' stoppedEarly=' + stoppedEarly);
System.debug(LoggingLevel.ERROR, 'INV :: fields=' + fieldsTotal + ' customFields=' + customFields + ' encrypted=' + encrypted + ' longText=' + longText + ' notFilterable=' + notFilterable + ' sensitiveByName=' + sensitiveNamed);
System.debug(LoggingLevel.ERROR, 'INV :: allFieldsPromptChars=' + promptChars + ' approxTokens=' + (promptChars / 4) + ' currentCatalogChars=' + ExploreCatalog.describeForPrompt().length());
// Record volumes on the objects the 30 questions use (counts only).
for (String o : new List<String>{'Account','Contact','Opportunity','OpportunityContactRole','Case','Task','Event','Lead','Campaign','CampaignMember','Contract','Asset','Product2','OpportunityLineItem','User','CaseComment','EmailMessage','Note','ContentDocumentLink'}) {
    try {
        Integer c = Database.countQuery('SELECT COUNT() FROM ' + o + ' LIMIT 50000', AccessLevel.USER_MODE);
        System.debug(LoggingLevel.ERROR, 'INV :: count ' + o + '=' + c);
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'INV :: count ' + o + '=unavailable (' + e.getTypeName() + ')');
    }
}
