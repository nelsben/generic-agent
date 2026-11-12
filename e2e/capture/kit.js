// @ts-check
/**
 * Shared pieces of the capture run (playwright.capture.config.js): the test fixture with the
 * privacy guard installed, the still and GIF writers and the 0.5 s recording check.
 *
 * Every asset lands in docs/assets/. Raw videos stay under test-results/capture/ (gitignored);
 * GIF frames for review go to a temporary folder outside the repo.
 */
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const { test: base, expect } = require('@playwright/test');
const { Panel } = require('../support/panel');
const { identity, pageGuard, oneLine } = require('./privacy');

const ASSETS = path.join(__dirname, '..', '..', 'docs', 'assets');
const RAW_DIR = path.join(__dirname, '..', '..', 'test-results', 'capture', 'raw');
// Review frames: outside the repo. CAPTURE_FRAMES_DIR overrides the default.
const FRAMES_DIR = process.env.CAPTURE_FRAMES_DIR || path.join(os.tmpdir(), 'abp-capture-frames');
const FFMPEG = '/opt/homebrew/bin/ffmpeg';
const FFPROBE = '/opt/homebrew/bin/ffprobe';
const GIF_FPS = 12;
const GIF_MAX_WIDTH = 900;
const GIF_MAX_BYTES = 6 * 1024 * 1024;
const STILL_MAX_WIDTH = 1600;

/** The area every panel still and GIF is cropped to, in CSS px: the panel and the record header. */
const PANEL_CROP = { x: 0, y: 150, width: 760, height: 750 };

let ident = null;
function who() {
    if (!ident) {
        ident = identity();
    }
    return ident;
}

/**
 * Runs the page's check() and throws a one-line error naming the asset and the category only.
 * @param {import('@playwright/test').Page} page
 */
async function assertClean(page, what) {
    const r = await page.evaluate(() => /** @type {any} */ (window).__abpCapture.check());
    if (r.found.length) {
        throw oneLine(`Privacy check failed for ${what}: ${r.found.join(', ')} in view.`);
    }
    if (!r.chars) {
        throw oneLine(`Privacy check for ${what} saw no text: the guard is not reading the page.`);
    }
}

/**
 * Checks the page every 0.5 s while it is recorded. stop() waits for the loop and throws if any
 * check found forbidden text, or if no check could run at all.
 * @param {import('@playwright/test').Page} page
 */
function watch(page, what) {
    let running = true;
    let failure = null;
    let checks = 0;
    const loop = (async () => {
        while (running && !page.isClosed()) {
            const started = Date.now();
            try {
                const r = await page.evaluate(() => {
                    const g = /** @type {any} */ (window).__abpCapture;
                    return g ? g.check() : null;
                });
                if (r) {
                    checks += 1;
                    if (r.found.length && !failure) {
                        failure = r.found.join(', ');
                    }
                }
            } catch (e) {
                // A navigation replaced the document mid-check: the next tick checks the new one.
            }
            await new Promise((res) => setTimeout(res, Math.max(0, 500 - (Date.now() - started))));
        }
    })();
    return {
        async stop() {
            running = false;
            await loop;
            if (failure) {
                throw oneLine(`Privacy check failed during the recording for ${what}: ${failure} in view.`);
            }
            if (checks === 0) {
                throw oneLine(`No privacy check ran during the recording for ${what}.`);
            }
            return checks;
        }
    };
}

/** PNG width and height from the IHDR chunk. */
function pngSize(file) {
    const b = fs.readFileSync(file);
    return { width: b.readUInt32BE(16), height: b.readUInt32BE(20) };
}

/**
 * A still of the clip (CSS px) at deviceScaleFactor 2, after the privacy check.
 * @param {import('@playwright/test').Page} page
 */
async function still(page, name, clip = PANEL_CROP, options = {}) {
    await settle(page, 500);
    await page.evaluate(() => /** @type {any} */ (window).__abpCapture.sanitize());
    await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
    await assertClean(page, name);
    const file = path.join(ASSETS, name);
    await page.screenshot({ path: file, clip, animations: 'disabled', caret: 'hide', ...options });
    const size = pngSize(file);
    if (size.width > STILL_MAX_WIDTH) {
        throw oneLine(`${name} is ${size.width} px wide; the limit is ${STILL_MAX_WIDTH}.`);
    }
    return size;
}

function run(cmd, args) {
    const r = spawnSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 240_000 });
    if (r.status !== 0) {
        const tail = (r.stderr || '').split('\n').filter(Boolean).slice(-3).join(' | ');
        throw oneLine(`${path.basename(cmd)} failed: ${tail}`);
    }
    return r.stdout;
}

function probe(file) {
    const out = run(FFPROBE, ['-v', 'error', '-show_entries', 'format=duration:stream=width,height', '-of', 'json', file]);
    const j = JSON.parse(out);
    return { duration: Number(j.format.duration), width: j.streams[0].width, height: j.streams[0].height };
}

/**
 * Turns a recorded video into docs/assets/<name> with a two-pass palette.
 * segments: [[start, end], ...] in seconds of the video; more than one are joined in order.
 * crop: CSS px; the video is recorded at the viewport's CSS size, so they map 1:1.
 * Then checks width, fps, duration and size, and writes one frame per second for review.
 */
function gif(rawVideo, name, segments, crop = PANEL_CROP) {
    const out = path.join(ASSETS, name);
    const palette = path.join(RAW_DIR, name + '.palette.png');
    const width = Math.min(crop.width, GIF_MAX_WIDTH);
    const parts = segments.map(
        ([a, b], i) => `[0:v]trim=start=${a.toFixed(2)}:end=${b.toFixed(2)},setpts=PTS-STARTPTS[s${i}]`
    );
    const joined = segments.map((_, i) => `[s${i}]`).join('') + `concat=n=${segments.length}:v=1:a=0[c]`;
    const body =
        `[c]fps=${GIF_FPS},crop=${crop.width}:${crop.height}:${crop.x}:${crop.y},` + `scale=${width}:-1:flags=lanczos`;
    const graph1 = [...parts, joined, body + ',palettegen=stats_mode=diff[p]'].join(';');
    const graph2 = [...parts, joined, body + '[v]', '[v][1:v]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle[o]'].join(';');
    run(FFMPEG, ['-y', '-v', 'error', '-i', rawVideo, '-filter_complex', graph1, '-map', '[p]', '-frames:v', '1', '-update', '1', palette]);
    run(FFMPEG, ['-y', '-v', 'error', '-i', rawVideo, '-i', palette, '-filter_complex', graph2, '-map', '[o]', '-loop', '0', out]);
    fs.rmSync(palette, { force: true });

    const info = probe(out);
    const bytes = fs.statSync(out).size;
    if (info.width > GIF_MAX_WIDTH) {
        throw oneLine(`${name} is ${info.width} px wide; the limit is ${GIF_MAX_WIDTH}.`);
    }
    if (bytes >= GIF_MAX_BYTES) {
        throw oneLine(`${name} is ${bytes} bytes; the limit is under 6 MB.`);
    }
    if (!(info.duration >= 6 && info.duration <= 20)) {
        throw oneLine(`${name} runs ${info.duration.toFixed(1)} s; it must run 6 to 20 s.`);
    }
    // One frame per second, outside the repo, for review by eye.
    const frames = path.join(FRAMES_DIR, name.replace(/\.gif$/, ''));
    fs.rmSync(frames, { recursive: true, force: true });
    fs.mkdirSync(frames, { recursive: true });
    run(FFMPEG, ['-y', '-v', 'error', '-i', out, '-vf', 'fps=1', path.join(frames, 'f%02d.png')]);
    run(FFMPEG, ['-y', '-v', 'error', '-sseof', '-0.2', '-i', out, '-frames:v', '1', '-update', '1', path.join(frames, 'last.png')]);
    return { ...info, bytes, frames };
}

/**
 * The capture test: a context with the privacy guard as an init script, a page whose video
 * start time is known (t0), and the account page loaded with the panel ready.
 */
const test = base.extend({
    context: async ({ context }, use) => {
        const id = who();
        await context.addInitScript(pageGuard, { strings: id.strings, name: id.name });
        await use(context);
    },
    t0: async ({ page }, use) => {
        // The video starts when the page is created, just before this fixture runs.
        void page;
        await use(Date.now());
    },
    panel: async ({ page, t0 }, use) => {
        void t0;
        const panel = new Panel(page);
        await panel.gotoAccount();
        await use(panel);
    }
});

/** Seconds since the video started. */
function at(t0) {
    return (Date.now() - t0) / 1000;
}

/**
 * Waits until no spinner has been visible anywhere on the page for one second (at most 60 s),
 * then holds for ms, so a capture starts on a settled frame.
 * @param {import('@playwright/test').Page} page
 */
async function settle(page, ms = 1500) {
    const deadline = Date.now() + 60_000;
    let quietSince = Date.now();
    while (Date.now() < deadline) {
        const n = await page.evaluate(() => /** @type {any} */ (window).__abpCapture.busy());
        if (n > 0) {
            quietSince = Date.now();
        } else if (Date.now() - quietSince >= 1000) {
            break;
        }
        await page.waitForTimeout(200);
    }
    await page.waitForTimeout(ms);
    await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
}

/**
 * Closes the page, saves its video under test-results/capture/raw/ and returns the path.
 * @param {import('@playwright/test').Page} page
 */
async function savedVideo(page, name) {
    const video = page.video();
    if (!video) {
        throw oneLine('No video: the capture config must record video.');
    }
    await page.close();
    fs.mkdirSync(RAW_DIR, { recursive: true });
    const file = path.join(RAW_DIR, name.replace(/\.gif$/, '.webm'));
    await video.saveAs(file);
    return file;
}

module.exports = { test, expect, still, gif, watch, at, settle, savedVideo, assertClean, pngSize, PANEL_CROP, ASSETS, FRAMES_DIR };
