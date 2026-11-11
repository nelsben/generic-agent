/**
 * AccountBriefSection: the one shape every Account Brief gather section returns.
 * Read-only: no DML. Plain text only; Apex never writes prose beyond fixed one-line
 * statements such as 'No open cases.', and the LLM never sees JSON from a section.
 */
public with sharing class AccountBriefSection {
    public static final String OK = 'OK';
    public static final String EMPTY = 'EMPTY';
    public static final String ERROR = 'ERROR';

    /** Stable machine key for the section, e.g. 'cases'. */
    public String key;
    /** Heading shown to the rep. */
    public String title;
    /** One of OK, EMPTY, ERROR. */
    public String status;
    /** Plain-text block. Never JSON, never null. EMPTY sections carry one human sentence. */
    public String body = '';
    /** Rows that matched. */
    public Integer total = 0;
    /** Rows rendered after the cap. */
    public Integer shown = 0;

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

    /** yyyy-MM-dd, or 'n/a' for a null date. */
    public static String fmtDate(Date d) {
        if (d == null) {
            return 'n/a';
        }
        return DateTime.newInstance(d, Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd');
    }
}
