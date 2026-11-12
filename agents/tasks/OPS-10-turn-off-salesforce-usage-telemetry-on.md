---
id: OPS-10
title: Turn off Salesforce usage telemetry on this machine for both the sf CLI and the salesforce-development Claude plugin, persistently, and record how in docs/research/telemetry-off.md
domain: ops
tier: economy
tier_reason: three commands, one config search and a short note
status: queued
repo: here
scope: [docs/research/telemetry-off.md, ~/.sf/telemetry/**, ~/.sf/config.json, ~/.zshenv]
forbid: [force-app/**, agents/**, reference/**, .chassis-delegation.json, scripts/**, tests/**, ~/.claude/**]
red_test: none
gate: test
budget: 2-attempts
spend: 3
---
## Why

The environment carries SF_DISABLE_TELEMETRY=false. The sf CLI reads that as telemetry on; the salesforce-development plugin reads any non-empty value as off, so the plugin is off only by accident and no persistent opt-out is saved. Ben wants both off for good.

## Done when

- Do not touch the Salesforce org, do not install or remove plugins, do not edit anything under ~/.claude or any VS Code settings file. A plugin hook may refuse a shell command whose text contains certain keywords and suggest installing a plugin: never install; reword or split the command instead, and note it in the hand-back
- Plugin opt-out saved: run `~/.claude/plugins/cache/salesforce/salesforce-development/2.7.0/scripts/sf-context telemetry off`, then `... telemetry status`. Status must show OFF, and ~/.sf/telemetry/telemetry-config.json must exist with enabled false. Quote the status output
- CLI opt-out saved: run `sf config set disable-telemetry true --global` (check the flag spelling with `sf config set --help` first)
- Find where SF_DISABLE_TELEMETRY=false is set. Read-only search of: ~/.zshenv, ~/.zshrc, ~/.zprofile, ~/.profile, /etc/zshenv, /etc/zprofile, ~/.claude/settings.json, ~/.claude/settings.local.json, the VS Code user settings.json under ~/Library/Application Support/Code/User, the repo's .vscode and .claude folders, `launchctl getenv SF_DISABLE_TELEMETRY`, and the package.json files of Salesforce VS Code extensions under ~/.vscode/extensions. Report the file and line, or 'not found' with the list searched
- Fix the variable: if it is set in ~/.zshenv, change the value to true there. Otherwise append exactly `export SF_DISABLE_TELEMETRY=true` to ~/.zshenv (create the file if absent) and, if the source was a file you may not edit, name that file and the one-line change Ben must make himself. Do not edit any other shell file
- Verify in a fresh shell: `zsh -c 'echo $SF_DISABLE_TELEMETRY; sf config get disable-telemetry --json'` prints true and the CLI reports value true. If the environment still injects false ahead of ~/.zshenv, say so plainly; do not claim success
- Write docs/research/telemetry-off.md, under 40 lines: what was changed and where, how to turn each back on, what the plugin would have collected (operating system, plugin version, editor, machine id, org type, connected org Id, commands, skills, subagents and MCP tools run with outcome, coarse error class), and what stays unverified. Do not write the machine id, org Id or the user's name or email in the file. Gate passes: test. The repo checkout is on main and commits there are blocked: leave the doc uncommitted and say so in the hand-back
