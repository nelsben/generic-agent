/**
 * OPS-29 throwaway spike (FR2 surfaces). Not product code: nothing in force-app refers to it.
 *
 * role="overlay" (the utility item): a document keydown listener for both hotkeys, a launcher fixed to a
 * bottom corner, a compact window (Cmd/Ctrl-K), and a right rail (Cmd/Ctrl-Shift-K) that can slide over
 * with a backdrop, hover-peek, minimize to a strip, or try to push the page left. Also the mic probe.
 * role="probe" (an app page region or the background region): the same listener, logging only.
 *
 * Everything it observes is written to data-state on the [data-spike-state] element as JSON, so a
 * Playwright run can read it. It never preventDefaults in probe mode.
 */
import { LightningElement, api } from 'lwc';

const RAIL_WIDTH = 480;

function isMac() {
    const nav = window.navigator || {};
    const platform = (nav.userAgentData && nav.userAgentData.platform) || nav.platform || '';
    return /mac|iphone|ipad/i.test(platform);
}

/** 'compact' for Cmd/Ctrl-K, 'rail' for Cmd/Ctrl-Shift-K, else null. By physical key; no Alt. */
function hotkeyOf(event) {
    if (event.code !== 'KeyK' || event.altKey) {
        return null;
    }
    const mod = isMac() ? event.metaKey && !event.ctrlKey : event.ctrlKey && !event.metaKey;
    if (!mod) {
        return null;
    }
    return event.shiftKey ? 'rail' : 'compact';
}

export default class SurfaceSpike extends LightningElement {
    /** overlay | probe */
    @api role = 'overlay';
    /** right | left: the launcher's and the compact window's corner. */
    @api corner = 'right';
    /**
     * component: draw the overlays in this component's own template (inside the utility panel).
     * body: build them with DOM calls and append them to document.body, outside the utility panel.
     */
    @api mount = 'component';

    compactOpen = false;
    rail = 'closed'; // closed | sheet | hover | min
    pushed = false;
    state = {
        role: '',
        mac: false,
        compact: 0,
        rail: 0,
        prevented: 0,
        lastKey: '',
        fixed: null,
        push: null,
        mic: null,
        portal: null
    };

    _onKey;

    get isOverlay() {
        return this.role !== 'probe';
    }

    get inTemplate() {
        return this.isOverlay && this.mount !== 'body';
    }

    get keyHint() {
        return this.state.mac ? '⌘K' : 'Ctrl K';
    }

    get railHint() {
        return this.state.mac ? '⌘⇧K' : 'Ctrl Shift K';
    }

    get launcherLabel() {
        return 'Ask Customer Summary ' + this.keyHint;
    }

    get launcherClass() {
        return 'spike-launcher spike-' + (this.corner === 'left' ? 'left' : 'right') + (this.compactOpen ? ' spike-gone' : '');
    }

    get compactClass() {
        return 'spike-compact spike-' + (this.corner === 'left' ? 'left' : 'right');
    }

    get railOpen() {
        return this.rail !== 'closed';
    }

    get railClass() {
        return 'spike-rail spike-rail_' + this.rail;
    }

    get showBackdrop() {
        return this.rail === 'sheet' && !this.pushed;
    }

    get railTitle() {
        return 'Customer Summary rail (' + this.rail + (this.pushed ? ', pushing' : '') + ')';
    }

    get stateJson() {
        return JSON.stringify(this.state);
    }

    get micSupport() {
        const m = this.state.mic;
        return m ? 'SpeechRecognition: ' + m.standard + ', webkitSpeechRecognition: ' + m.webkit : '';
    }

    connectedCallback() {
        this._set({ role: this.role, mac: isMac(), mic: this._micSupport() });
        this._onKey = (event) => this._handleKey(event);
        document.addEventListener('keydown', this._onKey);
        if (this.isOverlay && this.mount === 'body') {
            this._portalBuild();
        }
    }

    disconnectedCallback() {
        document.removeEventListener('keydown', this._onKey);
        if (this._portal && this._portal.root.parentNode) {
            this._portal.root.parentNode.removeChild(this._portal.root);
        }
        this._stopMic();
        if (this.pushed) {
            this._applyPush(false);
        }
    }

    renderedCallback() {
        if (this.state.fixed || !this.inTemplate) {
            return;
        }
        const launcher = this.template.querySelector('.spike-launcher');
        if (launcher) {
            const r = launcher.getBoundingClientRect();
            // Where the fixed launcher really sits in the viewport, and whether it is visible at all.
            this._set({
                fixed: {
                    position: getComputedStyle(launcher).position,
                    left: Math.round(r.left),
                    right: Math.round(r.right),
                    top: Math.round(r.top),
                    bottom: Math.round(r.bottom),
                    width: Math.round(r.width),
                    viewportWidth: window.innerWidth,
                    viewportHeight: window.innerHeight
                }
            });
        }
    }

    _set(patch) {
        this.state = { ...this.state, ...patch };
    }

    _handleKey(event) {
        const which = hotkeyOf(event);
        if (!which) {
            if (event.key === 'Escape' && this.isOverlay && (this.compactOpen || this.railOpen)) {
                this.compactOpen = false;
                this.rail = 'closed';
                this._portalSync();
            }
            return;
        }
        const prevented = event.defaultPrevented ? 1 : 0;
        this._set({
            [which]: this.state[which] + 1,
            prevented: this.state.prevented + prevented,
            lastKey: which + (event.metaKey ? ' meta' : '') + (event.ctrlKey ? ' ctrl' : '') + (event.shiftKey ? ' shift' : '')
        });
        if (!this.isOverlay || prevented) {
            return;
        }
        event.preventDefault();
        if (which === 'compact') {
            this.compactOpen = !this.compactOpen;
        } else {
            this.rail = this.rail === 'sheet' ? 'closed' : 'sheet';
        }
        this._portalSync();
    }

    // ------------------------------------------------------------ body-mounted overlays (the portal)

    _portalBuild() {
        const result = {};
        try {
            const el = (tag, css, text) => {
                const n = document.createElement(tag);
                n.style.cssText = css;
                if (text) {
                    n.textContent = text;
                }
                return n;
            };
            const side = this.corner === 'left' ? 'left:16px;' : 'right:16px;';
            const card = 'background:#fff;color:#181818;border:1px solid #c9c9c9;font-family:inherit;';
            const btn = 'margin-right:6px;padding:4px 10px;border:1px solid #c9c9c9;border-radius:4px;background:#fff;color:#0b5cab;cursor:pointer;';
            const root = el('div', 'position:fixed;top:0;left:0;width:0;height:0;z-index:9000;');
            root.setAttribute('data-spike-portal', '');

            const launcher = el(
                'button',
                'position:fixed;bottom:48px;' + side + card +
                    'display:inline-flex;align-items:center;gap:8px;padding:8px 14px;border-radius:999px;' +
                    'box-shadow:0 4px 14px rgba(0,0,0,.16);font-size:13px;cursor:pointer;' +
                    'transition:transform 180ms cubic-bezier(0.25,0.46,0.45,0.94),opacity 180ms;'
            );
            launcher.setAttribute('data-portal', 'launcher');
            launcher.setAttribute('aria-label', this.launcherLabel);
            launcher.appendChild(el('span', '', 'Ask Customer Summary'));
            launcher.appendChild(
                el('kbd', 'padding:1px 6px;border:1px solid #c9c9c9;border-radius:4px;background:#eef4fb;color:#0b5cab;font:12px ui-monospace,Menlo,monospace;', this.keyHint)
            );
            launcher.addEventListener('click', () => {
                this.compactOpen = true;
                this._portalSync();
            });

            const compact = el(
                'section',
                'position:fixed;bottom:48px;' + side + card + 'display:none;width:420px;height:480px;border-radius:12px;box-shadow:0 12px 32px rgba(0,0,0,.22);overflow:hidden;'
            );
            compact.setAttribute('data-portal', 'compact');
            compact.setAttribute('role', 'dialog');
            compact.setAttribute('aria-label', 'Customer Summary compact window');
            const ch = el('div', 'display:flex;align-items:center;gap:8px;padding:12px 16px;border-bottom:1px solid #c9c9c9;');
            ch.appendChild(el('strong', 'flex:1;', 'Customer Summary'));
            const expand = el('button', btn, 'Expand');
            expand.addEventListener('click', () => {
                this.compactOpen = false;
                this.rail = 'sheet';
                this._portalSync();
            });
            const closeC = el('button', btn, 'Close');
            closeC.addEventListener('click', () => {
                this.compactOpen = false;
                this._portalSync();
            });
            ch.appendChild(expand);
            ch.appendChild(closeC);
            compact.appendChild(ch);
            compact.appendChild(el('p', 'padding:16px;margin:0;', 'Compact window, 420 px, mounted on the page body. Opened by ' + this.keyHint + ' or the launcher.'));

            const backdrop = el('div', 'position:fixed;top:0;right:0;bottom:0;left:0;display:none;background:rgba(8,7,7,.35);');
            backdrop.setAttribute('data-portal', 'backdrop');
            backdrop.addEventListener('click', () => {
                this.rail = 'closed';
                this._portalSync();
            });

            const rail = el(
                'aside',
                'position:fixed;top:0;right:0;bottom:0;display:none;width:480px;transition:transform 280ms cubic-bezier(0.32,0.72,0,1);'
            );
            rail.setAttribute('data-portal', 'rail');
            rail.setAttribute('aria-label', 'Customer Summary rail');
            const strip = el(
                'div',
                card + 'display:none;width:28px;align-items:center;justify-content:center;border-right:0;border-radius:8px 0 0 8px;cursor:pointer;writing-mode:vertical-rl;font-size:12px;font-weight:700;',
                'Customer Summary'
            );
            strip.setAttribute('data-portal', 'strip');
            strip.addEventListener('mouseenter', () => {
                if (this.rail === 'min') {
                    this.rail = 'hover';
                    this._portalSync();
                }
            });
            strip.addEventListener('click', () => {
                this.rail = 'sheet';
                this._portalSync();
            });
            rail.addEventListener('mouseleave', () => {
                if (this.rail === 'hover') {
                    this.rail = 'min';
                    this._portalSync();
                }
            });
            const inner = el('div', card + 'flex:1;min-width:0;border-width:0 0 0 1px;box-shadow:-8px 0 24px rgba(0,0,0,.18);');
            const title = el('div', 'padding:12px 16px;border-bottom:1px solid #c9c9c9;font-weight:700;', 'Customer Summary rail');
            const actions = el('div', 'padding:12px 16px 0;');
            const push = el('button', btn, 'Push page');
            push.setAttribute('data-portal', 'push');
            push.addEventListener('click', () => {
                this._applyPush(!this.pushed);
                this._portalSync();
            });
            const min = el('button', btn, 'Minimize');
            min.setAttribute('data-portal', 'minimize');
            min.addEventListener('click', () => {
                this.handleMinimize();
                this._portalSync();
            });
            const closeR = el('button', btn, 'Close');
            closeR.addEventListener('click', () => {
                this.handleCloseRail();
                this._portalSync();
            });
            actions.appendChild(push);
            actions.appendChild(min);
            actions.appendChild(closeR);
            inner.appendChild(title);
            inner.appendChild(actions);
            inner.appendChild(
                el('p', 'padding:16px;margin:0;', 'Right rail, 480 px, mounted on the page body. Opened by ' + this.railHint + ', Expand, or a hover on the minimized strip.')
            );
            rail.appendChild(strip);
            rail.appendChild(inner);

            root.appendChild(backdrop);
            root.appendChild(rail);
            root.appendChild(compact);
            root.appendChild(launcher);
            document.body.appendChild(root);
            this._portal = { root, launcher, compact, backdrop, rail, strip, title };
            const r = launcher.getBoundingClientRect();
            result.ok = true;
            result.inBody = root.parentNode === document.body;
            result.launcher = { left: Math.round(r.left), right: Math.round(r.right), top: Math.round(r.top), bottom: Math.round(r.bottom) };
        } catch (e) {
            result.ok = false;
            result.error = String(e && e.message ? e.message : e).slice(0, 160);
        }
        this._set({ portal: result });
    }

    _portalSync() {
        const p = this._portal;
        if (!p) {
            return;
        }
        p.launcher.style.transform = this.compactOpen ? 'scale(0.6)' : '';
        p.launcher.style.opacity = this.compactOpen ? '0' : '1';
        p.launcher.style.pointerEvents = this.compactOpen ? 'none' : 'auto';
        p.compact.style.display = this.compactOpen ? 'block' : 'none';
        const open = this.rail !== 'closed';
        p.rail.style.display = open ? 'flex' : 'none';
        p.backdrop.style.display = this.rail === 'sheet' && !this.pushed ? 'block' : 'none';
        const min = this.rail === 'min';
        p.strip.style.display = min || this.rail === 'hover' ? 'flex' : 'none';
        p.rail.style.transform = min ? 'translateX(452px)' : '';
        p.rail.style.top = min ? '30%' : '0';
        p.rail.style.bottom = min ? '30%' : '0';
        p.title.textContent = 'Customer Summary rail (' + this.rail + (this.pushed ? ', pushing the page' : '') + ')';
        p.rail.setAttribute('data-rail', this.rail);
    }

    // ------------------------------------------------------------ launcher, compact, rail

    handleLauncher() {
        this.compactOpen = true;
    }

    handleCloseCompact() {
        this.compactOpen = false;
    }

    handleExpand() {
        this.compactOpen = false;
        this.rail = 'sheet';
    }

    handleBackdrop() {
        this.rail = 'closed';
    }

    handleMinimize() {
        if (this.pushed) {
            this._applyPush(false);
        }
        this.rail = 'min';
    }

    handleCloseRail() {
        if (this.pushed) {
            this._applyPush(false);
        }
        this.rail = 'closed';
    }

    handleStripEnter() {
        if (this.rail === 'min') {
            this.rail = 'hover';
        }
    }

    handleRailLeave() {
        if (this.rail === 'hover') {
            this.rail = 'min';
        }
    }

    handleStripClick() {
        this.rail = 'sheet';
    }

    handleTogglePush() {
        this._applyPush(!this.pushed);
    }

    /**
     * The undocumented push: shrink Lightning's own layout containers from the right. Records what
     * LWS let the component reach and whether the page content's right edge moved.
     */
    _applyPush(on) {
        const result = { tried: on ? 'push' : 'unpush', targets: [] };
        ['.viewport', '.oneCenterStage'].forEach((sel) => {
            const entry = { selector: sel };
            try {
                const el = document.querySelector(sel);
                entry.found = !!el;
                if (el) {
                    const before = el.getBoundingClientRect().right;
                    el.style.right = on ? RAIL_WIDTH + 'px' : '';
                    const after = el.getBoundingClientRect().right;
                    entry.rightBefore = Math.round(before);
                    entry.rightAfter = Math.round(after);
                }
            } catch (e) {
                entry.error = String(e && e.message ? e.message : e).slice(0, 120);
            }
            result.targets.push(entry);
        });
        this.pushed = on && result.targets.some((t) => t.rightAfter !== undefined && t.rightAfter < t.rightBefore);
        this._set({ push: result });
    }

    // ------------------------------------------------------------ mic

    _micSupport() {
        return {
            standard: typeof window.SpeechRecognition,
            webkit: typeof window.webkitSpeechRecognition,
            mediaDevices: typeof (window.navigator && window.navigator.mediaDevices),
            events: []
        };
    }

    _micEvent(name, extra) {
        const mic = this.state.mic || this._micSupport();
        this._set({ mic: { ...mic, events: [...mic.events, { name, ...(extra || {}) }] } });
    }

    handleMic() {
        const Ctor = window.SpeechRecognition || window.webkitSpeechRecognition;
        if (!Ctor) {
            this._micEvent('unavailable');
            return;
        }
        try {
            const rec = new Ctor();
            rec.continuous = true;
            rec.interimResults = true;
            rec.lang = 'en-US';
            ['start', 'audiostart', 'soundstart', 'speechstart', 'speechend', 'audioend', 'end', 'nomatch'].forEach((n) => {
                rec['on' + n] = () => this._micEvent(n);
            });
            rec.onerror = (e) => this._micEvent('error', { error: e && e.error });
            rec.onresult = (e) => {
                let text = '';
                for (let i = 0; i < e.results.length; i += 1) {
                    text += e.results[i][0].transcript;
                }
                this._micEvent('result', { chars: text.length });
            };
            this._rec = rec;
            rec.start();
            this._micEvent('start-called');
        } catch (e) {
            this._micEvent('throw', { message: String(e && e.message ? e.message : e).slice(0, 120) });
        }
    }

    _stopMic() {
        if (this._rec) {
            try {
                this._rec.abort();
            } catch (e) {
                // already stopped
            }
            this._rec = null;
        }
    }
}
