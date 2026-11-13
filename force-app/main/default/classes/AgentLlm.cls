/**
 * AgentLlm: the only class other code calls to reach a model.
 *
 * complete() runs one named prompt. How it runs is set per prompt by the Agent_Prompt_Setting__mdt record named
 * after the prompt (docs/research/fr2-model-door.md); a prompt with no record runs as it always has:
 * - Source Static resource (the default): the prompt is the text in the static resource 'AgentPrompt_<promptName>',
 *   its {{name}} placeholders are filled from vars, and it goes to the active provider with the setting's model.
 *   A prompt file has two parts, each starting with a marker line: '---system---' then '---user---'.
 *   Placeholders are filled in one pass, literally (a value is never re-expanded or read as a regex replacement).
 *   A placeholder with no entry in vars is an error, so a renamed variable fails loudly.
 * - Source Prompt template: the prompt template named on the setting runs with the variables its Template Inputs
 *   map to its inputs (TemplateProvider). It returns its text through the same error type.
 *
 * The active providers are the classes named in PROVIDER_CLASS and TEMPLATE_PROVIDER_CLASS, reached by name, so
 * this class holds no compile-time reference to a platform AI API. A provider that implements ModelProvider is
 * given the setting's model; one that implements only Provider keeps its own. Tests set `stub` (and
 * `templateStub`) so no test ever calls a model; with only `stub` set, a template prompt uses the file path.
 *
 * Length: the setting's Max_Tokens__c (else the caller's maxTokens) is passed to the provider, which sends it where
 * its request takes a maximum-token setting. The reply is also cut at about CHARS_PER_TOKEN characters a token,
 * for every provider, as a backstop (the Models API chat request takes no maximum-token setting).
 *
 * Trace: with Trace__c on a prompt's setting, the filled system and user text (or the template and its inputs)
 * and the reply length go to the debug log, with record Ids replaced by [id]. Never in a test's output.
 *
 * A prompt and the settings are read once per transaction and cached. No DML. Every failure is an
 * AgentLlm.LlmException: an exception from a provider is wrapped, with its type and message kept in the text.
 */
public with sharing class AgentLlm {
    public interface Provider {
        String complete(String systemPrompt, String userPrompt, Integer maxTokens);
    }

    /** A provider that also takes the model named on the prompt's setting (null or blank: its own default). */
    public interface ModelProvider extends Provider {
        String complete(String systemPrompt, String userPrompt, Integer maxTokens, String model);
    }

    /** Runs a prompt template by API name with its inputs, keyed by input API name. */
    public interface TemplateProvider {
        String generate(String templateName, Map<String, String> inputs, Integer maxTokens);
    }

    public class LlmException extends Exception {}

    /** One prompt's setting, with the defaults applied. */
    public class Setting {
        /** True when a record exists for the prompt. */
        public Boolean found = false;
        public String model;
        public Integer maxTokens;
        public String source = SOURCE_FILE;
        public String templateName;
        /** Prompt variable name to template input API name, in the order written. */
        public Map<String, String> templateInputs = new Map<String, String>();
        public Boolean trace = false;
        private String promptName;
        private String inputsError;

        public Boolean isTemplate() {
            return source == SOURCE_TEMPLATE;
        }
    }

    @TestVisible private static final String PROMPT_PREFIX = 'AgentPrompt_';
    @TestVisible private static final String PROVIDER_CLASS = 'AgentLlmModelsApi';
    @TestVisible private static final String TEMPLATE_PROVIDER_CLASS = 'AgentLlmPromptTemplate';
    @TestVisible private static final String SOURCE_FILE = 'Static_Resource';
    @TestVisible private static final String SOURCE_TEMPLATE = 'Prompt_Template';
    /** In Template Inputs, the variable that carries the systemSuffix lines. */
    @TestVisible private static final String SYSTEM_SUFFIX_VAR = 'system_suffix';
    /** Rough characters per token, used to turn maxTokens into a reply length cap. */
    @TestVisible private static final Integer CHARS_PER_TOKEN = 4;
    private static final String SYSTEM_MARK = '---system---';
    private static final String USER_MARK = '---user---';
    private static final String TRACE_PREFIX = 'AgentLlm trace ';
    private static final Pattern PLACEHOLDER = Pattern.compile('\\{\\{\\s*([A-Za-z0-9_]+)\\s*\\}\\}');
    /** A 15 or 18 character record Id: letters and digits, at least one digit, standing alone. */
    private static final String RECORD_ID = '\\b(?=[A-Za-z0-9]*[0-9])[A-Za-z0-9]{15}(?:[A-Za-z0-9]{3})?\\b';

    /** When set, used instead of the real provider. Tests only. */
    @TestVisible private static Provider stub;
    /** When set, used instead of the real template provider. Tests only. */
    @TestVisible private static TemplateProvider templateStub;
    /** When set, the only settings that exist, by prompt name. Tests only. */
    @TestVisible private static Map<String, Agent_Prompt_Setting__mdt> settingsForTest;
    /** Whether the org's setting records are read. Off in tests, so a test never depends on the org's records. */
    @TestVisible private static Boolean useOrgSettings = !Test.isRunningTest();
    /** When set, trace lines are added here instead of the debug log. Tests only. */
    @TestVisible private static List<String> traceSink;

    /** Prompt text by static resource name, filled on first load in a transaction. */
    private static final Map<String, String> promptCache = new Map<String, String>();
    /** The org's setting records by prompt name, read once per transaction. */
    private static Map<String, Agent_Prompt_Setting__mdt> orgSettings;

    public static String complete(String promptName, Map<String, String> vars, Integer maxTokens) {
        return complete(promptName, vars, maxTokens, null);
    }

    /**
     * As complete(promptName, vars, maxTokens), with systemSuffix (when not blank) added after the prompt file's
     * system text, on its own lines. The file's text is unchanged, so a caller that looks for it still finds it.
     * For a prompt template, systemSuffix goes to the input mapped to system_suffix, if any.
     */
    public static String complete(String promptName, Map<String, String> vars, Integer maxTokens, String systemSuffix) {
        Setting s = setting(promptName);
        Integer tokens = s.maxTokens != null ? s.maxTokens : maxTokens;
        String text = s.isTemplate() && (templateStub != null || stub == null)
            ? fromTemplate(s, vars, systemSuffix, tokens)
            : fromFile(s, vars, systemSuffix, tokens);
        if (String.isBlank(text)) {
            throw new LlmException('The model returned no text for prompt ' + promptName + '.');
        }
        text = text.trim();
        if (tokens != null && tokens > 0 && text.length() > tokens * CHARS_PER_TOKEN) {
            text = text.left(tokens * CHARS_PER_TOKEN).trim();
        }
        trace(s, 'reply', text.length() + ' characters');
        return text;
    }

    private static String fromFile(Setting s, Map<String, String> vars, String systemSuffix, Integer tokens) {
        String raw = loadPrompt(s.promptName);
        String systemPrompt = fill(part(raw, SYSTEM_MARK, USER_MARK, s.promptName), vars, s.promptName);
        if (String.isNotBlank(systemSuffix)) {
            systemPrompt += '\n\n' + systemSuffix.trim();
        }
        String userPrompt = fill(part(raw, USER_MARK, null, s.promptName), vars, s.promptName);
        trace(s, 'system', systemPrompt);
        trace(s, 'user', userPrompt);
        try {
            Provider p = provider();
            if (String.isNotBlank(s.model) && p instanceof ModelProvider) {
                return ((ModelProvider) p).complete(systemPrompt, userPrompt, tokens, s.model);
            }
            return p.complete(systemPrompt, userPrompt, tokens);
        } catch (Exception e) {
            throw wrapped(e, 'The model call for prompt ' + s.promptName);
        }
    }

    private static String fromTemplate(Setting s, Map<String, String> vars, String systemSuffix, Integer tokens) {
        if (String.isBlank(s.templateName)) {
            throw new LlmException('Prompt ' + s.promptName + ' is set to a prompt template but names no prompt template.');
        }
        if (s.inputsError != null) {
            throw new LlmException(s.inputsError);
        }
        Map<String, String> values = vars == null ? new Map<String, String>() : vars.clone();
        values.put(SYSTEM_SUFFIX_VAR, String.isBlank(systemSuffix) ? '' : systemSuffix.trim());
        Map<String, String> inputs = new Map<String, String>();
        for (String name : s.templateInputs.keySet()) {
            if (!values.containsKey(name)) {
                throw new LlmException('Prompt ' + s.promptName + ' maps {{' + name + '}} to a template input, but no value was given for it.');
            }
            inputs.put(s.templateInputs.get(name), values.get(name));
        }
        trace(s, 'template', s.templateName);
        for (String input : inputs.keySet()) {
            trace(s, 'input ' + input, inputs.get(input));
        }
        try {
            return templateProvider().generate(s.templateName, inputs, tokens);
        } catch (Exception e) {
            throw wrapped(e, 'The prompt template call for prompt ' + s.promptName);
        }
    }

    /** An LlmException as it is; any other exception wrapped, with its type and message, and kept as the cause. */
    private static LlmException wrapped(Exception e, String what) {
        if (e instanceof LlmException) {
            return (LlmException) e;
        }
        LlmException out = new LlmException(what + ' failed: ' + e.getTypeName() + ': ' + e.getMessage());
        out.initCause(e);
        return out;
    }

    @TestVisible
    private static Provider provider() {
        if (stub != null) {
            return stub;
        }
        Type t = Type.forName(PROVIDER_CLASS);
        if (t == null) {
            throw new LlmException('Model provider class not found: ' + PROVIDER_CLASS);
        }
        return (Provider) t.newInstance();
    }

    @TestVisible
    private static TemplateProvider templateProvider() {
        if (templateStub != null) {
            return templateStub;
        }
        Type t = Type.forName(TEMPLATE_PROVIDER_CLASS);
        if (t == null) {
            throw new LlmException('Prompt template provider class not found: ' + TEMPLATE_PROVIDER_CLASS);
        }
        return (TemplateProvider) t.newInstance();
    }

    /**
     * The prompt's setting with defaults applied; a prompt with no record gets every default.
     * @param promptName the prompt name, which is also the setting record's DeveloperName
     * @return the setting, never null
     */
    public static Setting setting(String promptName) {
        Setting s = new Setting();
        s.promptName = promptName == null ? '' : promptName.trim();
        Agent_Prompt_Setting__mdt row = settingRows().get(s.promptName);
        if (row == null) {
            return s;
        }
        s.found = true;
        s.model = String.isBlank(row.Model__c) ? null : row.Model__c.trim();
        s.maxTokens = row.Max_Tokens__c == null || row.Max_Tokens__c <= 0 ? null : row.Max_Tokens__c.intValue();
        s.source = row.Source__c == SOURCE_TEMPLATE ? SOURCE_TEMPLATE : SOURCE_FILE;
        s.templateName = String.isBlank(row.Template_Name__c) ? null : row.Template_Name__c.trim();
        s.trace = row.Trace__c == true;
        parseInputs(s, row.Template_Inputs__c);
        return s;
    }

    /** 'a=A; b = B' into {a => A, b => B}. A pair without both names is kept as an error for the template path. */
    private static void parseInputs(Setting s, String text) {
        if (String.isBlank(text)) {
            return;
        }
        for (String pair : text.split(';')) {
            if (String.isBlank(pair)) {
                continue;
            }
            List<String> sides = pair.split('=', 2);
            if (sides.size() != 2 || String.isBlank(sides[0]) || String.isBlank(sides[1])) {
                s.inputsError = 'Prompt ' + s.promptName + ' has a Template Inputs entry that is not variable=Input_Name: '
                    + pair.trim();
                return;
            }
            s.templateInputs.put(sides[0].trim(), sides[1].trim());
        }
    }

    private static Map<String, Agent_Prompt_Setting__mdt> settingRows() {
        if (settingsForTest != null) {
            return settingsForTest;
        }
        if (!useOrgSettings) {
            return new Map<String, Agent_Prompt_Setting__mdt>();
        }
        if (orgSettings == null) {
            orgSettings = new Map<String, Agent_Prompt_Setting__mdt>();
            for (Agent_Prompt_Setting__mdt row : querySettings()) {
                orgSettings.put(row.DeveloperName, row);
            }
        }
        return orgSettings;
    }

    // system-context: the product's own prompt configuration, the same for every user; reps hold no read access to the type
    private static List<Agent_Prompt_Setting__mdt> querySettings() {
        return [
            SELECT DeveloperName, Model__c, Max_Tokens__c, Source__c, Template_Name__c, Template_Inputs__c, Trace__c
            FROM Agent_Prompt_Setting__mdt
            WITH SYSTEM_MODE
        ];
    }

    /** One trace line for a prompt whose setting has the trace on: to the sink in tests, else the debug log. */
    private static void trace(Setting s, String label, String text) {
        if (!s.trace) {
            return;
        }
        String line = TRACE_PREFIX + s.promptName + ' ' + label + ': ' + (text == null ? '' : text.replaceAll(RECORD_ID, '[id]'));
        if (traceSink != null) {
            traceSink.add(line);
        } else if (!Test.isRunningTest()) {
            System.debug(LoggingLevel.INFO, line);
        }
    }

    @TestVisible
    private static String loadPrompt(String promptName) {
        String resourceName = PROMPT_PREFIX + (promptName == null ? '' : promptName.trim());
        String cached = promptCache.get(resourceName);
        if (cached != null) {
            return cached;
        }
        // Every user can read static resources in user mode, a rep holding only the user group included (BE-33).
        List<StaticResource> rows = [SELECT Body FROM StaticResource WHERE Name = :resourceName WITH USER_MODE LIMIT 1];
        if (rows.isEmpty() || rows[0].Body == null) {
            throw new LlmException('Prompt not found: static resource ' + resourceName + ' does not exist.');
        }
        String body = rows[0].Body.toString();
        promptCache.put(resourceName, body);
        return body;
    }

    /** The text after startMark and before endMark (or the end), trimmed. */
    @TestVisible
    private static String part(String raw, String startMark, String endMark, String promptName) {
        String text = raw == null ? '' : raw;
        Integer start = text.indexOf(startMark);
        Integer stop = endMark == null ? text.length() : text.indexOf(endMark);
        if (start < 0 || stop < 0 || stop < start) {
            throw new LlmException('Prompt ' + promptName + ' must have a ' + SYSTEM_MARK + ' part followed by a ' + USER_MARK + ' part.');
        }
        return text.substring(start + startMark.length(), stop).trim();
    }

    /** Replaces each {{name}} with vars.get(name) in one pass. A null value becomes ''. */
    @TestVisible
    private static String fill(String template, Map<String, String> vars, String promptName) {
        Map<String, String> values = vars == null ? new Map<String, String>() : vars;
        Matcher m = PLACEHOLDER.matcher(template);
        List<String> out = new List<String>();
        Integer last = 0;
        while (m.find()) {
            String name = m.group(1);
            if (!values.containsKey(name)) {
                throw new LlmException('Prompt ' + promptName + ' needs a value for {{' + name + '}}.');
            }
            String value = values.get(name);
            out.add(template.substring(last, m.start()));
            out.add(value == null ? '' : value);
            last = m.end();
        }
        out.add(template.substring(last));
        return String.join(out, '');
    }
}
