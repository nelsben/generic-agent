/**
 * CustomerSentiment: one focused model call that scores a customer's sentiment from a summary's gathered sections,
 * already reduced for the synthesis (FR2, F77). It runs no query of its own: the only read is the prompt file
 * AgentLlm loads once per transaction.
 *
 * The prompt AgentPrompt_Sentiment (setting record Sentiment) returns one JSON object: a score from -2 (at risk) to
 * +2 (very positive), the label for that score, and one plain-English reason that names the evidence. Sparse data is
 * a null score with the label NOT_ENOUGH. parse() is strict: anything else is NONE, stored as no score, no label and
 * no reason. Nothing here throws: a model failure is NONE too, so the summary always returns.
 *
 * forBrief() decides whether a summary is worth a call at all:
 * - every evidence source (open deals, cases, activity, calls, deal history) must have been requested and loaded,
 *   because a partial or half-failed summary is not a comparable point on a sentiment chart (NONE, no call);
 * - when none of them holds anything, the answer is NOT_ENOUGH with no call.
 * CustomerSummary owns the model-call budget and calls forBrief() only when the brief can afford it.
 */
public with sharing class CustomerSentiment {
    /** The prompt name: AgentPrompt_Sentiment and the Agent_Prompt_Setting record Sentiment. */
    public static final String PROMPT = 'Sentiment';
    /** The reply length the caller asks for; the setting record ships with the same value. */
    public static final Integer MAX_TOKENS = 200;
    /** The label for sparse data, which never has a score. */
    public static final String NOT_ENOUGH = 'Not enough activity';
    /** The reason stored when no evidence section holds anything, so no model call is made. */
    public static final String NO_EVIDENCE_REASON = 'No open deals, cases, activity, calls or deal history on record.';
    /** The longest reason kept: the outcome's reason field is 255 characters. */
    public static final Integer MAX_REASON_CHARS = 255;

    /** A score with its label and reason. */
    public static final String SCORED = 'SCORED';
    /** Not enough activity: a label and reason, no score. */
    public static final String SPARSE = 'SPARSE';
    /** No reading: not asked, malformed or failed. Stored as no score, no label and no reason. */
    public static final String NONE = 'NONE';

    /** The source keys sentiment comes from. Profile and contacts describe the account, not how it is going. */
    public static final List<String> EVIDENCE_KEYS = new List<String>{ 'open_deals', 'cases', 'activity', 'calls', 'deal_history' };
    /** The reduced values the prompt reads, as CustomerSummary's synthesis names them. */
    private static final List<String> PROMPT_INPUTS = new List<String>{ 'open_deals', 'cases', 'engagement_summary', 'deal_history_summary' };
    private static final String NOT_REQUESTED = 'EMPTY: not requested';
    private static final Set<String> REPLY_KEYS = new Set<String>{ 'score', 'label', 'reason' };
    private static final String FENCE = '```';

    private static final Map<Integer, String> LABELS = new Map<Integer, String>{
        -2 => 'At risk',
        -1 => 'Concerned',
        0 => 'Neutral',
        1 => 'Positive',
        2 => 'Very positive'
    };

    /** One sentiment reading. score is null unless status is SCORED; label and reason are null when status is NONE. */
    public class Reading {
        public String status = NONE;
        public Decimal score;
        public String label;
        public String reason;
    }

    /**
     * The label for a score.
     * @param score -2 to 2
     * @return the label, or null for any other value
     */
    public static String labelFor(Integer score) {
        return score == null ? null : LABELS.get(score);
    }

    /**
     * The sentiment for one summary, from its built sections and the values its synthesis was given.
     * Makes at most one model call, and none for a partial, failed or empty summary. Never throws.
     * @param built the summary's sections by source key, as gathered
     * @param reduced the synthesis values by name (open_deals, cases, engagement_summary, deal_history_summary)
     * @return the reading; NONE when the summary is not scored
     */
    public static Reading forBrief(Map<String, CustomerSummarySection> built, Map<String, String> reduced) {
        if (built == null || reduced == null) {
            return new Reading();
        }
        Boolean anyEvidence = false;
        for (String key : EVIDENCE_KEYS) {
            CustomerSummarySection s = built.get(key);
            if (s == null || s.status == CustomerSummarySection.ERROR) {
                return new Reading();
            }
            anyEvidence = anyEvidence || s.status == CustomerSummarySection.OK;
        }
        return anyEvidence ? score(reduced) : notEnough(NO_EVIDENCE_REASON);
    }

    /**
     * One model call on the reduced values. A value that is missing is sent as not requested. Never throws.
     * @param reduced the synthesis values by name
     * @return the parsed reading; NONE when the model fails or replies with anything malformed
     */
    public static Reading score(Map<String, String> reduced) {
        Map<String, String> vars = new Map<String, String>{ 'today' => Datetime.now().format('yyyy-MM-dd') };
        for (String name : PROMPT_INPUTS) {
            String value = reduced == null ? null : reduced.get(name);
            vars.put(name, String.isBlank(value) ? NOT_REQUESTED : value);
        }
        try {
            return parse(AgentLlm.complete(PROMPT, vars, MAX_TOKENS));
        } catch (Exception e) {
            // The summary stands without a sentiment; the type and message are kept for the debug log only.
            System.debug(LoggingLevel.WARN, 'CustomerSentiment: no score, the model call failed: ' + e.getTypeName() + ': ' + e.getMessage());
            return new Reading();
        }
    }

    /**
     * Strict parse of the prompt's reply: one JSON object (optionally inside one code fence) with exactly the keys
     * score, label and reason. score is a whole number from -2 to 2 with its own label, or null with NOT_ENOUGH.
     * reason is one non-blank line of at most MAX_REASON_CHARS characters.
     * @param reply the model's text
     * @return SCORED or SPARSE for a well-formed reply, otherwise NONE
     */
    public static Reading parse(String reply) {
        Map<String, Object> fields = jsonObject(unfenced(reply));
        if (fields == null || !fields.keySet().equals(REPLY_KEYS)) {
            return new Reading();
        }
        Object rawScore = fields.get('score');
        Object rawLabel = fields.get('label');
        Object rawReason = fields.get('reason');
        if (!(rawLabel instanceof String) || !(rawReason instanceof String)) {
            return new Reading();
        }
        String label = ((String) rawLabel).trim();
        String reason = ((String) rawReason).trim();
        if (String.isBlank(reason) || reason.length() > MAX_REASON_CHARS || reason.contains('\n') || reason.contains('\r')) {
            return new Reading();
        }

        Reading r = new Reading();
        if (rawScore == null) {
            if (!label.equalsIgnoreCase(NOT_ENOUGH)) {
                return r;
            }
            return notEnough(reason);
        }
        if (!(rawScore instanceof Integer)) {
            return r;
        }
        String expected = labelFor((Integer) rawScore);
        if (expected == null || !label.equalsIgnoreCase(expected)) {
            return r;
        }
        r.status = SCORED;
        r.score = (Integer) rawScore;
        r.label = expected;
        r.reason = reason;
        return r;
    }

    private static Reading notEnough(String reason) {
        Reading r = new Reading();
        r.status = SPARSE;
        r.label = NOT_ENOUGH;
        r.reason = reason;
        return r;
    }

    /** The text inside one code fence that wraps the whole reply, or the reply itself, trimmed. Null stays null. */
    private static String unfenced(String reply) {
        if (reply == null) {
            return null;
        }
        String text = reply.trim();
        if (text.startsWith(FENCE) && text.endsWith(FENCE) && text.length() > 2 * FENCE.length()) {
            Integer firstBreak = text.indexOf('\n');
            if (firstBreak < 0) {
                return null;
            }
            text = text.substring(firstBreak + 1, text.length() - FENCE.length()).trim();
        }
        return text;
    }

    /** The reply as a JSON object when the whole text is one, else null. */
    private static Map<String, Object> jsonObject(String text) {
        if (String.isBlank(text) || !text.startsWith('{') || !text.endsWith('}')) {
            return null;
        }
        try {
            Object parsed = JSON.deserializeUntyped(text);
            return parsed instanceof Map<String, Object> ? (Map<String, Object>) parsed : null;
        } catch (JSONException e) {
            return null;
        }
    }
}
