---
id: OPS-1
title: Repo is a minimal Salesforce DX project (API 68.0) with the four agent metadata folders
domain: ops
tier: economy
tier_reason: Mechanical scaffold of hand-written config files with every value specified in the card
status: merged
scope: [sfdx-project.json, .forceignore, .gitignore, README.md, force-app/**, tests/test_sfdx_project.py]
forbid: [tests/test_ok.py, tests/__init__.py, .chassis-delegation.json, agents/**]
red_test: python3 -m unittest discover -s tests (tests/test_sfdx_project.py fails before: no sfdx-project.json)
gate: test
budget: 2-attempts
spend: 3
---
## Why

generic-agent will hold a reusable baseline Agentforce agent that gets built and deployed to the `experimental` org. Nothing Salesforce-shaped exists yet, so every later card needs the project skeleton first. Testing/deploy-validation strategy is deliberately NOT part of this card; it comes later once we know what metadata we're pulling.

## Done when

- sfdx-project.json exists at the repo root: valid JSON, one packageDirectories entry {"path": "force-app", "default": true}, "name": "generic-agent", "namespace": "", "sfdcLoginUrl": "https://login.salesforce.com", "sourceApiVersion": "68.0"
- These folders exist, each holding only a .gitkeep: force-app/main/default/aiAuthoringBundles, force-app/main/default/flows, force-app/main/default/classes, force-app/main/default/genAiPromptTemplates, force-app/main/default/permissionsets
- .forceignore exists with the standard Salesforce DX entries (package.xml, **/jsconfig.json, **/.eslintrc.json, **/__tests__/**, **/.gitkeep)
- .gitignore keeps its existing .delegation/ line and adds .sf/, .sfdx/, .localdevserver/, node_modules/ and .DS_Store
- Hand-written files only: do NOT run `sf project generate`, and add no package.json, npm tooling, eslint, prettier, husky, jest, scratch-org config or manifest/ folder
- README.md exists: one short paragraph saying this is a reusable baseline Agentforce agent built and validated against the `experimental` org (sf alias), and a line listing the four metadata layers (Agent Script in aiAuthoringBundles, Flows, Apex classes, Prompt Templates in genAiPromptTemplates). No client names, no deploy instructions yet
- tests/test_sfdx_project.py (unittest, stdlib only) asserts the sfdx-project.json fields above and that the five folders exist; `python3 -m unittest discover -s tests` passes
- Do not touch tests/test_ok.py, tests/__init__.py, .chassis-delegation.json or agents/**
