/**
 * cardSpikeCard: renders one card of the FE-18 contract (spike, not product code).
 *
 * Interface:
 *   @api card       one card object (docs/research/fr2-card-architecture.md, "The contract")
 *   @api density    'compact' (the compact window, about 340 px of content) or 'comfortable' (the rail)
 *   event cardopen    detail { ref, recordId, objectName }   a record link was chosen
 *   event cardchoose  detail { cardKey, fieldKey, ref, recordId } a candidate or a field choice was chosen
 *   event cardask     detail { text }                       a follow-up chip or a related object was chosen
 *   event cardaction  detail { cardKey, control }            a draft or result button was pressed
 *
 * Every value is bound as text. There is no lwc:inner-html, no innerHTML and no href built from card
 * data: a record link is a button that fires cardopen, and the host navigates by Id. The view comes
 * from viewOf, which never throws: an unknown type, an unknown version or a builder that throws shows
 * the card's plain-text fallback.
 */
import { LightningElement, api } from 'lwc';
import { viewOf } from 'c/cardSpikeContract';

let uid = 0;

export default class CardSpikeCard extends LightningElement {
    _card = null;
    _density = 'comfortable';
    view = viewOf(null, 'comfortable');
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
        this._density = value === 'compact' ? 'compact' : 'comfortable';
        this._build(false);
    }

    _build(reset) {
        this.view = viewOf(this._card, this._density);
        if (reset) {
            this.open = this.view.openByDefault !== false;
            this.expanded = false;
        }
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
        return this.hasTitle ? null : this.view.isFallback ? 'Answer' : TYPE_NAMES[this.view.type] || 'Answer';
    }
    get statusLabel() {
        return STATUS_WORDS[this.view.status] || this.view.status;
    }
    get statusClass() {
        return this.view.isError ? 'cs-badge cs-badge-error' : 'cs-badge';
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
        return this._visible(this.view.items);
    }
    get visibleRows() {
        return this._visible(this.view.rows);
    }
    get hasItems() {
        return (this.view.items || []).length > 0;
    }
    get hasRows() {
        return (this.view.rows || []).length > 0;
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
        return this.relatedItems.length > 0;
    }
    get hasNotes() {
        return this.noteItems.length > 0;
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
