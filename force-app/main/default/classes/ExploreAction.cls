/**
 * ExploreAction: the 'Explore Data' agent action. One question in, status and answer out.
 *
 * Calls DataExplorer.explore and relays its status verbatim. The answer is the model's text plus a
 * compact plain-text table of the last result set, and the whole answer stays under MAX_CHARS so it
 * fits the chat relay. Table rows are dropped from the end first; the text is clipped only if it alone
 * is too long. When the explorer ran out of turns, the status is OK (or EMPTY) and the text says the
 * step cap was hit, so the last result still reaches the user. When the model failed after a query (N4),
 * the status stays ERROR and the fixed failure line is followed by the last table already read, as the
 * panel shows it. Read-only: no DML.
 *
 * Cards (BE-39): the Cards output is the same answer as card JSON (AnswerCard), its table holding exactly the
 * rows the Answer text shows. Over AnswerCard.MAX_JSON_CHARS it is '' and the Answer is unchanged.
 *
 * History (N3): the History output is this question and its answer as one string, in the shape
 * DataExplorer reads ([{"question":"...","answer":"..."}], each part clipped to HISTORY_CHARS). The agent
 * keeps it and passes it back as the History input on the next explore turn, so a follow-up such as
 * "Which close this quarter?" reaches the explorer with the question it follows. Empty means none.
 */
public with sharing class ExploreAction {
    @TestVisible private static final Integer MAX_CHARS = 5900;
    private static final Integer CELL_CHARS = 40;
    /** DataExplorer shows the model at most 600 characters of each earlier question and answer. */
    @TestVisible private static final Integer HISTORY_CHARS = 600;

    public class Request {
        @InvocableVariable(label='Question' description='The data question, in the user\'s words.' required=true)
        public String question;
        @InvocableVariable(label='Context Record Id' description='The record the user has open, if any.')
        public Id contextRecordId;
        @InvocableVariable(label='History' description='The previous explore question and answer as one string: the History output of the previous explore run. Empty for none.' required=false)
        public String history;
    }

    public class Response {
        @InvocableVariable(label='Status' description='OK, EMPTY or ERROR.')
        public String status;
        @InvocableVariable(label='Answer' description='The answer text and a compact table of the last result. Relay it verbatim.')
        public String answer;
        @InvocableVariable(label='History' description='This question and its answer as one string, to pass as History on the next explore turn. Not for the user.')
        public String history;
        @InvocableVariable(label='Cards' description='The same answer as structured cards in JSON, for a client that can show them: the answer, the result table with exactly the rows the Answer shows, the queries that ran and the suggested follow-up questions. Record Ids appear only in each card\'s refs. Empty when too long. Do not relay it to the user; relay the Answer.')
        public String cards;
    }

    @InvocableMethod(callout=true label='Explore Data' description='Answers a question about Salesforce data by running safe, read-only queries the user has access to.')
    public static List<Response> explore(List<Request> requests) {
        List<Response> out = new List<Response>();
        if (requests == null) {
            return out;
        }
        for (Request req : requests) {
            // A null request gets a response like any other (a blank question is EMPTY), so results line up.
            DataExplorer.Result r = req == null
                ? DataExplorer.explore(null, null, null)
                : DataExplorer.explore(req.question, req.contextRecordId, String.isBlank(req.history) ? null : req.history);
            Response res = new Response();
            res.status = r.status;
            Composed c = composeRows(r);
            res.answer = c.text;
            res.cards = cardsOf(r, c.rows);
            res.history = historyOf(req?.question, res.answer);
            out.add(res);
        }
        return out;
    }

    /**
     * This turn as the history DataExplorer reads: one item, question and answer each clipped to
     * HISTORY_CHARS. Empty for a blank question, which the explorer does not run.
     */
    @TestVisible
    private static String historyOf(String question, String answer) {
        if (String.isBlank(question)) {
            return '';
        }
        return JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'question' => clipHistory(question.trim()),
                'answer' => clipHistory(answer == null ? '' : answer)
            }
        });
    }

    private static String clipHistory(String text) {
        return text.length() > HISTORY_CHARS ? text.left(HISTORY_CHARS - 3) + '...' : text;
    }

    /** The answer text and how many rows of the last result set it shows. */
    private class Composed {
        String text;
        Integer rows = 0;
        Composed(String text, Integer rows) {
            this.text = text;
            this.rows = rows;
        }
    }

    /** The answer text, then the last result set as a table, kept under MAX_CHARS. ERROR included. */
    @TestVisible
    private static String compose(DataExplorer.Result r) {
        return composeRows(r).text;
    }

    /**
     * The Cards output for this answer: DataExplorer's cards, the table cut to the rows the Answer shows, as JSON.
     * '' when over the cap, or when the cards could not be built: the Answer never depends on them.
     */
    @TestVisible
    private static String cardsJson(DataExplorer.Result r) {
        return cardsOf(r, composeRows(r).rows);
    }

    private static String cardsOf(DataExplorer.Result r, Integer rows) {
        try {
            return AnswerCard.toJson(DataExplorer.cards(r, rows));
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ExploreAction cards not built: ' + e.getTypeName() + ': ' + e.getMessage());
            return '';
        }
    }

    private static Composed composeRows(DataExplorer.Result r) {
        String text = r.answer == null ? '' : r.answer.trim();
        if (text.length() > MAX_CHARS) {
            return new Composed(text.left(MAX_CHARS - 3) + '...', 0);
        }
        // An ERROR answer is the fixed failure line; the table read before the failure still follows it (N4).
        if (r.resultSets.isEmpty()) {
            return new Composed(text, 0);
        }
        ExploreQuery.ResultSet rs = r.resultSets[r.resultSets.size() - 1];
        if (rs.rows.isEmpty()) {
            return new Composed(text, 0);
        }
        String header = String.join(DataExplorer.headers(rs), ' | ');
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
            return new Composed(text, 0);
        }
        if (shown < rs.total) {
            body += '\n(' + shown + ' of ' + rs.total + ' rows)';
        }
        return new Composed(body, shown);
    }
}
