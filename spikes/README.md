# spikes

Throwaway FR2 spike code. Each spike gets one subfolder here, named in that spike's card.

Nothing under this folder is deployed by the README's quick start, by `scripts/validate-org.sh`, or by a deploy of
`force-app`. Those paths never read this folder.

A spike is deployed only by its own card, with `--source-dir spikes/<name>`. Never deploy the whole folder.

Each spike's research page under `docs/research/` ends with an "Undo" list of what it left in the org.

Product code under `force-app` never refers to anything here.

This folder is registered as a non-default package directory in `sfdx-project.json` so the spike cards need no
change to that file.
