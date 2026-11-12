// @ts-check
/**
 * Privacy for every captured frame (see "Capture" in e2e/README.md).
 *
 * The running user's name, username, email and nickname are read from the sf CLI at run time and
 * kept in memory only: never printed, logged, put in an error message or written to disk.
 *
 * pageGuard() runs in the page (as a context init script, so from the first document of every
 * frame). It
 * - injects CSS that hides the global header's avatar button and any user photo;
 * - on every animation frame, before paint, rewrites text and visible attributes in the document
 *   and in every shadow root (native ones are tracked by wrapping attachShadow): the user's name
 *   and other identity strings become "Sample Owner", email addresses "email hidden", and 15 or
 *   18 character record Ids "Id hidden"; user photos are hidden inline;
 * - exposes window.__abpCapture.check(), which walks the same trees and returns the categories of
 *   forbidden text still visible (never the text itself).
 */
const { spawnSync } = require('child_process');
const { SF, ORG } = require('../support/env');

/**
 * Runs sf with --json and returns the parsed object, or null; output is captured, never echoed.
 * Playwright workers set FORCE_COLOR, which makes sf colour its JSON, so colour is turned off.
 */
function sf(args) {
    const env = { ...process.env, SF_AUTOUPDATE_DISABLE: 'true', SF_DISABLE_TELEMETRY: 'true', NO_COLOR: '1' };
    delete env.FORCE_COLOR;
    const r = spawnSync(SF, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], env, timeout: 120_000 });
    try {
        return JSON.parse(r.stdout || '');
    } catch (e) {
        return null;
    }
}

/** One-line error with no stack, so Playwright prints the message alone. */
function oneLine(message) {
    const e = new Error(message);
    e.stack = message;
    return e;
}

/**
 * The running user's identity strings, from `sf org display user` (Id, username) and one User
 * query for the name (display user has no name field). Returned, never printed.
 */
function identity() {
    const shown = sf(['org', 'display', 'user', '--target-org', ORG, '--json']);
    const user = shown && shown.status === 0 && shown.result;
    if (!user || !user.id || !user.username) {
        throw oneLine(`Could not read the running user of org "${ORG}" with sf org display user.`);
    }
    if (!/^005[0-9A-Za-z]{12}([0-9A-Za-z]{3})?$/.test(user.id)) {
        throw oneLine('sf org display user returned an unexpected user Id shape.');
    }
    const soql = `SELECT Name, Email, CommunityNickname FROM User WHERE Id = '${user.id}'`;
    const q = sf(['data', 'query', '--query', soql, '--json', '-o', ORG]);
    const row = q && q.status === 0 && q.result && q.result.records && q.result.records[0];
    if (!row || !row.Name) {
        throw oneLine(`Could not read the running user's name in org "${ORG}".`);
    }
    return {
        name: String(row.Name),
        // Exact strings replaced with "Sample Owner" wherever they appear.
        strings: [row.Name, user.username, row.Email, row.CommunityNickname].filter((s) => typeof s === 'string' && s.trim().length >= 3)
    };
}

/**
 * Runs in the browser. Must be self-contained: Playwright serialises it.
 * @param {{ strings: string[], name: string }} arg
 */
function pageGuard(arg) {
    const w = /** @type {any} */ (window);
    if (w.__abpCapture) {
        return;
    }
    const REPLACEMENT = 'Sample Owner';
    const strings = (arg.strings || []).slice().sort((a, b) => b.length - a.length);
    const lowered = strings.map((s) => s.toLowerCase());
    const EMAIL = /[A-Za-z0-9._%+'-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}/g;
    // Exactly 15 or 18 letters and digits, at least one a digit, not part of a longer run.
    const ID = /(?<![A-Za-z0-9])(?=[A-Za-z]*[0-9])(?:[A-Za-z0-9]{18}|[A-Za-z0-9]{15})(?![A-Za-z0-9])/g;
    const ATTRS = ['title', 'aria-label', 'alt', 'placeholder', 'data-tooltip'];
    // The global header's avatar button and any user photo (user avatars are the round ones;
    // record-type icons are square).
    const PHOTO =
        '.branding-userProfile-button, .branding-user-profile, .slds-global-actions__avatar, .forceSocialPhoto,' +
        ' .slds-avatar--circle, .slds-avatar_circle, img[src*="profilephoto"], img[src*="/userphoto"]';
    const CSS = PHOTO + ' { visibility: hidden !important; }';

    function clean(text) {
        let out = text;
        const low = out.toLowerCase();
        for (let i = 0; i < strings.length; i += 1) {
            if (low.indexOf(lowered[i]) >= 0) {
                out = out.split(new RegExp(strings[i].replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi')).join(REPLACEMENT);
            }
        }
        if (out.indexOf('@') >= 0) {
            out = out.replace(EMAIL, 'email hidden');
        }
        out = out.replace(ID, 'Id hidden');
        return out;
    }

    const roots = new Set();
    const origAttach = Element.prototype.attachShadow;
    Element.prototype.attachShadow = function (init) {
        const root = origAttach.call(this, init);
        roots.add(root);
        return root;
    };

    const seen = new WeakMap();

    function walk(root, visit) {
        const tw = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT);
        let node = tw.currentNode;
        while (node) {
            visit(node);
            if (node.nodeType === 1) {
                const sr = /** @type {Element} */ (node).shadowRoot;
                if (sr && !roots.has(sr)) {
                    roots.add(sr);
                }
            }
            node = tw.nextNode();
        }
    }

    function allRoots() {
        const list = [document];
        roots.forEach((r) => {
            if (r.host && r.host.isConnected) {
                list.push(r);
            }
        });
        return list;
    }

    function sanitizeNode(node) {
        if (node.nodeType === 3) {
            const data = node.data;
            if (seen.get(node) === data) {
                return;
            }
            const fixed = clean(data);
            if (fixed !== data) {
                node.data = fixed;
            }
            seen.set(node, fixed);
            return;
        }
        if (node.nodeType === 1) {
            // User photos live in shadow roots too, where page CSS cannot reach: hide them inline.
            if (node.matches(PHOTO) && node.style.visibility !== 'hidden') {
                node.style.setProperty('visibility', 'hidden', 'important');
            }
            for (let i = 0; i < ATTRS.length; i += 1) {
                const v = node.getAttribute(ATTRS[i]);
                if (v) {
                    const fixed = clean(v);
                    if (fixed !== v) {
                        node.setAttribute(ATTRS[i], fixed);
                    }
                }
            }
        }
    }

    function ensureStyle() {
        if (document.getElementById('abp-capture-style')) {
            return;
        }
        const parent = document.head || document.documentElement;
        if (!parent) {
            return;
        }
        const style = document.createElement('style');
        style.id = 'abp-capture-style';
        style.textContent = CSS;
        parent.appendChild(style);
    }

    function sanitize() {
        ensureStyle();
        // The walk discovers shadow roots as it goes; walk until no new ones appear.
        const done = new Set();
        let pending = allRoots();
        while (pending.length) {
            pending.forEach((r) => {
                done.add(r);
                walk(r, sanitizeNode);
            });
            pending = allRoots().filter((r) => !done.has(r));
        }
    }

    function visible(el) {
        if (!el) {
            return false;
        }
        if (typeof el.checkVisibility === 'function') {
            return el.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true });
        }
        return true;
    }

    /** Categories of forbidden text still visible; the matched text itself is never returned. */
    function check() {
        sanitize();
        const parts = [];
        const done = new Set();
        let pending = allRoots();
        while (pending.length) {
            pending.forEach((r) => {
                done.add(r);
                walk(r, (node) => {
                    if (node.nodeType === 3) {
                        if (node.data.trim() && visible(node.parentElement)) {
                            parts.push(node.data);
                        }
                    } else if (node.nodeType === 1 && (node.tagName === 'INPUT' || node.tagName === 'TEXTAREA')) {
                        if (node.value && visible(node)) {
                            parts.push(node.value);
                        }
                    }
                });
            });
            pending = allRoots().filter((r) => !done.has(r));
        }
        const text = parts.join('\n');
        const low = text.toLowerCase();
        const found = [];
        if (lowered.some((s) => low.indexOf(s) >= 0) || low.indexOf(String(arg.name).toLowerCase()) >= 0) {
            found.push('running-user identity');
        }
        if (new RegExp(EMAIL.source).test(text)) {
            found.push('email address');
        }
        if (new RegExp(ID.source).test(text)) {
            found.push('15/18 character Id');
        }
        if (text.indexOf('URL_Redacted') >= 0) {
            found.push('URL_Redacted');
        }
        return { found, chars: text.length };
    }

    function frame() {
        try {
            sanitize();
        } catch (e) {
            // Keep going: the next frame tries again, and check() reports what is left.
        }
        requestAnimationFrame(frame);
    }

    /** Visible loading spinners anywhere on the page, the panel's own included. */
    function busy() {
        let n = 0;
        allRoots().forEach((r) => {
            walk(r, (node) => {
                if (node.nodeType === 1 && (node.tagName === 'LIGHTNING-SPINNER' || node.classList.contains('slds-spinner')) && visible(node)) {
                    n += 1;
                }
            });
        });
        return n;
    }

    w.__abpCapture = { sanitize, check, busy };
    requestAnimationFrame(frame);
}

module.exports = { identity, pageGuard, oneLine };
