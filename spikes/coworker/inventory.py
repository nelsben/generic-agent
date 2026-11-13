#!/usr/bin/env python3
"""OPS-55 read-only inventory (spike, never deployed; run by hand, agent-probe only).

Asks agent-probe whether anything Agentforce Coworker exists: an app, a tab, a permission set, a permission set
group, a permission set licence, a user licence, an agent (BotDefinition) or a metadata type or Settings entry.
Uses SOQL queries and metadata lists only. Nothing is enabled, assigned, deployed, sent or changed.

Usage:
  python3 spikes/coworker/inventory.py      # writes spikes/coworker/results/inventory.jsonl (overwrites)

Each line is one check: what was asked, a count, and names (API names and labels only). No Ids, usernames,
emails, hostnames or tokens are written. Every sf call carries -o agent-probe.
"""
import datetime
import json
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
ORG = "agent-probe"
OUT = os.path.join(HERE, "results", "inventory.jsonl")
TIMEOUT_S = 180

# Words that would name Coworker or the AI Search feature it was built from (the setup docs' older names).
WORDS = ["Coworker", "Ai_Search", "AI Search", "AiSearch", "Search Agent", "Search_Agent"]


def sf(args, tooling=False):
    cmd = ["sf"] + args + ["-o", ORG, "--json"]
    if tooling:
        cmd.append("--use-tooling-api")
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT_S)
    try:
        body = json.loads(p.stdout)
    except ValueError:
        return None, "unparsed output, exit %d" % p.returncode
    if body.get("status") != 0:
        return None, (body.get("name") or "error") + ": " + (body.get("message") or "")[:160]
    return body.get("result"), None


def like(fields):
    return " OR ".join("%s LIKE '%%%s%%'" % (f, w) for f in fields for w in WORDS)


def query(check, soql, keys, tooling=False):
    res, err = sf(["data", "query", "-q", soql], tooling=tooling)
    if err:
        return {"check": check, "count": None, "error": err}
    recs = res.get("records", [])
    names = [{k: r.get(k) for k in keys} for r in recs]
    return {"check": check, "count": len(recs), "names": names}


def metadata_list(check, mtype, filt=None):
    res, err = sf(["org", "list", "metadata", "-m", mtype])
    if err:
        return {"check": check, "count": None, "error": err}
    names = sorted(r.get("fullName") for r in (res or []))
    if filt:
        names = [n for n in names if filt(n)]
    return {"check": check, "count": len(names), "names": names}


def has_word(s):
    s = (s or "").lower()
    return any(w.lower().replace(" ", "") in s.replace(" ", "") for w in WORDS)


def main():
    rows = []
    rows.append(query("org edition", "SELECT OrganizationType, IsSandbox FROM Organization",
                      ["OrganizationType", "IsSandbox"]))
    rows.append(query("permission sets named Coworker or AI Search",
                      "SELECT Name, Label FROM PermissionSet WHERE IsOwnedByProfile = false AND (%s)"
                      % like(["Name", "Label"]), ["Name", "Label"]))
    rows.append(query("permission set groups named Coworker or AI Search",
                      "SELECT DeveloperName, MasterLabel FROM PermissionSetGroup WHERE %s"
                      % like(["DeveloperName", "MasterLabel"]), ["DeveloperName", "MasterLabel"]))
    rows.append(query("permission set licences named Coworker or AI Search",
                      "SELECT DeveloperName, MasterLabel, Status, TotalLicenses, UsedLicenses FROM PermissionSetLicense "
                      "WHERE %s" % like(["DeveloperName", "MasterLabel"]),
                      ["DeveloperName", "MasterLabel", "Status", "TotalLicenses", "UsedLicenses"]))
    rows.append(query("all permission set licences with Agentforce, Einstein, Data Cloud or Data 360 in the label",
                      "SELECT DeveloperName, MasterLabel, Status, TotalLicenses, UsedLicenses FROM PermissionSetLicense "
                      "WHERE MasterLabel LIKE '%Agentforce%' OR MasterLabel LIKE '%Einstein%' "
                      "OR MasterLabel LIKE '%Data Cloud%' OR MasterLabel LIKE '%Data 360%' OR MasterLabel LIKE '%Agent%' "
                      "ORDER BY MasterLabel",
                      ["DeveloperName", "MasterLabel", "Status", "TotalLicenses", "UsedLicenses"]))
    rows.append(query("user licences named Coworker",
                      "SELECT Name, MasterLabel, Status, TotalLicenses, UsedLicenses FROM UserLicense WHERE %s"
                      % like(["Name", "MasterLabel"]), ["Name", "MasterLabel", "Status", "TotalLicenses", "UsedLicenses"]))
    rows.append(query("apps named Coworker (AppMenuItem)",
                      "SELECT Name, Label, Type FROM AppMenuItem WHERE %s" % like(["Name", "Label"]),
                      ["Name", "Label", "Type"]))
    # TabDefinition rejects OR in a filter, so read every tab's name and label and filter here.
    res, err = sf(["data", "query", "-q", "SELECT Name, Label FROM TabDefinition"])
    if err:
        rows.append({"check": "tabs named Coworker or AI Search (TabDefinition)", "count": None, "error": err})
    else:
        recs = res.get("records", [])
        hits = [{"Name": r.get("Name"), "Label": r.get("Label")} for r in recs
                if has_word(r.get("Name")) or has_word(r.get("Label"))]
        rows.append({"check": "tabs named Coworker or AI Search (TabDefinition)", "count": len(hits), "names": hits,
                     "tabsRead": len(recs)})
    rows.append(query("every agent (BotDefinition)",
                      "SELECT DeveloperName, MasterLabel, Type, AgentType, AgentTemplate, BotSource FROM BotDefinition "
                      "ORDER BY DeveloperName",
                      ["DeveloperName", "MasterLabel", "Type", "AgentType", "AgentTemplate", "BotSource"]))
    # BotVersion's parent name is nested; flatten it without Ids.
    res, err = sf(["data", "query", "-q", "SELECT BotDefinition.DeveloperName, VersionNumber, Status FROM BotVersion "
                   "ORDER BY BotDefinition.DeveloperName, VersionNumber"])
    if err:
        rows.append({"check": "every agent version (BotVersion)", "count": None, "error": err})
    else:
        recs = res.get("records", [])
        rows.append({"check": "every agent version (BotVersion)", "count": len(recs),
                     "names": [{"agent": (r.get("BotDefinition") or {}).get("DeveloperName"),
                                "VersionNumber": r.get("VersionNumber"), "Status": r.get("Status")} for r in recs]})
    rows.append(query("objects with Coworker in the API name (EntityDefinition, Tooling API)",
                      "SELECT QualifiedApiName FROM EntityDefinition WHERE QualifiedApiName LIKE '%Coworker%'",
                      ["QualifiedApiName"], tooling=True))
    res, err = sf(["org", "list", "metadata-types"])
    if err:
        rows.append({"check": "metadata types with Coworker or Search in the name", "count": None, "error": err})
    else:
        types = sorted(m["xmlName"] for m in res.get("metadataObjects", []))
        hits = [t for t in types if "cowork" in t.lower() or "search" in t.lower()]
        rows.append({"check": "metadata types with Coworker or Search in the name", "count": len(hits),
                     "names": hits, "typesListed": len(types)})
    rows.append(metadata_list("Settings entries named Coworker or Search", "Settings",
                              lambda n: "cowork" in n.lower() or "search" in n.lower()))
    rows.append(metadata_list("CustomApplication names with Coworker", "CustomApplication", has_word))
    rows.append(metadata_list("GenAiPlannerBundle names (all)", "GenAiPlannerBundle"))
    rows.append(metadata_list("AiAgentDefinition names (all)", "AiAgentDefinition"))
    rows.append(metadata_list("AIApplication names (all)", "AIApplication"))
    stamp = datetime.date.today().isoformat()
    with open(OUT, "w", encoding="utf-8") as f:
        for r in rows:
            r["date"] = stamp
            f.write(json.dumps(r, sort_keys=True) + "\n")
    for r in rows:
        print(json.dumps(r, sort_keys=True))


if __name__ == "__main__":
    main()
