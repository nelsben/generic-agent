/**
 * cardContract: the FR2 card contract (FE-18, built in Apex by BE-39), as plain functions. Ported
 * from spikes/cards/ cardSpikeContract, which stays as it was.
 *
 * One card is one flat, typed object that Apex builds from @AuraEnabled classes and that survives
 * a JSON round trip: no Map member, no Object member, every table cell a string. The shape and the
 * rules are in docs/research/fr2-card-architecture.md and docs/research/fr2-card-contract-apex.md.
 *
 *   parseRich(text, refs)  the rich-text subset as blocks of runs (never markup). Only for text a
 *                          surface writes itself: a card's rich text arrives as body runs.
 *   plainText(card)        the Id-free plain-text fallback, one rule per type
 *   viewOf(card, density, options)  the view model the card component binds, or a fallback view;
 *                          never throws. options.actions draws the action types (FE-14).
 *
 * A new card type is one entry in TYPES (its version, its layout family) and one plain-text rule.
 * A type marked ready: false is registered but not drawn by default: it shows its text. The action
 * types are drawn only for a host that runs the write actions and says so (options.actions, which
 * c-customer-summary-card passes when its action-mode is set, FE-14); everywhere else they show their
 * text, so a surface that cannot confirm a draft never shows a Confirm button.
 */

export const CONTRACT_VERSION = 1;

// The layout families the card component draws. A new type maps to one of these, so it needs no new
// template unless it needs a new family.
export const FAMILY = {
    PROSE: 'prose',
    LIST: 'list',
    FIELDS: 'fields',
    GRID: 'grid',
    METRIC: 'metric',
    CHIPS: 'chips',
    FALLBACK: 'fallback'
};

// Rows a grid shows before "Show all"; a list's items before "Show all". The total line is never folded.
const FOLD = { compact: 5, comfortable: 10 };
// A grid with more columns than this is drawn as stacked rows at the compact density. A comparison
// stacks as soon as it compares two records: at 340 px a field column and two record columns leave
// each record about 100 px, too narrow for its name as a column head.
const COMPACT_MAX_COLUMNS = 3;
const COMPACT_MAX_COMPARISON_COLUMNS = 2;

// **strong**, *em* (starts with a non-space, so '5 * 3' stays plain), `code`, [label](ref:key).
const INLINE = /\*\*([^*\n]+)\*\*|\*([^*\s\n][^*\n]*)\*|`([^`\n]+)`|\[([^\]\n]+)\]\(ref:([A-Za-z0-9_-]+)\)/g;
const BULLET = /^\s*[-•]\s+(.*)$/;
const NUMBERED = /^\s*(\d{1,3})[.)]\s+(.*)$/;

function list(value) {
    return Array.isArray(value) ? value : [];
}

function str(value) {
    return value === null || value === undefined ? '' : String(value);
}

function refMap(card) {
    const map = {};
    list(card && card.refs).forEach((r) => {
        if (r && r.key) {
            map[r.key] = r;
        }
    });
    return map;
}

/** One line's inline runs. A link whose ref the card does not carry is plain text: its label only. */
export function parseInline(line, refs) {
    const s = str(line);
    const known = refs || {};
    const runs = [];
    let last = 0;
    let m;
    INLINE.lastIndex = 0;
    while ((m = INLINE.exec(s)) !== null) {
        if (m.index > last) {
            runs.push({ text: s.slice(last, m.index) });
        }
        if (m[1] !== undefined) {
            runs.push({ text: m[1], strong: true });
        } else if (m[2] !== undefined) {
            runs.push({ text: m[2], em: true });
        } else if (m[3] !== undefined) {
            runs.push({ text: m[3], code: true });
        } else if (known[m[5]]) {
            runs.push({ text: m[4], ref: m[5] });
        } else {
            runs.push({ text: m[4] });
        }
        last = INLINE.lastIndex;
    }
    if (last < s.length) {
        runs.push({ text: s.slice(last) });
    }
    return runs;
}

/**
 * Text as blocks: each non-blank line is a paragraph ('p'), a '- ' line a bullet ('li'), a '1. ' line
 * a numbered item ('ol'). Blank lines only separate. refs is the card's refs list or a key map.
 */
export function parseRich(text, refs) {
    const known = Array.isArray(refs) ? refMap({ refs }) : refs || {};
    const blocks = [];
    str(text)
        .split('\n')
        .forEach((raw) => {
            const line = raw.replace(/\s+$/, '');
            if (!line.trim()) {
                return;
            }
            const b = BULLET.exec(line);
            const n = b ? null : NUMBERED.exec(line);
            if (b) {
                blocks.push({ kind: 'li', runs: parseInline(b[1], known) });
            } else if (n) {
                blocks.push({ kind: 'ol', runs: parseInline(n[2], known) });
            } else {
                blocks.push({ kind: 'p', runs: parseInline(line.trim(), known) });
            }
        });
    return blocks;
}

function runsText(runs) {
    return list(runs)
        .map((r) => str(r && r.text))
        .join('');
}

/** Blocks back to plain lines: markers dropped, links as their label, list items as '- ' or 'n. '. */
export function blocksText(blocks) {
    let n = 0;
    return list(blocks)
        .map((b) => {
            const t = runsText(b && b.runs);
            if (b && b.kind === 'li') {
                n = 0;
                return '- ' + t;
            }
            if (b && b.kind === 'ol') {
                n += 1;
                return n + '. ' + t;
            }
            n = 0;
            return t;
        })
        .join('\n');
}

function countLine(shown, total, noun) {
    if (total > shown) {
        return 'Showing ' + shown + ' of ' + total + ' ' + noun;
    }
    return shown + ' ' + (shown === 1 ? noun.replace(/s$/, '') : noun);
}

function joinLines(lines) {
    return lines.filter((l) => l !== null && l !== undefined && l !== '').join('\n');
}

function itemLine(i) {
    const parts = [str(i.label)];
    if (i.value) {
        parts[0] = parts[0] + ': ' + str(i.value);
    }
    if (i.detail) {
        parts.push(str(i.detail));
    }
    return parts.join(' — ');
}

function fieldLine(f) {
    let value = str(f.value);
    if (f.state === 'missing') {
        value = value || '(needed)';
    } else if (f.state === 'choose') {
        value = (value ? value + ' ' : '') + '(choose one)';
    }
    return str(f.label) + ': ' + value;
}

function gridText(card) {
    const columns = list(card.columns);
    const lines = [columns.map((c) => str(c.label)).join(' | ')];
    list(card.rows).forEach((r) => lines.push(list(r.cells).map(str).join(' | ')));
    return lines;
}

/** The plain-text rule per type. Never an Id: refs are left out, links read as their label. */
const TEXT_RULES = {
    text: (c) => joinLines([str(c.title), blocksText(c.body)]),
    summary: (c) => joinLines([str(c.title), blocksText(c.body)]),
    notice: (c) => joinLines([str(c.title), blocksText(c.body)]),
    error: (c) => joinLines([str(c.title), blocksText(c.body)]),
    section: (c) =>
        joinLines([
            str(c.title) + (c.total || c.shown ? ' (' + c.shown + ' of ' + c.total + ')' : ''),
            list(c.items).length ? list(c.items).map((i) => '- ' + itemLine(i)).join('\n') : blocksText(c.body)
        ]),
    table: (c) => {
        const lines = [str(c.title)].concat(gridText(c));
        if (c.total > c.shown) {
            lines.push('(' + c.shown + ' of ' + c.total + ' rows)');
        }
        return joinLines(lines);
    },
    comparison: (c) => joinLines([str(c.title)].concat(gridText(c))),
    record: (c) => joinLines([str(c.title) + (c.meta ? ' · ' + c.meta : '')].concat(list(c.fields).map(fieldLine))),
    recordList: (c) =>
        joinLines(
            [str(c.title)]
                .concat(list(c.items).map((i) => '- ' + itemLine(i)))
                .concat(c.total > c.shown ? ['(' + c.shown + ' of ' + c.total + ')'] : [])
        ),
    choice: (c) => joinLines([str(c.title)].concat(list(c.items).map((i, n) => n + 1 + '. ' + itemLine(i)))),
    metric: (c) => joinLines([str(c.title)].concat(list(c.items).map(itemLine))),
    timeline: (c) => joinLines([str(c.title)].concat(list(c.items).map((i) => str(i.at) + ' · ' + itemLine(i)))),
    followups: (c) => joinLines([str(c.title)].concat(list(c.items).map((i) => '- ' + str(i.label)))),
    trail: (c) => joinLines([str(c.title)].concat(list(c.items).map((i, n) => n + 1 + '. ' + itemLine(i)))),
    actionDraft: (c) =>
        joinLines(
            [str(c.title) + (c.meta ? ' · ' + c.meta : '')]
                .concat(list(c.fields).map(fieldLine))
                .concat(list(c.items).map((i) => 'Note: ' + itemLine(i)))
                .concat(list(c.controls).length ? ['Options: ' + list(c.controls).map((k) => str(k.label)).join(', ')] : [])
        ),
    actionResult: (c) =>
        joinLines([str(c.title) + (c.meta ? ' · ' + c.meta : '')].concat(list(c.fields).map(fieldLine)).concat([blocksText(c.body)]))
};

/** The fallback a card carries, computed by the rule for its type. Apex builds the same text. */
export function plainText(card) {
    const rule = card && TEXT_RULES[card.type];
    return rule ? rule(card) : str(card && card.text);
}

// ------------------------------------------------------------------ view models

function viewRuns(runs, refs, keyPrefix) {
    return list(runs).map((r, i) => {
        const ref = r.ref && refs[r.ref] ? refs[r.ref] : null;
        return {
            key: keyPrefix + 'r' + i,
            text: str(r.text),
            isStrong: !!r.strong,
            isEm: !!r.em,
            isCode: !!r.code,
            isLink: !!ref,
            isPlain: !r.strong && !r.em && !r.code && !ref,
            ref: ref ? ref.key : null,
            linkLabel: ref ? 'Open ' + str(ref.objectName || 'record') + ' ' + str(ref.label || r.text) : null
        };
    });
}

function viewBlocks(card, refs) {
    const blocks = list(card.body).map((b, i) => ({
        key: 'b' + i,
        kind: b.kind,
        runs: viewRuns(b.runs, refs, 'b' + i)
    }));
    // Consecutive list items become one <ul> or <ol>, so a screen reader hears a list and its size.
    const groups = [];
    blocks.forEach((b) => {
        const listKind = b.kind === 'li' || b.kind === 'ol' ? b.kind : null;
        const lastGroup = groups[groups.length - 1];
        if (listKind && lastGroup && lastGroup.listKind === listKind) {
            lastGroup.items.push(b);
        } else if (listKind) {
            groups.push({ key: 'g' + groups.length, listKind, isUl: listKind === 'li', isOl: listKind === 'ol', isP: false, items: [b] });
        } else {
            groups.push({ key: 'g' + groups.length, isUl: false, isOl: false, isP: true, runs: b.runs });
        }
    });
    return groups;
}

function refView(refs, key) {
    const ref = key && refs[key];
    return ref ? { ref: ref.key, linkLabel: 'Open ' + str(ref.objectName || 'record') + ' ' + str(ref.label) } : { ref: null, linkLabel: null };
}

function viewItems(card, refs) {
    return list(card.items).map((i, n) => ({
        key: 'i' + n,
        label: str(i.label),
        value: str(i.value),
        detail: str(i.detail),
        at: str(i.at),
        kind: str(i.kind),
        status: str(i.status),
        hasValue: !!i.value,
        hasDetail: !!i.detail,
        hasAt: !!i.at,
        isLink: !!(i.ref && refs[i.ref]),
        ...refView(refs, i.ref)
    }));
}

function viewFields(card, refs) {
    return list(card.fields).map((f, n) => {
        const choices = list(f.choices)
            .map((k) => refs[k])
            .filter(Boolean)
            .map((r) => ({ key: r.key, ref: r.key, label: str(r.label), fieldKey: str(f.key) }));
        return {
            key: 'f' + n,
            fieldKey: str(f.key),
            label: str(f.label),
            value: f.state === 'missing' && !f.value ? 'Needed' : str(f.value),
            // The value as the card carries it: what an editable draft field starts from (FE-14).
            raw: str(f.value),
            isMissing: f.state === 'missing',
            isChoose: f.state === 'choose',
            hasChoices: choices.length > 0,
            choices,
            isLink: !!(f.ref && refs[f.ref]),
            ddClass: f.state === 'missing' ? 'cs-dd cs-dd-missing' : 'cs-dd',
            ...refView(refs, f.ref)
        };
    });
}

function viewGrid(card, refs, density) {
    const columns = list(card.columns).map((c, n) => ({
        key: 'h' + n,
        label: str(c.label),
        isNumber: c.kind === 'number' || c.kind === 'currency' || c.kind === 'percent',
        thClass: c.kind === 'number' || c.kind === 'currency' || c.kind === 'percent' ? 'cs-th cs-num' : 'cs-th'
    }));
    const rows = list(card.rows).map((r, n) => {
        const link = refView(refs, r.ref);
        return {
            key: 'row' + n,
            ...link,
            cells: list(r.cells).map((v, j) => ({
                key: 'c' + j,
                value: str(v),
                label: columns[j] ? columns[j].label : '',
                isFirst: j === 0,
                isLinkCell: j === 0 && !!link.ref,
                tdClass: columns[j] && columns[j].isNumber ? 'cs-td cs-num' : 'cs-td'
            })),
            head: str(list(r.cells)[0]),
            rest: list(r.cells)
                .slice(1)
                .map((v, j) => ({ key: 's' + j, label: columns[j + 1] ? columns[j + 1].label : '', value: str(v) }))
        };
    });
    return {
        columns,
        rows,
        stacked: density === 'compact' && columns.length > (card.type === 'comparison' ? COMPACT_MAX_COMPARISON_COLUMNS : COMPACT_MAX_COLUMNS)
    };
}

function fold(view, entries, density) {
    const at = FOLD[density] || FOLD.comfortable;
    const all = entries.length;
    return { ...view, foldAt: at, canFold: all > at, hiddenCount: Math.max(0, all - at) };
}

function totals(card) {
    const total = Number(card.total) || 0;
    const shown = Number(card.shown) || 0;
    return { total, shown, hasTotal: total > 0 || shown > 0, partial: total > shown };
}

const BUILDERS = {
    prose: (card, refs) => ({ blocks: viewBlocks(card, refs) }),
    list: (card, refs, density) => {
        const items = viewItems(card, refs);
        return fold({ items, blocks: viewBlocks(card, refs) }, items, density);
    },
    fields: (card, refs) => ({
        fields: viewFields(card, refs),
        items: viewItems(card, refs),
        blocks: viewBlocks(card, refs),
        controls: list(card.controls).map((k) => ({
            key: str(k.key),
            label: str(k.label),
            btnClass: k.kind === 'primary' ? 'cs-btn cs-btn-primary' : k.kind === 'link' ? 'cs-btn cs-btn-link' : 'cs-btn'
        }))
    }),
    grid: (card, refs, density) => {
        const grid = viewGrid(card, refs, density);
        return fold(grid, grid.rows, density);
    },
    metric: (card) => ({
        items: list(card.items).map((i, n) => ({
            key: 'm' + n,
            label: str(i.label),
            value: str(i.value),
            detail: str(i.detail),
            hasDetail: !!i.detail,
            itemClass: n === 0 ? 'cs-metric cs-metric-hero' : 'cs-metric'
        }))
    }),
    chips: (card) => ({ items: list(card.items).map((i, n) => ({ key: 'p' + n, label: str(i.label) })) })
};

/**
 * The registry: each type's highest supported version and its family. Where the type is made is in
 * the page's catalog (summary, explorer, resolver, drill, BE-27, later).
 */
export const TYPES = {
    text: { version: 1, family: FAMILY.PROSE },
    summary: { version: 1, family: FAMILY.PROSE, folds: 'open' },
    notice: { version: 1, family: FAMILY.PROSE },
    error: { version: 1, family: FAMILY.PROSE },
    section: { version: 1, family: FAMILY.LIST, folds: 'closed' },
    recordList: { version: 1, family: FAMILY.LIST },
    choice: { version: 1, family: FAMILY.LIST },
    timeline: { version: 1, family: FAMILY.LIST },
    trail: { version: 1, family: FAMILY.LIST, folds: 'closed' },
    record: { version: 1, family: FAMILY.FIELDS },
    // Drawn only for a host that runs the write actions (viewOf's options.actions, FE-14): their text shows elsewhere.
    actionDraft: { version: 1, family: FAMILY.FIELDS, ready: false },
    actionResult: { version: 1, family: FAMILY.FIELDS, ready: false },
    table: { version: 1, family: FAMILY.GRID },
    comparison: { version: 1, family: FAMILY.GRID },
    metric: { version: 1, family: FAMILY.METRIC },
    followups: { version: 1, family: FAMILY.CHIPS }
};

function fallbackView(card, reason) {
    const text = str(card && card.text) || plainText(card);
    return {
        family: FAMILY.FALLBACK,
        isFallback: true,
        reason,
        type: str(card && card.type),
        title: '',
        lines: text.split('\n').map((t, i) => ({ key: 'l' + i, text: t }))
    };
}

/**
 * The view a renderer binds. An unknown type, a version above the registry's, a type not drawn here
 * or a builder that throws all give the fallback view: the card's own plain text. options.actions
 * draws a ready: false type (the action types); the version check and the fallback still apply.
 */
export function viewOf(card, density, options) {
    const d = density === 'compact' ? 'compact' : 'comfortable';
    if (!card || typeof card !== 'object') {
        return fallbackView({}, 'empty');
    }
    const entry = TYPES[card.type];
    if (!entry) {
        return fallbackView(card, 'unknown-type');
    }
    if (!(Number(card.version) >= 1) || Number(card.version) > entry.version) {
        return fallbackView(card, 'unknown-version');
    }
    if (entry.ready === false && !(options && options.actions)) {
        return fallbackView(card, 'not-ready');
    }
    try {
        const refs = refMap(card);
        const body = BUILDERS[entry.family](card, refs, d);
        const status = str(card.status);
        return {
            ...body,
            ...totals(card),
            family: entry.family,
            isFallback: false,
            type: card.type,
            key: str(card.key),
            title: str(card.title),
            meta: str(card.meta),
            status,
            hasStatus: !!status && status !== 'OK',
            isError: card.type === 'error' || status === 'ERROR' || status === 'REFUSED',
            folds: !!entry.folds,
            openByDefault: entry.folds !== 'closed',
            isChoice: card.type === 'choice',
            countText: card.type === 'table' || card.type === 'recordList' ? countLine(Number(card.shown) || 0, Number(card.total) || 0, card.type === 'table' ? 'rows' : 'records') : '',
            refs
        };
    } catch (e) {
        return fallbackView(card, 'render-error');
    }
}

/** For the tests and the page: a card is valid when its type is known and its text is its rule's text. */
export function checkCard(card) {
    const problems = [];
    if (!card || !TYPES[card.type]) {
        problems.push('unknown type');
        return problems;
    }
    if (card.version !== TYPES[card.type].version) {
        problems.push('version');
    }
    if (typeof card.text !== 'string' || !card.text) {
        problems.push('no text');
    } else if (card.text !== plainText(card)) {
        problems.push('text differs from its rule');
    }
    list(card.refs).forEach((r) => {
        if (r.recordId && card.text.indexOf(r.recordId) >= 0) {
            problems.push('text holds a record id');
        }
    });
    if (/<[a-z!/]/i.test(JSON.stringify(card))) {
        problems.push('markup');
    }
    return problems;
}

export const DENSITY = Object.keys(FOLD);
