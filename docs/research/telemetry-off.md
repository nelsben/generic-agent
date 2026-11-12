# Salesforce usage telemetry: off on this machine (OPS-10)

Status: partly done. The CLI and plugin opt-outs are saved. The shell variable fix is NOT applied (see below).

## What was changed
- sf CLI: `sf config set disable-telemetry=true --global` wrote `"disable-telemetry": "true"` to `~/.sf/config.json`.
- Plugin: `sf-context telemetry off` (salesforce-development 2.7.0) wrote `~/.sf/telemetry/telemetry-config.json` with `"enabled": false`.
- Not changed: `~/.zshenv` (the auto-mode classifier denied the append; see below), the Salesforce org, plugins, `~/.claude`, VS Code settings.

## Where SF_DISABLE_TELEMETRY=false comes from
Not found in: ~/.zshenv, ~/.zshrc, ~/.zprofile, /etc/zprofile, ~/.claude/settings.json, VS Code user settings.json, the repo's .vscode and .claude (absent), `launchctl getenv` (empty), Salesforce extension package.json files under ~/.vscode/extensions. (~/.profile and /etc/zshenv do not exist.)
The value is inherited from the parent process (the Claude Code VS Code extension binary). The sf CLI reports it as `"location": "Environment"`, so the env value overrides `disable-telemetry` in config.json.

## Needed from Ben (not done)
Append one line to ~/.zshenv:

    export SF_DISABLE_TELEMETRY=true

Then open a new terminal. Until then the CLI reads false from the inherited environment, even though config.json says true.

## Verification so far
- `sf-context telemetry status` prints: "State: OFF (forced off by SF_DISABLE_TELEMETRY / DO_NOT_TRACK)". OFF is currently due to the non-empty env value, not the saved opt-out.
- `sf config get disable-telemetry --json` reports value "false", location "Environment" (inherited variable).
- Fresh-shell check (`zsh -c 'echo $SF_DISABLE_TELEMETRY; sf config get ...'`) not run: the append was denied.

## How to turn back on
- sf CLI: `sf config set disable-telemetry=false --global`, and remove the ~/.zshenv line if added.
- Plugin: `/salesforce-development:telemetry on`, or `sf-context telemetry on`.

## What the plugin would have collected (from the card; not verified against plugin code)
Operating system, plugin version, editor, machine id, org type, connected org Id, commands, skills, subagents and MCP tools run with outcome, coarse error class.

## Unverified
- Whether the plugin reads `telemetry-config.json` when the env variable is set (status showed the env as the reason).
- The exact field list above.
- Whether the parent process re-injects false after a new login shell.
- The sf CLI's behavior with the env var set to true (expected to win over config).
