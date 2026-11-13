// BE-31 engine 'real': the deployed DataExplorer.explore, untouched. Pass or fail and limits come from here.
// Its model calls cannot be counted from outside (Models API calls do not show in Limits.getCallouts()),
// so modelCalls and tokens print as -1; engine 'current' replays the same loop with a meter.
Meter m = new Meter();
m.calls = -1;
m.inTok = -1;
m.outTok = -1;
Outcome o = new Outcome();
Long t0 = System.currentTimeMillis();
DataExplorer.Result r = DataExplorer.explore(QUESTION, null, null);
Long wall = System.currentTimeMillis() - t0;
Integer soqlCount = Limits.getQueries(), cpu = Limits.getCpuTime(), heap = Limits.getHeapSize(), rows = Limits.getQueryRows();
o.status = r.status;
o.answer = r.answer == null ? '' : r.answer;
o.sets = r.resultSets.size();
o.queries = r.trail.size();
for (ExploreQuery.ResultSet rs : r.resultSets) {
    m.objects.add(rs.objectName);
}
if (!r.resultSets.isEmpty()) {
    o.lastRows = r.resultSets[r.resultSets.size() - 1].rows;
    o.lastTotal = r.resultSets[r.resultSets.size() - 1].total;
}
report(QID, 'real', REF, o, m, soqlCount, cpu, heap, rows, wall);
