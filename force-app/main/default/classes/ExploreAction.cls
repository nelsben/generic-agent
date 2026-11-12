/**
 * ExploreAction: the 'Explore Data' agent action. One question in, status and answer out.
 *
 * Calls DataExplorer.explore and relays its status verbatim. The answer is the model's text plus a
 * compact plain-text table of the last result set, and the whole answer stays under MAX_CHARS so it
 * fits the chat relay. Table rows are dropped from the end first; the text is clipped only if it alone
 * is too long. When the explorer ran out of turns, the status is OK (or EMPTY) and the text says the
 * step cap was hit, so the last result still reaches the user. Read-only: no DML.
 */
public with sharing class ExploreAction {
    @TestVisible private static final Integer MAX_CHARS = 5900;
    private static final Integer CELL_CHARS = 40;

    public class Request {
        @InvocableVariable(label='Question' description='The data question, in the user\'s words.' required=true)
        public String question;
        @InvocableVariable(label='Context Record Id' description='The record the user has open, if any.')
        public Id contextRecordId;
    }

    public class Response {
        @InvocableVariable(label='Status' description='OK, EMPTY or ERROR.')
        public String status;
        @InvocableVariable(label='Answer' description='The answer text and a compact table of the last result. Relay it verbatim.')
        public String answer;
    }

    @InvocableMethod(label='Explore Data' description='Answers a question about Salesforce data by running safe, read-only queries the user has access to.')
    public static List<Response> explore(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request req : requests) {
            DataExplorer.Result r = DataExplorer.explore(req.question, req.contextRecordId, null);
            Response res = new Response();
            res.status = r.status;
            res.answer = compose(r);
            out.add(res);
        }
        return out;
    }

    /** The answer text, then the last result set as a table, kept under MAX_CHARS. */
    @TestVisible
    private static String compose(DataExplorer.Result r) {
        String text = r.answer == null ? '' : r.answer.trim();
        if (text.length() > MAX_CHARS) {
            return text.left(MAX_CHARS - 3) + '...';
        }
        if (r.status == DataExplorer.ERROR || r.resultSets.isEmpty()) {
            return text;
        }
        ExploreQuery.ResultSet rs = r.resultSets[r.resultSets.size() - 1];
        if (rs.rows.isEmpty()) {
            return text;
        }
        String header = String.join(rs.columns, ' | ');
        String body = text + '\n\n' + header;
        Integer shown = 0;
        for (Map<String, Object> row : rs.rows) {
            List<String> cells = new List<String>();
            for (String c : rs.columns) {
                Object v = row.get(c);
                String cell = v == null ? '' : String.valueOf(v).replaceAll('\\s+', ' ');
                cells.add(cell.length() > CELL_CHARS ? cell.left(CELL_CHARS - 3) + '...' : cell);
            }
            String line = '\n' + String.join(cells, ' | ');
            // Leave room for the closing count line.
            if (body.length() + line.length() + 40 > MAX_CHARS) {
                break;
            }
            body += line;
            shown++;
        }
        if (shown == 0) {
            return text;
        }
        if (shown < rs.total) {
            body += '\n(' + shown + ' of ' + rs.total + ' rows)';
        }
        return body;
    }
}
