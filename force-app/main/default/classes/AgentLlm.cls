/**
 * AgentLlm: the only class other code calls to reach a model.
 *
 * complete() loads a prompt kept as text in the static resource 'AgentPrompt_<promptName>',
 * fills its {{name}} placeholders from vars, sends it to the active provider and returns the text.
 * A prompt file has two parts, each starting with a marker line: '---system---' then '---user---'.
 * Placeholders are filled in one pass, literally (a value is never re-expanded or read as a regex
 * replacement). A placeholder with no entry in vars is an error, so a renamed variable fails loudly.
 *
 * The active provider is the class named in PROVIDER_CLASS. A new model provider is one class that
 * implements Provider plus a change to that constant. Tests set `stub` so no test ever calls a model.
 * No DML. Every failure is an AgentLlm.LlmException.
 */
public with sharing class AgentLlm {
    public interface Provider {
        String complete(String systemPrompt, String userPrompt, Integer maxTokens);
    }

    public class LlmException extends Exception {}

    @TestVisible private static final String PROMPT_PREFIX = 'AgentPrompt_';
    @TestVisible private static final String PROVIDER_CLASS = 'AgentLlmModelsApi';
    private static final String SYSTEM_MARK = '---system---';
    private static final String USER_MARK = '---user---';
    private static final Pattern PLACEHOLDER = Pattern.compile('\\{\\{\\s*([A-Za-z0-9_]+)\\s*\\}\\}');

    /** When set, used instead of the real provider. Tests only. */
    @TestVisible private static Provider stub;

    public static String complete(String promptName, Map<String, String> vars, Integer maxTokens) {
        String raw = loadPrompt(promptName);
        String systemPrompt = fill(part(raw, SYSTEM_MARK, USER_MARK, promptName), vars, promptName);
        String userPrompt = fill(part(raw, USER_MARK, null, promptName), vars, promptName);
        String text = provider().complete(systemPrompt, userPrompt, maxTokens);
        if (String.isBlank(text)) {
            throw new LlmException('The model returned no text for prompt ' + promptName + '.');
        }
        return text.trim();
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
    private static String loadPrompt(String promptName) {
        String resourceName = PROMPT_PREFIX + (promptName == null ? '' : promptName.trim());
        List<StaticResource> rows = [SELECT Body FROM StaticResource WHERE Name = :resourceName LIMIT 1];
        if (rows.isEmpty() || rows[0].Body == null) {
            throw new LlmException('Prompt not found: static resource ' + resourceName + ' does not exist.');
        }
        return rows[0].Body.toString();
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
