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
 * Output is capped at about CHARS_PER_TOKEN characters per requested token (the Models API request
 * carries no max-token setting, so the cap is applied here, at the seam, to every provider). A prompt
 * is read once per transaction and kept in a static cache.
 * No DML. Every failure is an AgentLlm.LlmException: an exception from a provider is wrapped, with its
 * type and message kept in the text.
 */
public with sharing class AgentLlm {
    public interface Provider {
        String complete(String systemPrompt, String userPrompt, Integer maxTokens);
    }

    public class LlmException extends Exception {}

    @TestVisible private static final String PROMPT_PREFIX = 'AgentPrompt_';
    @TestVisible private static final String PROVIDER_CLASS = 'AgentLlmModelsApi';
    /** Rough characters per token, used to turn maxTokens into a reply length cap. */
    @TestVisible private static final Integer CHARS_PER_TOKEN = 4;
    private static final String SYSTEM_MARK = '---system---';
    private static final String USER_MARK = '---user---';
    private static final Pattern PLACEHOLDER = Pattern.compile('\\{\\{\\s*([A-Za-z0-9_]+)\\s*\\}\\}');

    /** When set, used instead of the real provider. Tests only. */
    @TestVisible private static Provider stub;

    /** Prompt text by static resource name, filled on first load in a transaction. */
    private static final Map<String, String> promptCache = new Map<String, String>();

    public static String complete(String promptName, Map<String, String> vars, Integer maxTokens) {
        String raw = loadPrompt(promptName);
        String systemPrompt = fill(part(raw, SYSTEM_MARK, USER_MARK, promptName), vars, promptName);
        String userPrompt = fill(part(raw, USER_MARK, null, promptName), vars, promptName);
        String text;
        try {
            text = provider().complete(systemPrompt, userPrompt, maxTokens);
        } catch (LlmException e) {
            throw e;
        } catch (Exception e) {
            LlmException wrapped = new LlmException('The model call for prompt ' + promptName + ' failed: '
                + e.getTypeName() + ': ' + e.getMessage());
            wrapped.initCause(e);
            throw wrapped;
        }
        if (String.isBlank(text)) {
            throw new LlmException('The model returned no text for prompt ' + promptName + '.');
        }
        text = text.trim();
        if (maxTokens != null && maxTokens > 0 && text.length() > maxTokens * CHARS_PER_TOKEN) {
            text = text.left(maxTokens * CHARS_PER_TOKEN).trim();
        }
        return text;
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
        String cached = promptCache.get(resourceName);
        if (cached != null) {
            return cached;
        }
        // system-context: the product's own shipped prompt files; reps have no read access to static resources
        List<StaticResource> rows = [SELECT Body FROM StaticResource WHERE Name = :resourceName WITH SYSTEM_MODE LIMIT 1];
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
