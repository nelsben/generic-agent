/**
 * AccountBriefSource: one gather section of the Account Brief.
 * A new source is one class implementing this plus one line in AccountBrief's registry.
 * build() is deterministic Apex: no LLM, no DML, plain text only, and it never throws
 * (a failure comes back as an ERROR section).
 */
public interface AccountBriefSource {
    /** Stable machine key, e.g. 'cases'. Must equal the key in AccountBrief's registry. */
    String key();
    /** Heading shown to the rep. */
    String title();
    /** The section for one account. */
    AccountBriefSection build(Id accountId);
}
