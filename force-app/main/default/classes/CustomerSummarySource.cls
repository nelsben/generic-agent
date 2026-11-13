/**
 * CustomerSummarySource: one gather section of the Customer Summary.
 * A new source is one class implementing this plus one line in CustomerSummary's registry.
 * build() is deterministic Apex: no LLM, no DML, plain text only, and it never throws
 * (a failure comes back as an ERROR section).
 */
public interface CustomerSummarySource {
    /** Stable machine key, e.g. 'cases'. Must equal the key in CustomerSummary's registry. */
    String key();
    /** Heading shown to the rep. */
    String title();
    /** The section for one account. */
    CustomerSummarySection build(Id accountId);
}
