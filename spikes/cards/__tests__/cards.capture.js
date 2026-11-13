// @ts-check
/**
 * Stills of the card gallery at 340 and 640 px, one pair per group, and the overflow check: no card
 * in a 340 column is wider than the column. Prints "CARDS <json>" lines with counts and sizes only.
 */
const { test, expect, still, settle } = require('../../../e2e/capture/kit');
const { RUN_FILE } = require('../../../e2e/support/env');

const GROUPS = ['summary', 'explorer', 'actions'];

/**
 * Hides in-app guidance and any other fixed overlay that is not the page holding the gallery, so a
 * docked "welcome" card never covers a still. Only visibility changes; nothing is clicked.
 * @param {import('@playwright/test').Page} page
 */
async function hideOverlays(page) {
    await page.evaluate(() => {
        const gallery = document.querySelector('c-card-spike-gallery');
        document.querySelectorAll('body *').forEach((el) => {
            const pos = getComputedStyle(el).position;
            if ((pos === 'fixed' || pos === 'sticky') && gallery && !el.contains(gallery)) {
                /** @type {HTMLElement} */ (el).style.visibility = 'hidden';
            }
        });
    });
}

test('card gallery at 340 and 640', async ({ page }) => {
    // eslint-disable-next-line global-require
    const { origin } = require(RUN_FILE);
    await page.goto(origin + '/lightning/n/FR2_Cards_Spike');
    const gallery = page.locator('c-card-spike-gallery');
    await expect(gallery.locator('[data-capture="cards-340-summary"]')).toBeVisible({ timeout: 90_000 });
    await settle(page, 1500);

    for (const group of GROUPS) {
        for (const width of [340, 640]) {
            const col = gallery.locator(`[data-capture="cards-${width}-${group}"]`);
            await col.scrollIntoViewIfNeeded();
            const box = await col.boundingBox();
            if (!box) {
                throw new Error(`no box for ${width}-${group}`);
            }
            const cards = col.locator('c-card-spike-card');
            const n = await cards.count();
            // Overflow: each card's own scroll width against its column's content width.
            const widths = await col.evaluate((el) => {
                const inner = el.clientWidth - 24;
                return Array.from(el.querySelectorAll('c-card-spike-card')).map((c) => {
                    const art = c.shadowRoot ? c.shadowRoot.querySelector('article') : c.querySelector('article');
                    const w = art ? art.scrollWidth : c.scrollWidth;
                    return { w, inner };
                });
            });
            const over = widths.filter((x) => x.w > x.inner + 1).length;
            await hideOverlays(page);
            const size = await still(page, `fr2-cards-${width}-${group}.png`, {
                x: Math.floor(box.x),
                y: Math.floor(box.y),
                width: Math.ceil(box.width),
                height: Math.ceil(box.height)
            });
            // eslint-disable-next-line no-console
            console.log('CARDS ' + JSON.stringify({ group, width, cards: n, overflowing: over, png: size }));
            if (width === 340) {
                expect(over).toBe(0);
            }
        }
    }
});
