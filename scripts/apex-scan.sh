#!/usr/bin/env bash
# Runs Salesforce Code Analyzer (recommended rules) on the Apex classes and prints the violations.
# Needs the code-analyzer plugin (`sf code-analyzer run --help`). Never installs anything.
# The PMD, CPD and SFGE engines need a Java 11+ runtime; without one they report an
# UninstantiableEngineError violation instead of results. Exit status is the CLI's own.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! sf code-analyzer run --help >/dev/null 2>&1; then
  echo "apex-scan: code-analyzer is not installed (sf code-analyzer run --help failed)"
  exit 1
fi

sf code-analyzer run --workspace force-app/main/default/classes --rule-selector Recommended --view table
