/**
 * Test data for customerSummaryCard: the JSON examples of the two card pages, as data.
 *
 * FIXTURES are the FE-18 page's examples (docs/research/fr2-card-architecture.md), one per type, as the
 * spike carried them, with one fix: the notice says "Showing 6 of 212 rows", agreeing with the table
 * card beside it (the spike's notice said 50). BE39_FIXTURES are the three examples only BE-39's page
 * (docs/research/fr2-card-contract-apex.md) adds: the resolver's choice and not-found cards and a
 * drill's record card. FALLBACKS are the spike gallery's three cards a surface cannot draw.
 * Record Ids are placeholders; names are sample data.
 */
export const FIXTURES = [
    {
        "type": "summary",
        "version": 1,
        "key": "sum",
        "title": "Edge Communications: steady service, one large renewal at risk",
        "meta": "Account summary",
        "status": "OK",
        "text": "Edge Communications: steady service, one large renewal at risk\nOpen deals: 3 worth $412,000; the largest closes this quarter.\nService health: 2 open cases, one high priority for 9 days.\n- Renewal owner has not logged a call in 41 days\n- Two contacts on their side have never been called",
        "body": [
            {
                "kind": "p",
                "runs": [
                    {
                        "text": "Open deals:",
                        "strong": true
                    },
                    {
                        "text": " 3 worth $412,000; the largest closes this quarter."
                    }
                ]
            },
            {
                "kind": "p",
                "runs": [
                    {
                        "text": "Service health:",
                        "strong": true
                    },
                    {
                        "text": " 2 open cases, one "
                    },
                    {
                        "text": "high priority",
                        "em": true
                    },
                    {
                        "text": " for 9 days."
                    }
                ]
            },
            {
                "kind": "li",
                "runs": [
                    {
                        "text": "Renewal owner has not logged a call in 41 days"
                    }
                ]
            },
            {
                "kind": "li",
                "runs": [
                    {
                        "text": "Two contacts on their side have never been called"
                    }
                ]
            }
        ],
        "refs": []
    },
    {
        "type": "section",
        "version": 1,
        "key": "sec-deals",
        "title": "Open deals",
        "status": "OK",
        "text": "Open deals (3 of 3)\n- Edge Emergency Generator — Proposal · $250,000 · closes 2026-12-18\n- Edge Installation — Negotiation · $112,000 · closes 2027-01-30\n- Edge SLA — Qualification · $50,000 · closes 2027-03-02",
        "body": [],
        "total": 3,
        "shown": 3,
        "items": [
            {
                "label": "Edge Emergency Generator",
                "detail": "Proposal · $250,000 · closes 2026-12-18",
                "ref": "o1"
            },
            {
                "label": "Edge Installation",
                "detail": "Negotiation · $112,000 · closes 2027-01-30",
                "ref": "o2"
            },
            {
                "label": "Edge SLA",
                "detail": "Qualification · $50,000 · closes 2027-03-02",
                "ref": "o3"
            }
        ],
        "refs": [
            {
                "key": "o1",
                "recordId": "record-id:o1",
                "objectName": "Opportunity",
                "label": "Edge Emergency Generator"
            },
            {
                "key": "o2",
                "recordId": "record-id:o2",
                "objectName": "Opportunity",
                "label": "Edge Installation"
            },
            {
                "key": "o3",
                "recordId": "record-id:o3",
                "objectName": "Opportunity",
                "label": "Edge SLA"
            }
        ]
    },
    {
        "type": "section",
        "version": 1,
        "key": "sec-calls",
        "title": "Calls",
        "status": "ERROR",
        "text": "Calls\nCouldn't load Calls right now.",
        "body": [
            {
                "kind": "p",
                "runs": [
                    {
                        "text": "Couldn't load Calls right now."
                    }
                ]
            }
        ],
        "total": 0,
        "shown": 0,
        "items": [],
        "refs": []
    },
    {
        "type": "text",
        "version": 1,
        "key": "ans",
        "title": "",
        "status": "OK",
        "text": "There are 212 open opportunities; the 6 largest are below. The top one is Edge Emergency Generator, at $250,000.",
        "body": [
            {
                "kind": "p",
                "runs": [
                    {
                        "text": "There are "
                    },
                    {
                        "text": "212",
                        "strong": true
                    },
                    {
                        "text": " open opportunities; the 6 largest are below. The top one is "
                    },
                    {
                        "text": "Edge Emergency Generator",
                        "ref": "o1"
                    },
                    {
                        "text": ", at "
                    },
                    {
                        "text": "$250,000",
                        "code": true
                    },
                    {
                        "text": "."
                    }
                ]
            }
        ],
        "refs": [
            {
                "key": "o1",
                "recordId": "record-id:o1",
                "objectName": "Opportunity",
                "label": "Edge Emergency Generator"
            }
        ]
    },
    {
        "type": "table",
        "version": 1,
        "key": "tbl",
        "title": "Opportunity",
        "status": "OK",
        "text": "Opportunity\nName | Stage | Amount | Close date\nEdge Emergency Generator | Proposal | $250,000 | 2026-12-18\nJuniper Project B | Negotiation | $180,000 | 2026-12-04\nFernhollow Project C | Proposal | $160,000 | 2027-01-12\nEdge Installation | Negotiation | $112,000 | 2027-01-30\nPimble Project B | Qualification | $95,000 | 2027-02-20\nEdge SLA | Qualification | $50,000 | 2027-03-02\n(6 of 212 rows)",
        "body": [],
        "columns": [
            {
                "key": "Name",
                "label": "Name",
                "kind": "text"
            },
            {
                "key": "StageName",
                "label": "Stage",
                "kind": "text"
            },
            {
                "key": "Amount",
                "label": "Amount",
                "kind": "currency"
            },
            {
                "key": "CloseDate",
                "label": "Close date",
                "kind": "date"
            }
        ],
        "rows": [
            {
                "ref": "o1",
                "cells": [
                    "Edge Emergency Generator",
                    "Proposal",
                    "$250,000",
                    "2026-12-18"
                ]
            },
            {
                "ref": "o4",
                "cells": [
                    "Juniper Project B",
                    "Negotiation",
                    "$180,000",
                    "2026-12-04"
                ]
            },
            {
                "ref": "o5",
                "cells": [
                    "Fernhollow Project C",
                    "Proposal",
                    "$160,000",
                    "2027-01-12"
                ]
            },
            {
                "ref": "o2",
                "cells": [
                    "Edge Installation",
                    "Negotiation",
                    "$112,000",
                    "2027-01-30"
                ]
            },
            {
                "ref": "o6",
                "cells": [
                    "Pimble Project B",
                    "Qualification",
                    "$95,000",
                    "2027-02-20"
                ]
            },
            {
                "ref": "o3",
                "cells": [
                    "Edge SLA",
                    "Qualification",
                    "$50,000",
                    "2027-03-02"
                ]
            }
        ],
        "total": 212,
        "shown": 6,
        "refs": [
            {
                "key": "o1",
                "recordId": "record-id:o1",
                "objectName": "Opportunity",
                "label": "Edge Emergency Generator"
            },
            {
                "key": "o4",
                "recordId": "record-id:o4",
                "objectName": "Opportunity",
                "label": "Juniper Project B"
            },
            {
                "key": "o5",
                "recordId": "record-id:o5",
                "objectName": "Opportunity",
                "label": "Fernhollow Project C"
            },
            {
                "key": "o2",
                "recordId": "record-id:o2",
                "objectName": "Opportunity",
                "label": "Edge Installation"
            },
            {
                "key": "o6",
                "recordId": "record-id:o6",
                "objectName": "Opportunity",
                "label": "Pimble Project B"
            },
            {
                "key": "o3",
                "recordId": "record-id:o3",
                "objectName": "Opportunity",
                "label": "Edge SLA"
            }
        ]
    },
    {
        "type": "metric",
        "version": 1,
        "key": "met",
        "title": "Open pipeline",
        "status": "OK",
        "text": "Open pipeline\nOpen opportunities: 212 — in your access\nTotal amount: $18.4M\nClosing this quarter: 37",
        "body": [],
        "items": [
            {
                "label": "Open opportunities",
                "value": "212",
                "detail": "in your access"
            },
            {
                "label": "Total amount",
                "value": "$18.4M"
            },
            {
                "label": "Closing this quarter",
                "value": "37"
            }
        ],
        "refs": []
    },
    {
        "type": "record",
        "version": 1,
        "key": "rec",
        "title": "Edge Emergency Generator",
        "meta": "Opportunity",
        "status": "OK",
        "text": "Edge Emergency Generator · Opportunity\nAccount: Edge Communications\nStage: Proposal\nAmount: $250,000\nClose date: 2026-12-18\nOwner: Seller One",
        "body": [],
        "fields": [
            {
                "key": "AccountId",
                "label": "Account",
                "value": "Edge Communications",
                "ref": "a1"
            },
            {
                "key": "StageName",
                "label": "Stage",
                "value": "Proposal"
            },
            {
                "key": "Amount",
                "label": "Amount",
                "value": "$250,000"
            },
            {
                "key": "CloseDate",
                "label": "Close date",
                "value": "2026-12-18"
            },
            {
                "key": "OwnerId",
                "label": "Owner",
                "value": "Seller One"
            }
        ],
        "items": [
            {
                "label": "Tasks",
                "kind": "related"
            },
            {
                "label": "Events",
                "kind": "related"
            },
            {
                "label": "Opportunity Contact Roles",
                "kind": "related"
            }
        ],
        "refs": [
            {
                "key": "a1",
                "recordId": "record-id:a1",
                "objectName": "Account",
                "label": "Edge Communications"
            }
        ]
    },
    {
        "type": "recordList",
        "version": 1,
        "key": "lst",
        "title": "Contacts never called",
        "status": "OK",
        "text": "Contacts never called\n- Contact One — VP Facilities\n- Contact Two — Procurement lead\n- Contact Three — IT director\n(3 of 4)",
        "body": [],
        "total": 4,
        "shown": 3,
        "items": [
            {
                "label": "Contact One",
                "detail": "VP Facilities",
                "ref": "c1"
            },
            {
                "label": "Contact Two",
                "detail": "Procurement lead",
                "ref": "c2"
            },
            {
                "label": "Contact Three",
                "detail": "IT director",
                "ref": "c3"
            }
        ],
        "refs": [
            {
                "key": "c1",
                "recordId": "record-id:c1",
                "objectName": "Contact",
                "label": "Contact One"
            },
            {
                "key": "c2",
                "recordId": "record-id:c2",
                "objectName": "Contact",
                "label": "Contact Two"
            },
            {
                "key": "c3",
                "recordId": "record-id:c3",
                "objectName": "Contact",
                "label": "Contact Three"
            }
        ]
    },
    {
        "type": "timeline",
        "version": 1,
        "key": "tml",
        "title": "Recent activity",
        "status": "OK",
        "text": "Recent activity\n2026-11-10 · Call: renewal check-in — Seller One\n2026-11-04 · Email: revised proposal sent — Seller One\n2026-10-28 · Case comment: generator fault — Support",
        "body": [],
        "items": [
            {
                "at": "2026-11-10",
                "kind": "call",
                "label": "Call: renewal check-in",
                "detail": "Seller One",
                "ref": "t1"
            },
            {
                "at": "2026-11-04",
                "kind": "email",
                "label": "Email: revised proposal sent",
                "detail": "Seller One",
                "ref": "t2"
            },
            {
                "at": "2026-10-28",
                "kind": "case",
                "label": "Case comment: generator fault",
                "detail": "Support",
                "ref": "k1"
            }
        ],
        "refs": [
            {
                "key": "t1",
                "recordId": "record-id:t1",
                "objectName": "Task",
                "label": "Call: renewal check-in"
            },
            {
                "key": "t2",
                "recordId": "record-id:t2",
                "objectName": "Task",
                "label": "Email: revised proposal sent"
            },
            {
                "key": "k1",
                "recordId": "record-id:k1",
                "objectName": "Case",
                "label": "Generator fault"
            }
        ]
    },
    {
        "type": "comparison",
        "version": 1,
        "key": "cmp",
        "title": "Two largest open deals",
        "status": "OK",
        "text": "Two largest open deals\nField | Edge Emergency Generator | Juniper Project B\nStage | Proposal | Negotiation\nAmount | $250,000 | $180,000\nClose date | 2026-12-18 | 2026-12-04\nLast activity | 3 days ago | 19 days ago",
        "body": [],
        "columns": [
            {
                "key": "field",
                "label": "Field",
                "kind": "text"
            },
            {
                "key": "o1",
                "label": "Edge Emergency Generator",
                "kind": "text"
            },
            {
                "key": "o4",
                "label": "Juniper Project B",
                "kind": "text"
            }
        ],
        "rows": [
            {
                "cells": [
                    "Stage",
                    "Proposal",
                    "Negotiation"
                ]
            },
            {
                "cells": [
                    "Amount",
                    "$250,000",
                    "$180,000"
                ]
            },
            {
                "cells": [
                    "Close date",
                    "2026-12-18",
                    "2026-12-04"
                ]
            },
            {
                "cells": [
                    "Last activity",
                    "3 days ago",
                    "19 days ago"
                ]
            }
        ],
        "refs": []
    },
    {
        "type": "choice",
        "version": 1,
        "key": "cho",
        "title": "More than one account matches \"edge\". Which one?",
        "status": "AMBIGUOUS",
        "text": "More than one account matches \"edge\". Which one?\n1. Edge Communications — Austin\n2. Edge Communications — Toronto\n3. Edgewater Freight — Portland",
        "body": [],
        "items": [
            {
                "label": "Edge Communications",
                "detail": "Austin",
                "ref": "a1"
            },
            {
                "label": "Edge Communications",
                "detail": "Toronto",
                "ref": "a2"
            },
            {
                "label": "Edgewater Freight",
                "detail": "Portland",
                "ref": "a3"
            }
        ],
        "refs": [
            {
                "key": "a1",
                "recordId": "record-id:a1",
                "objectName": "Account",
                "label": "Edge Communications"
            },
            {
                "key": "a2",
                "recordId": "record-id:a2",
                "objectName": "Account",
                "label": "Edge Communications"
            },
            {
                "key": "a3",
                "recordId": "record-id:a3",
                "objectName": "Account",
                "label": "Edgewater Freight"
            }
        ]
    },
    {
        "type": "followups",
        "version": 1,
        "key": "fol",
        "title": "Ask next",
        "text": "Ask next\n- Which of these close this quarter?\n- Who on their side have we not called?\n- Show the open cases",
        "body": [],
        "items": [
            {
                "label": "Which of these close this quarter?"
            },
            {
                "label": "Who on their side have we not called?"
            },
            {
                "label": "Show the open cases"
            }
        ],
        "refs": []
    },
    {
        "type": "trail",
        "version": 1,
        "key": "trl",
        "title": "Ran 2 queries",
        "text": "Ran 2 queries\n1. Opportunity where IsClosed = false: COUNT() — 212 rows\n2. Opportunity where IsClosed = false, by Amount descending, first 6 — 6 of 212 rows",
        "body": [],
        "items": [
            {
                "label": "Opportunity where IsClosed = false: COUNT()",
                "detail": "212 rows"
            },
            {
                "label": "Opportunity where IsClosed = false, by Amount descending, first 6",
                "detail": "6 of 212 rows"
            }
        ],
        "refs": []
    },
    {
        "type": "notice",
        "version": 1,
        "key": "not",
        "title": "",
        "status": "OK",
        "text": "Showing 6 of 212 rows. Ask with a filter, such as a stage or a close date, to narrow it.",
        "body": [
            {
                "kind": "p",
                "runs": [
                    {
                        "text": "Showing 6 of 212 rows. Ask with a filter, such as a stage or a close date, to narrow it."
                    }
                ]
            }
        ],
        "refs": []
    },
    {
        "type": "error",
        "version": 1,
        "key": "err",
        "title": "",
        "status": "ERROR",
        "text": "I couldn't finish that right now. Try again in a minute.",
        "body": [
            {
                "kind": "p",
                "runs": [
                    {
                        "text": "I couldn't finish that right now. Try again in a minute."
                    }
                ]
            }
        ],
        "refs": []
    },
    {
        "type": "actionDraft",
        "version": 1,
        "key": "drf",
        "title": "Create a task",
        "meta": "Task · create",
        "status": "NEEDS_INPUT",
        "text": "Create a task · Task · create\nSubject: Follow up on the generator proposal\nDue: 2026-11-17\nContact: Jordan (choose one)\nRelated to: Edge Emergency Generator\nPriority: (needed)\nNote: Two contacts match \"Jordan\"; choose one or clear the field.\nOptions: Confirm, Edit, Cancel",
        "body": [],
        "fields": [
            {
                "key": "Subject",
                "label": "Subject",
                "value": "Follow up on the generator proposal"
            },
            {
                "key": "ActivityDate",
                "label": "Due",
                "value": "2026-11-17"
            },
            {
                "key": "WhoId",
                "label": "Contact",
                "value": "Jordan",
                "state": "choose",
                "choices": [
                    "c1",
                    "c4"
                ]
            },
            {
                "key": "WhatId",
                "label": "Related to",
                "value": "Edge Emergency Generator",
                "ref": "o1"
            },
            {
                "key": "Priority",
                "label": "Priority",
                "value": "",
                "state": "missing"
            }
        ],
        "items": [
            {
                "label": "Two contacts match \"Jordan\"; choose one or clear the field."
            }
        ],
        "controls": [
            {
                "key": "confirm",
                "label": "Confirm",
                "kind": "primary"
            },
            {
                "key": "edit",
                "label": "Edit",
                "kind": "neutral"
            },
            {
                "key": "cancel",
                "label": "Cancel",
                "kind": "link"
            }
        ],
        "refs": [
            {
                "key": "c1",
                "recordId": "record-id:c1",
                "objectName": "Contact",
                "label": "Jordan Lee"
            },
            {
                "key": "c4",
                "recordId": "record-id:c4",
                "objectName": "Contact",
                "label": "Jordan Park"
            },
            {
                "key": "o1",
                "recordId": "record-id:o1",
                "objectName": "Opportunity",
                "label": "Edge Emergency Generator"
            }
        ]
    },
    {
        "type": "actionResult",
        "version": 1,
        "key": "res",
        "title": "Task created",
        "meta": "Task",
        "status": "OK",
        "text": "Task created · Task\nSubject: Follow up on the generator proposal\nDue: 2026-11-17\nContact: Jordan Lee\nSaved as you, with your access. Undo is offered for 15 seconds after an update.",
        "body": [
            {
                "kind": "p",
                "runs": [
                    {
                        "text": "Saved as you, with your access. Undo is offered for 15 seconds after an update."
                    }
                ]
            }
        ],
        "fields": [
            {
                "key": "Subject",
                "label": "Subject",
                "value": "Follow up on the generator proposal",
                "ref": "t9"
            },
            {
                "key": "ActivityDate",
                "label": "Due",
                "value": "2026-11-17"
            },
            {
                "key": "WhoId",
                "label": "Contact",
                "value": "Jordan Lee"
            }
        ],
        "controls": [
            {
                "key": "open",
                "label": "Open task",
                "kind": "primary"
            }
        ],
        "refs": [
            {
                "key": "t9",
                "recordId": "record-id:t9",
                "objectName": "Task",
                "label": "Follow up on the generator proposal"
            }
        ]
    }
];

export const BE39_FIXTURES = [
    {
        "type": "choice",
        "version": 1,
        "key": "cho",
        "title": "Several accounts match \"Edge\". Which one?",
        "status": "AMBIGUOUS",
        "text": "Several accounts match \"Edge\". Which one?\n1. Edge Communications — Austin\n2. Edge Communications — no city",
        "body": [],
        "items": [
            {
                "label": "Edge Communications",
                "detail": "Austin",
                "ref": "a1"
            },
            {
                "label": "Edge Communications",
                "detail": "no city",
                "ref": "a2"
            }
        ],
        "refs": [
            {
                "key": "a1",
                "recordId": "record-id:a1",
                "objectName": "Account",
                "label": "Edge Communications"
            },
            {
                "key": "a2",
                "recordId": "record-id:a2",
                "objectName": "Account",
                "label": "Edge Communications"
            }
        ]
    },
    {
        "type": "notice",
        "version": 1,
        "key": "not",
        "title": "",
        "status": "NOT_FOUND",
        "text": "No account matches \"Edgx\". Try a fuller or different account name.",
        "body": [
            {
                "kind": "p",
                "runs": [
                    {
                        "text": "No account matches \"Edgx\". Try a fuller or different account name."
                    }
                ]
            }
        ],
        "refs": []
    },
    {
        "type": "record",
        "version": 1,
        "key": "rec",
        "title": "Panel Deal",
        "meta": "Opportunity",
        "status": "OK",
        "text": "Panel Deal · Opportunity\nAccount: Panel Acme\nStage: Prospecting\nAmount: $500\nClose Date: 2026-12-13",
        "body": [],
        "fields": [
            {
                "key": "Account",
                "label": "Account",
                "value": "Panel Acme",
                "ref": "a1"
            },
            {
                "key": "Stage",
                "label": "Stage",
                "value": "Prospecting"
            },
            {
                "key": "Amount",
                "label": "Amount",
                "value": "$500"
            },
            {
                "key": "Close Date",
                "label": "Close Date",
                "value": "2026-12-13"
            }
        ],
        "items": [
            {
                "label": "Tasks",
                "kind": "related"
            },
            {
                "label": "Opportunity Contact Roles",
                "kind": "related"
            }
        ],
        "refs": [
            {
                "key": "a1",
                "recordId": "record-id:a1",
                "objectName": "Account",
                "label": "Panel Acme"
            }
        ]
    }
];

export const FALLBACKS = [
    { type: 'mapPins', version: 1, key: 'fb-type', title: 'Accounts near Austin', text: 'Accounts near Austin\n- Edge Communications — 2 km\n- Edgewater Freight — 9 km' },
    { type: 'table', version: 2, key: 'fb-version', title: 'Opportunity', text: 'Opportunity\nName | Stage\nEdge SLA | Qualification' },
    { type: 'recordList', version: 1, key: 'fb-throw', title: 'Contacts', items: [null], text: 'Contacts\n- Jordan Lee — VP Facilities' }
];
