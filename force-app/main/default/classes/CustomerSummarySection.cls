/**
 * CustomerSummarySection: the one shape every Customer Summary gather section returns.
 * Read-only: no DML. Plain text only; Apex never writes prose beyond fixed one-line
 * statements such as 'No open cases.', and the LLM never sees JSON from a section.
 */
public with sharing class CustomerSummarySection {
    public static final String OK = 'OK';
    public static final String EMPTY = 'EMPTY';
    public static final String ERROR = 'ERROR';

    /** Stable machine key for the section, e.g. 'cases'. */
    @AuraEnabled public String key;
    /** Heading shown to the rep. */
    @AuraEnabled public String title;
    /** One of OK, EMPTY, ERROR. */
    @AuraEnabled public String status;
    /**
     * Plain-text block. Never JSON, never null. EMPTY sections carry one human sentence.
     * A line that describes one record ends with ' — ' and its Id (withId), for the panel's drill;
     * CustomerSummary strips those Ids (withoutIds) before any text reaches a model prompt.
     */
    @AuraEnabled public String body = '';
    /** Rows that matched. */
    @AuraEnabled public Integer total = 0;
    /** Rows rendered after the cap. */
    @AuraEnabled public Integer shown = 0;
    /**
     * For an ERROR section: the exception type and message that caused it. For logs and tests only:
     * not AuraEnabled, never part of body, so it never reaches the rep or a model prompt.
     */
    public String cause;

    /** An ERROR section for a failed build: the fixed user-facing body, the cause kept and logged. */
    public static CustomerSummarySection failed(String key, String title, Exception e) {
        CustomerSummarySection s = new CustomerSummarySection();
        s.key = key;
        s.title = title;
        s.status = ERROR;
        s.body = 'Couldn\'t load ' + title + ' right now.';
        s.cause = e == null ? null : e.getTypeName() + ': ' + e.getMessage();
        System.debug(LoggingLevel.ERROR, 'CustomerSummary section ' + key + ' failed: ' + s.cause);
        return s;
    }

    /**
     * Single-line, whitespace-collapsed, length-capped text. Blank input gives 'n/a'.
     * A cut value is exactly maxChars long and ends with an ellipsis.
     * A null or non-positive maxChars means no cap.
     */
    public static String clip(String s, Integer maxChars) {
        if (String.isBlank(s)) {
            return 'n/a';
        }
        String t = s.trim().replaceAll('\\s+', ' ');
        if (maxChars != null && maxChars > 0 && t.length() > maxChars) {
            return t.substring(0, maxChars - 1) + '…';
        }
        return t;
    }

    /** What ends a line that describes one record: the separator, then the record's 18-character Id. */
    @TestVisible private static final String ID_SEPARATOR = ' — ';
    /** A record Id at the end of a line, with its separator. Multiline, so $ matches at each line end. */
    private static final String LINE_ID = '(?m)' + ID_SEPARATOR + '[0-9][0-9A-Za-z]{17}$';

    /**
     * The line with the record's Id at its end, so the panel can drill it (the panel hides the Id).
     * A null Id leaves the line as it is.
     */
    public static String withId(String line, Id recordId) {
        return recordId == null ? line : line + ID_SEPARATOR + String.valueOf(recordId);
    }

    /** The text without the record Ids withId added: what a model prompt and every length budget see. */
    public static String withoutIds(String text) {
        return String.isEmpty(text) ? text : text.replaceAll(LINE_ID, '');
    }

    /** yyyy-MM-dd, or 'n/a' for a null date. */
    public static String fmtDate(Date d) {
        if (d == null) {
            return 'n/a';
        }
        return DateTime.newInstance(d, Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd');
    }

    /** Whole currency units with grouping and a '$' prefix, e.g. $1,250,000. Rounds half up. */
    public static String money(Decimal amount) {
        Decimal rounded = amount.setScale(0, System.RoundingMode.HALF_UP);
        String digits = String.valueOf(rounded.abs().longValue());
        String grouped = '';
        Integer len = digits.length();
        for (Integer i = 0; i < len; i++) {
            if (i > 0 && Math.mod(len - i, 3) == 0) {
                grouped += ',';
            }
            grouped += digits.substring(i, i + 1);
        }
        return (rounded < 0 ? '-' : '') + '$' + grouped;
    }
}
