/**
 * CustomerSummaryActionCatalog: the six write actions as data (BE-27, docs/patterns/13-write-actions.md), and the
 * pre-check draftFromText runs before it spends a model call.
 *
 * For each action: the object it writes, whether it creates or updates, the words the card shows, and, for an update,
 * the allow-list of fields it may change. CustomerSummaryActions holds the rules that use them. No query, DML or callout.
 *
 * The pre-check (BE-22): skip filler words, then test the first word that is left against a verb list. Matching a verb
 * anywhere in the text is wrong: a question such as "Which of their open deals close this quarter?" contains "open".
 * The two lists are BE-22's, kept as they ran; CustomerSummaryActionsTest pins what they sort right and what they miss.
 */
public with sharing class CustomerSummaryActionCatalog {
    public static final String CREATE_MODE = 'create';
    public static final String UPDATE_MODE = 'update';

    public static final String CREATE_TASK = 'create_task';
    public static final String CREATE_EVENT = 'create_event';
    public static final String LOG_CALL = 'log_call';
    public static final String UPDATE_CONTACT = 'update_contact';
    public static final String CREATE_CASE = 'create_case';
    public static final String UPDATE_OPPORTUNITY = 'update_opportunity';

    /** Words skipped before the first real word (BE-22's list). */
    public static final Set<String> FILLER = new Set<String>{
        'uh', 'um', 'so', 'ok', 'okay', 'hey', 'please', 'can', 'could', 'would', 'you', 'i', 'need', 'to', 'want', 'let\'s'
    };
    /** A first real word on this list makes the text worth one model call (BE-22's list). */
    public static final Set<String> VERBS = new Set<String>{
        'create', 'add', 'schedule', 'set', 'book', 'log', 'remind', 'update', 'change', 'open', 'push', 'move', 'make'
    };

    /** One action: what it writes and how the card names it. */
    public class Spec {
        /** The action's name, such as create_task. */
        public String name;
        /** What the draft card calls it: 'Create a task'. */
        public String label;
        /** What the result card and the outcome call it once saved: 'Task created'. */
        public String done;
        /** The object it writes. */
        public String objectName;
        /** create or update. */
        public String mode;
        /** For an update: the only fields it may change, by API name. Empty for a create. */
        public List<String> allowed = new List<String>();

        public Spec(String name, String label, String done, String objectName, String mode, List<String> allowed) {
            this.name = name;
            this.label = label;
            this.done = done;
            this.objectName = objectName;
            this.mode = mode;
            if (allowed != null) {
                this.allowed = allowed;
            }
        }

        /** @return true when the action changes an existing record */
        public Boolean isUpdate() {
            return mode == UPDATE_MODE;
        }
    }

    /**
     * Every action, in the order a chip list shows them. log_call writes CustomerSummaryActions.logCallObject()
     * (F17: one constant decides Event or Task).
     * @return the six specs
     */
    public static List<Spec> all() {
        return new List<Spec>{
            new Spec(CREATE_TASK, 'Create a task', 'Task created', 'Task', CREATE_MODE, null),
            new Spec(CREATE_EVENT, 'Create an event', 'Event created', 'Event', CREATE_MODE, null),
            new Spec(LOG_CALL, 'Log a call', 'Call logged', CustomerSummaryActions.logCallObject(), CREATE_MODE, null),
            new Spec(UPDATE_CONTACT, 'Update a contact', 'Contact updated', 'Contact', UPDATE_MODE,
                new List<String>{ 'Title', 'Phone', 'MobilePhone', 'Email', 'Department' }),
            new Spec(CREATE_CASE, 'Create a case', 'Case created', 'Case', CREATE_MODE, null),
            new Spec(UPDATE_OPPORTUNITY, 'Update an opportunity', 'Opportunity updated', 'Opportunity', UPDATE_MODE,
                new List<String>{ 'StageName', 'CloseDate', 'NextStep', 'Amount' })
        };
    }

    /**
     * @param name an action name, any case
     * @return its spec, or null for no such action
     */
    public static Spec find(String name) {
        if (String.isBlank(name)) {
            return null;
        }
        String wanted = name.trim().toLowerCase();
        for (Spec s : all()) {
            if (s.name == wanted) {
                return s;
            }
        }
        return null;
    }

    /**
     * The first word of the text that is not filler, lowercased, with commas, colons and end punctuation removed.
     * @param text typed or spoken words
     * @return the word, or '' when there is none
     */
    public static String firstWord(String text) {
        if (String.isBlank(text)) {
            return '';
        }
        String cleaned = text.toLowerCase().replace('’', '\'').replaceAll('[,:;.!?"]', ' ');
        for (String word : cleaned.split('\\s+')) {
            if (String.isNotBlank(word) && !FILLER.contains(word)) {
                return word;
            }
        }
        return '';
    }

    /**
     * The pre-check: true when the first real word is an action verb, so the text is worth one model call.
     * @param text typed or spoken words
     * @return true to draft, false to treat the text as a question with no model call
     */
    public static Boolean looksLikeAction(String text) {
        return VERBS.contains(firstWord(text));
    }
}
