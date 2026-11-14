#!/usr/bin/env bash
# Runs Salesforce Code Analyzer (recommended rules) and prints the violations. Reports; does not gate.
# Needs the code-analyzer plugin (`sf code-analyzer run --help`). Never installs anything.
# With Java 11 or later: every Recommended rule on the Apex classes (PMD, CPD and SFGE need Java).
# Without Java: the engines that need none (eslint, regex, retire-js, flow) on all of force-app, and it
# says which engines it skipped and that installing Java 11 or later turns them on.
# Exit status is the CLI's own; the Java-less run adds nothing to it.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SF="${SF_BIN:-/usr/local/bin/sf}"
[ -x "$SF" ] || SF="$(command -v sf || true)"
if [ -z "$SF" ] || ! "$SF" code-analyzer run --help >/dev/null 2>&1; then
  echo "apex-scan: code-analyzer is not installed (sf code-analyzer run --help failed)"
  exit 1
fi

java_major=""
if java_out="$(java -version 2>&1)"; then
  java_major="$(printf '%s\n' "$java_out" | sed -n '1s/.*version "\([0-9][0-9]*\)\(\.\([0-9][0-9]*\)\)\{0,1\}.*/\1/p')"
  [ "$java_major" = "1" ] && java_major="$(printf '%s\n' "$java_out" | sed -n '1s/.*version "1\.\([0-9][0-9]*\).*/\1/p')"
fi

if [ -n "$java_major" ] && [ "$java_major" -ge 11 ] 2>/dev/null; then
  echo "apex-scan: java $java_major found, running every Recommended rule on the Apex classes"
  "$SF" code-analyzer run --workspace force-app/main/default/classes --rule-selector Recommended --view table
  exit $?
fi

echo "apex-scan: no Java 11 or later found; running the engines that need none (eslint, regex, retire-js, flow) on force-app"
"$SF" code-analyzer run --workspace force-app \
  --rule-selector eslint:Recommended --rule-selector regex:Recommended \
  --rule-selector retire-js:Recommended --rule-selector flow:Recommended --view table
rc=$?
echo "apex-scan: skipped the pmd, cpd and sfge engines (the Apex rules): they need Java. Installing Java 11 or later turns them on."
exit $rc
