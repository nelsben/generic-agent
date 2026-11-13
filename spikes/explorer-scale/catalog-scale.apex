// BE-31 catalog growth: the prompt text and the CPU and heap it costs to describe N allowed objects
// (the prototype's catalog line for each), for N = 8 (the core set), 10, 50, 200 and all, and a
// names-only index (API name and label) of every allowed object. Read-only. Prints counts only.
// Run with: python3 spikes/explorer-scale/run.py tool catalog-scale.apex
Cat cat = new Cat();
Meter m = new Meter();
Integer c0 = Limits.getCpuTime();
List<String> keys = new List<String>(cat.g.keySet());
keys.sort();
List<String> allowed = new List<String>();
List<String> index = new List<String>();
Boolean stopped = false;
for (String k : keys) {
    if (Limits.getCpuTime() > 6000) {
        stopped = true;
        break;
    }
    DescribeSObjectResult d = cat.obj(k);
    if (d != null) {
        allowed.add(d.getName());
        index.add(d.getName() + ' (' + d.getLabel() + ')');
    }
}
System.debug(LoggingLevel.ERROR, 'CAT :: index :: objects=' + allowed.size() + ' of ' + keys.size() + ' stoppedEarly=' + stopped + ' chars=' + String.join(index, ', ').length() + ' cpuMs=' + (Limits.getCpuTime() - c0) + ' heap=' + Limits.getHeapSize());
// Lines for the core set first (as engine v2 sends them), then the other allowed objects in name order.
List<String> order = new List<String>{ 'Account', 'Contact', 'Opportunity', 'OpportunityContactRole', 'Case', 'Task', 'Event', 'User' };
for (String n : allowed) {
    if (!order.contains(n)) {
        order.add(n);
    }
}
Set<String> inPrompt = new Set<String>();
for (String n : order) {
    inPrompt.add(n.toLowerCase());
}
Integer chars = 0;
Integer c1 = Limits.getCpuTime();
Set<Integer> marks = new Set<Integer>{ 8, 10, 50, 200 };
Integer done = 0;
stopped = false;
for (String n : order) {
    if (Limits.getCpuTime() > 9000) {
        stopped = true;
        break;
    }
    String line = cat.line(cat.obj(n), inPrompt);
    chars += line.length() + 1;
    done++;
    if (marks.contains(done)) {
        System.debug(LoggingLevel.ERROR, 'CAT :: lines :: n=' + done + ' chars=' + chars + ' approxTokens=' + chars / 4 + ' cpuMs=' + (Limits.getCpuTime() - c1) + ' heap=' + Limits.getHeapSize());
    }
}
System.debug(LoggingLevel.ERROR, 'CAT :: lines :: n=' + done + ' of ' + order.size() + ' stoppedEarly=' + stopped + ' chars=' + chars + ' approxTokens=' + chars / 4 + ' cpuMs=' + (Limits.getCpuTime() - c1) + ' heap=' + Limits.getHeapSize());
