/**
 * customerSummaryCard: draws one card of the FR2 card contract (FE-18; built in Apex by BE-39).
 * Ported from spikes/cards/ cardSpikeCard, which stays as it was.
 *
 * Interface:
 *   @api card       one card object (docs/research/fr2-card-architecture.md, "The contract")
 *   @api density    'compact' (the default: the compact window, about 340 px of content) or
 *                   'comfortable' (the rail). A grid stacks and a list folds at 5 when compact; a
 *                   list folds at 10 when comfortable. The count line is never folded.
 *   @api focusLink(ref)  focuses the card's link to the record with that ref key (a host returning
 *                   focus after a drill); true when a link took focus.
 *   event cardopen   detail { ref, recordId, objectName }    a record link was chosen
 *   event cardchoose  detail { cardKey, fieldKey, ref, recordId } a candidate or a field choice was chosen
 *   event cardask     detail { text }                        a follow-up chip or a related object was chosen
 *   event cardaction  detail { cardKey, control }             a draft or result button was pressed
 * Every event bubbles and is composed.
 *
 * Six layouts, one per family: prose, list, fields, grid, metric, chips. Anything else shows the
 * card's own plain text: an unknown type, a version above the registry's, a type not drawn yet (the
 * action types) and a builder that throws. Rich text is drawn from the card's body runs only.
 *
 * Every value is bound as text. Nothing is written as markup and no href is built from card data:
 * a record link is a button that fires cardopen, and the host navigates by Id. A record Id never
 * reaches the markup; it stays in the view's refs and leaves only in an event's detail.
 *
 * Keys: a list of record links, a table's row heads and stacked rows are one Tab stop each, with the
 * arrow keys, Home and End inside.
 */
import { LightningElement, api } from 'lwc';
import { viewOf } from './cardContract';

const ROVE_STEP = { ArrowDown: 1, ArrowRight: 1, ArrowUp: -1, ArrowLeft: -1 };

const TYPE_NAMES = {
    text: 'Answer',
    notice: 'Note',
    error: 'Error',
    followups: 'Suggested questions',
    trail: 'Queries run'
};

const STATUS_WORDS = {
    ERROR: 'Error',
    EMPTY: 'Empty',
    NOT_FOUND: 'Not found',
    AMBIGUOUS: 'Choose one',
    READY: 'Ready',
    NEEDS_INPUT: 'Needs input',
    REFUSED: 'Refused',
    UNDONE: 'Undone'
};

let uid = 0;

export default class CustomerSummaryCard extends LightningElement {
    _card = null;
    _density = 'compact';
    view = viewOf(null, 'compact');
    open = true;
    expanded = false;
    titleId = 'cs-card-title-' + uid++;

    @api
    get card() {
        return this._card;
    }
    set card(value) {
        this._card = value;
        this._build(true);
    }

    @api
    get density() {
        return this._density;
    }
    set density(value) {
        this._density = value === 'comfortable' ? 'comfortable' : 'compact';
        this._build(false);
    }

    /**
     * Moves focus to this card's first link to the record with that ref key, so a host can return
     * focus to the link a drill started from. True when a link took focus.
     */
    @api
    focusLink(ref) {
        const link = Array.from(this.template.querySelectorAll('button[data-ref]')).find((b) => b.dataset.ref === ref);
        if (!link) {
            return false;
        }
        link.focus();
        return true;
    }

    _build(reset) {
        this.view = viewOf(this._card, this._density);
        if (reset) {
            this.open = this.view.openByDefault !== false;
            this.expanded = false;
        }
    }

    renderedCallback() {
        this._syncRoving();
    }

    // ------------------------------------------------------------ families

    get isProse() {
        return this.view.family === 'prose';
    }
    get isList() {
        return this.view.family === 'list';
    }
    get isFields() {
        return this.view.family === 'fields';
    }
    get isGrid() {
        return this.view.family === 'grid';
    }
    get isMetric() {
        return this.view.family === 'metric';
    }
    get isChips() {
        return this.view.family === 'chips';
    }
    get isFallback() {
        return this.view.isFallback;
    }

    get cardClass() {
        const parts = ['cs-card', 'cs-family-' + (this.view.family || 'fallback'), 'cs-density-' + this._density];
        if (this.view.isError) {
            parts.push('cs-card-error');
        }
        return parts.join(' ');
    }

    get hasTitle() {
        return !!this.view.title;
    }
    get hasHead() {
        return this.hasTitle || !!this.view.meta || this.view.hasStatus;
    }
    get labelledBy() {
        return this.hasTitle ? this.titleId : null;
    }
    get ariaLabel() {
        // A card with no title is named by its type so a screen reader can tell cards apart.
        if (this.hasTitle) {
            return null;
        }
        return this.view.isFallback ? 'Answer' : TYPE_NAMES[this.view.type] || 'Answer';
    }
    get statusLabel() {
        return STATUS_WORDS[this.view.status] || this.view.status;
    }
    get statusClass() {
        return this.view.isError ? 'cs-badge cs-badge-error' : 'cs-badge';
    }

    // ------------------------------------------------------------ rich text (body runs)

    /** Prose draws its body; a list draws it when it has no lines; fields draw it under the fields. */
    get showBlocks() {
        const blocks = this.view.blocks || [];
        if (!blocks.length) {
            return false;
        }
        return this.isProse || this.isFields || (this.isList && !this.hasItems);
    }
    get blocksClass() {
        return this.isProse ? 'cs-prose' : this.isFields ? 'cs-blocks cs-blocks-muted' : 'cs-blocks';
    }

    // ------------------------------------------------------------ folding

    get showBody() {
        return !this.view.folds || this.open;
    }
    get toggleLabel() {
        return (this.open ? 'Hide ' : 'Show ') + (this.view.title || 'details');
    }
    get ariaExpanded() {
        return String(this.open);
    }
    get bodyId() {
        return this.titleId + '-body';
    }
    get toggleIcon() {
        return this.open ? '▾' : '▸';
    }
    handleToggle() {
        this.open = !this.open;
    }

    _visible(entries) {
        const all = entries || [];
        return this.expanded || !this.view.canFold ? all : all.slice(0, this.view.foldAt);
    }
    get visibleItems() {
        const choice = this.view.isChoice;
        return this._visible(this.view.items).map((i) => ({
            ...i,
            // A candidate is chosen, not opened; its detail (a city, an owner) tells two alike apart.
            buttonLabel: choice ? 'Choose ' + i.label + (i.hasDetail ? ', ' + i.detail : '') : i.linkLabel
        }));
    }
    get visibleRows() {
        return this._visible(this.view.rows);
    }
    get hasItems() {
        return (this.view.items || []).length > 0;
    }
    get showMore() {
        return this.view.canFold && !this.expanded;
    }
    get moreLabel() {
        return 'Show ' + this.view.hiddenCount + ' more';
    }
    handleMore() {
        this.expanded = true;
    }

    get gridStacked() {
        return this.isGrid && this.view.stacked;
    }
    get gridTable() {
        return this.isGrid && !this.view.stacked;
    }
    /** A table whose rows link is reached through its row heads; one without is a focusable scroll area. */
    get wrapTabindex() {
        return (this.view.rows || []).some((r) => r.ref) ? null : '0';
    }
    get hasControls() {
        return (this.view.controls || []).length > 0;
    }
    get relatedItems() {
        return this.view.type === 'record' ? this.view.items || [] : [];
    }
    get noteItems() {
        return this.view.type === 'record' ? [] : this.view.items || [];
    }
    get hasRelated() {
        return this.isFields && this.relatedItems.length > 0;
    }
    get hasNotes() {
        return this.noteItems.length > 0;
    }

    // ------------------------------------------------------------ roving tabindex

    /** Each [data-roving] group keeps exactly one item at tabindex 0. */
    _syncRoving() {
        this.template.querySelectorAll('[data-roving]').forEach((group) => {
            const items = Array.from(group.querySelectorAll('[data-roving-item]'));
            if (!items.length) {
                return;
            }
            let current = items.findIndex((i) => i.getAttribute('tabindex') === '0');
            if (current < 0) {
                current = 0;
            }
            items.forEach((item, n) => {
                const value = n === current ? '0' : '-1';
                if (item.getAttribute('tabindex') !== value) {
                    item.setAttribute('tabindex', value);
                }
            });
        });
    }

    handleRovingKeydown(event) {
        const step = ROVE_STEP[event.key];
        if (step === undefined && event.key !== 'Home' && event.key !== 'End') {
            return;
        }
        const items = Array.from(event.currentTarget.querySelectorAll('[data-roving-item]'));
        const index = items.indexOf(event.target);
        if (index < 0) {
            return;
        }
        event.preventDefault();
        let next;
        if (event.key === 'Home') {
            next = 0;
        } else if (event.key === 'End') {
            next = items.length - 1;
        } else {
            next = Math.min(items.length - 1, Math.max(0, index + step));
        }
        items.forEach((item, n) => item.setAttribute('tabindex', n === next ? '0' : '-1'));
        items[next].focus();
    }

    handleRovingFocusin(event) {
        const items = Array.from(event.currentTarget.querySelectorAll('[data-roving-item]'));
        const index = items.indexOf(event.target);
        if (index >= 0) {
            items.forEach((item, n) => item.setAttribute('tabindex', n === index ? '0' : '-1'));
        }
    }

    // ------------------------------------------------------------ events

    _ref(key) {
        return (this.view.refs || {})[key] || null;
    }

    handleOpen(event) {
        const ref = this._ref(event.currentTarget.dataset.ref);
        if (!ref) {
            return;
        }
        if (this.view.isChoice) {
            this._fire('cardchoose', { cardKey: this.view.key, fieldKey: null, ref: ref.key, recordId: ref.recordId });
            return;
        }
        this._fire('cardopen', { ref: ref.key, recordId: ref.recordId, objectName: ref.objectName });
    }

    handleChoose(event) {
        const ref = this._ref(event.currentTarget.dataset.ref);
        if (ref) {
            this._fire('cardchoose', { cardKey: this.view.key, fieldKey: event.currentTarget.dataset.field, ref: ref.key, recordId: ref.recordId });
        }
    }

    handleAsk(event) {
        this._fire('cardask', { text: event.currentTarget.dataset.text });
    }

    handleControl(event) {
        this._fire('cardaction', { cardKey: this.view.key, control: event.currentTarget.dataset.control });
    }

    _fire(name, detail) {
        this.dispatchEvent(new CustomEvent(name, { detail, bubbles: true, composed: true }));
    }
}
