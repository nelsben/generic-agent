/**
 * BrandSettings: the product's brand, read from the one Brand_Setting__mdt record named Default.
 *
 * getSettings() is the panel's read (cacheable). promptLines() is the two lines the summary synthesis and the
 * explorer add after their system prompt: the company the user works at, and the tone. Every value has a safe
 * fallback: a blank field, a missing record or a value that is not safe to put in a style (a colour that is not
 * hex, a font list with anything but letters, digits, spaces, commas, hyphens and quotes, a logo that is not a
 * static resource name) gives the neutral default instead. A blank font means the page's own font.
 *
 * The record is read in user mode; the data-access permission set grants read on Brand_Setting__mdt. A user
 * without that access gets the fallbacks. Read once per transaction. No DML.
 */
public with sharing class BrandSettings {
    @TestVisible private static final String RECORD_NAME = 'Default';
    @TestVisible private static final String DEFAULT_AGENT_NAME = 'Customer Summary';
    @TestVisible private static final String DEFAULT_COMPANY_NAME = 'Your Company';
    @TestVisible private static final String DEFAULT_LOGO = 'BrandLogo';
    @TestVisible private static final String DEFAULT_PRIMARY = '#0176d3';
    @TestVisible private static final String DEFAULT_ACCENT = '#014486';
    @TestVisible private static final String DEFAULT_SURFACE = '#ffffff';
    @TestVisible private static final String DEFAULT_INK = '#181818';
    /** Blank: the stylesheet falls back to the page's own font. */
    @TestVisible private static final String DEFAULT_FONT = '';
    @TestVisible private static final String DEFAULT_TONE =
        'Write in a plain, warm and concise voice: short sentences, everyday words, no hype.';
    /** The corner radius has no field in FR2: one fixed value, set as --cs-radius like the rest. */
    @TestVisible private static final String RADIUS = '0.25rem';
    @TestVisible private static final String COMPANY_PREFIX = 'Company: the user works at ';
    @TestVisible private static final String TONE_PREFIX = 'Tone: ';
    private static final String RESOURCE_PATH = '/resource/';
    private static final Integer MAX_TONE_CHARS = 500;
    private static final Pattern HEX = Pattern.compile('^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{4}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$');
    private static final Pattern FONT = Pattern.compile('^[A-Za-z0-9 ,\'"\\-]{1,200}$');
    private static final Pattern RESOURCE_NAME = Pattern.compile('^[A-Za-z][A-Za-z0-9_]{0,79}$');

    /** When set, used instead of the org's record. Tests only: an empty list means no record. */
    @TestVisible private static List<Brand_Setting__mdt> rowsForTest;

    private static Brand cached;

    /** The brand as the panel reads it. */
    public class Brand {
        @AuraEnabled public String agentName;
        @AuraEnabled public String companyName;
        @AuraEnabled public String logoUrl;
        @AuraEnabled public String primaryColor;
        @AuraEnabled public String accentColor;
        @AuraEnabled public String surfaceColor;
        @AuraEnabled public String inkColor;
        @AuraEnabled public String displayFont;
        @AuraEnabled public String bodyFont;
        @AuraEnabled public String radius;
        @AuraEnabled public String tone;
    }

    /**
     * The Default record with fallbacks applied.
     * @return the brand; never null
     */
    @AuraEnabled(cacheable=true)
    public static Brand getSettings() {
        if (cached == null) {
            cached = build(readRecord());
        }
        return cached;
    }

    /**
     * The two lines a prompt adds after its system text: the company, then the tone.
     * @return 'Company: the user works at <company>.' and 'Tone: <tone>', joined by a line break
     */
    public static String promptLines() {
        Brand b = getSettings();
        return COMPANY_PREFIX + b.companyName + '.\n' + TONE_PREFIX + b.tone;
    }

    private static Brand_Setting__mdt readRecord() {
        List<Brand_Setting__mdt> rows = rowsForTest;
        if (rows == null) {
            try {
                rows = [
                    SELECT Agent_Name__c, Company_Name__c, Logo_Resource__c, Primary_Color__c, Accent_Color__c,
                        Surface_Color__c, Ink_Color__c, Display_Font__c, Body_Font__c, Tone__c
                    FROM Brand_Setting__mdt
                    WHERE DeveloperName = :RECORD_NAME
                    WITH USER_MODE
                    LIMIT 1
                ];
            } catch (QueryException e) {
                // No read access to the brand record: the fallbacks apply.
                rows = new List<Brand_Setting__mdt>();
            }
        }
        return rows.isEmpty() ? new Brand_Setting__mdt() : rows[0];
    }

    private static Brand build(Brand_Setting__mdt row) {
        Brand b = new Brand();
        b.agentName = text(row.Agent_Name__c, DEFAULT_AGENT_NAME);
        b.companyName = text(row.Company_Name__c, DEFAULT_COMPANY_NAME);
        b.logoUrl = RESOURCE_PATH + matching(row.Logo_Resource__c, RESOURCE_NAME, DEFAULT_LOGO);
        b.primaryColor = matching(row.Primary_Color__c, HEX, DEFAULT_PRIMARY);
        b.accentColor = matching(row.Accent_Color__c, HEX, DEFAULT_ACCENT);
        b.surfaceColor = matching(row.Surface_Color__c, HEX, DEFAULT_SURFACE);
        b.inkColor = matching(row.Ink_Color__c, HEX, DEFAULT_INK);
        b.displayFont = matching(row.Display_Font__c, FONT, DEFAULT_FONT);
        b.bodyFont = matching(row.Body_Font__c, FONT, DEFAULT_FONT);
        b.radius = RADIUS;
        b.tone = text(row.Tone__c, DEFAULT_TONE).left(MAX_TONE_CHARS).trim();
        return b;
    }

    /** The value on one line with spaces collapsed, or the fallback when blank. */
    private static String text(String value, String fallback) {
        return String.isBlank(value) ? fallback : value.normalizeSpace();
    }

    /** The trimmed value when it matches the pattern, else the fallback. */
    private static String matching(String value, Pattern allowed, String fallback) {
        String v = value == null ? '' : value.trim();
        return v.length() > 0 && allowed.matcher(v).matches() ? v : fallback;
    }
}
