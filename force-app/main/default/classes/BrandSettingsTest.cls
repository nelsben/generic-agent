@IsTest
private class BrandSettingsTest {
    /** A brand record held in memory: tests never depend on the values deployed in the org. */
    private static Brand_Setting__mdt northwind() {
        return new Brand_Setting__mdt(
            Agent_Name__c = 'Northwind Assist',
            Company_Name__c = 'Northwind Health',
            Logo_Resource__c = 'BrandLogo_Example',
            Primary_Color__c = '#0B6E4F',
            Accent_Color__c = '#08415c',
            Surface_Color__c = '#fff',
            Ink_Color__c = '#1b2a24',
            Display_Font__c = 'Georgia, \'Times New Roman\', serif',
            Body_Font__c = 'Verdana, sans-serif',
            Tone__c = 'Warm and brief.'
        );
    }

    private static void useRecord(Brand_Setting__mdt row) {
        BrandSettings.rowsForTest = row == null ? new List<Brand_Setting__mdt>() : new List<Brand_Setting__mdt>{ row };
    }

    @IsTest
    static void getSettings_ReadsEveryFieldOfTheRecord() {
        useRecord(northwind());

        Test.startTest();
        BrandSettings.Brand b = BrandSettings.getSettings();
        Test.stopTest();

        Assert.areEqual('Northwind Assist', b.agentName, 'agent name comes from Agent_Name__c');
        Assert.areEqual('Northwind Health', b.companyName, 'company name comes from Company_Name__c');
        Assert.areEqual('/resource/BrandLogo_Example', b.logoUrl, 'the logo URL names the Logo_Resource__c static resource');
        Assert.areEqual('#0B6E4F', b.primaryColor, 'primary colour');
        Assert.areEqual('#08415c', b.accentColor, 'accent colour');
        Assert.areEqual('#fff', b.surfaceColor, 'a three-digit hex is kept');
        Assert.areEqual('#1b2a24', b.inkColor, 'ink colour');
        Assert.areEqual('Georgia, \'Times New Roman\', serif', b.displayFont, 'display font');
        Assert.areEqual('Verdana, sans-serif', b.bodyFont, 'body font');
        Assert.areEqual('Warm and brief.', b.tone, 'tone');
        Assert.areEqual(BrandSettings.RADIUS, b.radius, 'the corner radius is the one fixed value');
    }

    @IsTest
    static void getSettings_BlankFields_GiveTheFallbacks() {
        useRecord(new Brand_Setting__mdt(Agent_Name__c = '  ', Company_Name__c = ''));

        BrandSettings.Brand b = BrandSettings.getSettings();

        Assert.areEqual(BrandSettings.DEFAULT_AGENT_NAME, b.agentName, 'blank agent name falls back');
        Assert.areEqual(BrandSettings.DEFAULT_COMPANY_NAME, b.companyName, 'blank company name falls back');
        Assert.areEqual('/resource/' + BrandSettings.DEFAULT_LOGO, b.logoUrl, 'blank logo falls back to BrandLogo');
        Assert.areEqual(BrandSettings.DEFAULT_PRIMARY, b.primaryColor, 'primary falls back');
        Assert.areEqual(BrandSettings.DEFAULT_ACCENT, b.accentColor, 'accent falls back');
        Assert.areEqual(BrandSettings.DEFAULT_SURFACE, b.surfaceColor, 'surface falls back');
        Assert.areEqual(BrandSettings.DEFAULT_INK, b.inkColor, 'ink falls back');
        Assert.areEqual(BrandSettings.DEFAULT_FONT, b.displayFont, 'display font falls back');
        Assert.areEqual(BrandSettings.DEFAULT_FONT, b.bodyFont, 'body font falls back');
        Assert.areEqual(BrandSettings.DEFAULT_TONE, b.tone, 'tone falls back');
    }

    @IsTest
    static void getSettings_NoRecord_GivesEveryFallback() {
        useRecord(null);

        BrandSettings.Brand b = BrandSettings.getSettings();

        Assert.areEqual(BrandSettings.DEFAULT_AGENT_NAME, b.agentName, 'no record: default agent name');
        Assert.areEqual(BrandSettings.DEFAULT_COMPANY_NAME, b.companyName, 'no record: default company name');
        Assert.areEqual(BrandSettings.DEFAULT_TONE, b.tone, 'no record: default tone');
    }

    @IsTest
    static void getSettings_ValuesThatAreNotSafe_GiveTheFallbacks() {
        Brand_Setting__mdt row = northwind();
        row.Primary_Color__c = 'red; background: url(x)';
        row.Accent_Color__c = '#12345';
        row.Display_Font__c = 'Arial; color: red';
        row.Body_Font__c = 'x</style>';
        row.Logo_Resource__c = '../secret';
        useRecord(row);

        BrandSettings.Brand b = BrandSettings.getSettings();

        Assert.areEqual(BrandSettings.DEFAULT_PRIMARY, b.primaryColor, 'a colour that is not hex falls back');
        Assert.areEqual(BrandSettings.DEFAULT_ACCENT, b.accentColor, 'a five-digit hex falls back');
        Assert.areEqual(BrandSettings.DEFAULT_FONT, b.displayFont, 'a font with a semicolon falls back');
        Assert.areEqual(BrandSettings.DEFAULT_FONT, b.bodyFont, 'a font with markup falls back');
        Assert.areEqual('/resource/' + BrandSettings.DEFAULT_LOGO, b.logoUrl, 'a logo that is not a resource name falls back');
    }

    @IsTest
    static void getSettings_TrimsNamesAndKeepsTheToneOnOneLine() {
        Brand_Setting__mdt row = northwind();
        row.Agent_Name__c = '  Northwind Assist ';
        row.Tone__c = 'Warm.\n\n  Brief.  ';
        useRecord(row);

        BrandSettings.Brand b = BrandSettings.getSettings();

        Assert.areEqual('Northwind Assist', b.agentName, 'the agent name is trimmed');
        Assert.areEqual('Warm. Brief.', b.tone, 'the tone is one line');
    }

    @IsTest
    static void getSettings_ReadsTheDeployedDefaultRecord() {
        // No in-memory record: the method reads the org's Default record, whatever its values are.
        Brand_Setting__mdt deployed = Brand_Setting__mdt.getInstance('Default');

        BrandSettings.Brand b = BrandSettings.getSettings();

        Assert.isNotNull(deployed, 'the Default record is deployed');
        Assert.areEqual(deployed.Agent_Name__c.trim(), b.agentName, 'the agent name is the Default record\'s');
        Assert.areEqual(deployed.Company_Name__c.trim(), b.companyName, 'the company name is the Default record\'s');
        Assert.isFalse(String.isBlank(b.tone), 'the tone line is not blank');
    }

    @IsTest
    static void promptLines_NameTheCompanyAndCarryTheTone() {
        useRecord(northwind());

        String lines = BrandSettings.promptLines();

        Assert.isTrue(lines.contains(BrandSettings.COMPANY_PREFIX + 'Northwind Health'), 'the company line names the company: ' + lines);
        Assert.isTrue(lines.contains(BrandSettings.TONE_PREFIX + 'Warm and brief.'), 'the tone line carries Tone__c: ' + lines);
        Assert.areEqual(2, lines.trim().split('\n').size(), 'exactly two lines: ' + lines);
    }
}
