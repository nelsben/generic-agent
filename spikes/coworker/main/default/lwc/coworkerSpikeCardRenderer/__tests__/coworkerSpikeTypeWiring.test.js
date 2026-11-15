/**
 * FE-24: the spike's files agree with each other and with BE-39's envelope. No org is needed: each check
 * reads the source files. What only an org can show (the type deploys, the agent publishes, Coworker
 * draws the card) is on docs/research/fr2-coworker-spike.md as not measured.
 */
const fs = require('fs');
const path = require('path');

const SPIKE = path.join(__dirname, '..', '..', '..');
const ROOT = path.join(SPIKE, '..', '..', '..', '..');
const TYPE_NAME = 'coworkerSpikeSummaryCard';
const TYPE_DIR = path.join(SPIKE, 'lightningTypes', TYPE_NAME);
const RENDERER_DIR = path.join(SPIKE, 'lwc', 'coworkerSpikeCardRenderer');
const AGENT = path.join(SPIKE, 'aiAuthoringBundles', 'Customer_Summary_Coworker_Spike', 'Customer_Summary_Coworker_Spike.agent');

const read = (p) => fs.readFileSync(p, 'utf8');

function be39SummaryKeys() {
    const page = read(path.join(ROOT, 'docs', 'research', 'fr2-card-contract-apex.md'));
    const block = /```json\n([\s\S]*?)\n```/.exec(page.slice(page.indexOf('### `summary` (sum)')));
    return Object.keys(JSON.parse(block[1])).sort();
}

function apexMembers(className) {
    const src = read(path.join(SPIKE, 'classes', className + '.cls'));
    return Array.from(src.matchAll(/@AuraEnabled global [\w<>]+ (\w+)/g)).map((m) => m[1]).sort();
}

function apiProps() {
    const src = read(path.join(RENDERER_DIR, 'coworkerSpikeCardRenderer.js'));
    return Array.from(src.matchAll(/@api (\w+);/g)).map((m) => m[1]).sort();
}

describe('the spike Lightning type, its renderer and the spike agent', () => {
    const renderer = JSON.parse(read(path.join(TYPE_DIR, 'lightningDesktopGenAi', 'renderer.json')));
    const override = renderer.renderer.componentOverrides.$;

    test("the Apex class behind the type has exactly the members of BE-39's summary card", () => {
        const schema = JSON.parse(read(path.join(TYPE_DIR, 'schema.json')));
        expect(schema['lightning:type']).toBe('@apexClassType/c__CoworkerSpikeSummaryCard');
        expect(apexMembers('CoworkerSpikeSummaryCard')).toEqual(be39SummaryKeys());
        expect(apexMembers('CoworkerSpikeCardBlock')).toEqual(['kind', 'runs']);
        expect(apexMembers('CoworkerSpikeCardRun')).toEqual(['code', 'em', 'ref', 'strong', 'text']);
        expect(apexMembers('CoworkerSpikeCardRef')).toEqual(['key', 'label', 'objectName', 'recordId']);
    });

    test('renderer.json names the renderer and maps every card member to one of its @api properties', () => {
        expect(override.definition).toBe('c/coworkerSpikeCardRenderer');
        expect(Object.keys(override.attributes).sort()).toEqual(apiProps());
        const mapped = Object.values(override.attributes).map((v) => /^\{!\$attrs\.(\w+)\}$/.exec(v)[1]);
        expect(mapped.sort()).toEqual(be39SummaryKeys());
    });

    test('the renderer targets Agentforce output for this type only, and imports nothing from force-app', () => {
        const meta = read(path.join(RENDERER_DIR, 'coworkerSpikeCardRenderer.js-meta.xml'));
        expect(meta).toContain('<target>lightning__AgentforceOutput</target>');
        expect(Array.from(meta.matchAll(/<sourceType name="([^"]+)"/g)).map((m) => m[1])).toEqual(['c__' + TYPE_NAME]);
        const js = read(path.join(RENDERER_DIR, 'coworkerSpikeCardRenderer.js'));
        expect(Array.from(js.matchAll(/from '([^']+)'/g)).map((m) => m[1])).toEqual(['lwc', 'lightning/navigation']);
        const html = read(path.join(RENDERER_DIR, 'coworkerSpikeCardRenderer.html'));
        expect(html).toMatch(/<c-customer-summary-card card=\{card\} density="compact"/);
        expect(html).not.toMatch(/lwc:inner-html|href=/);
    });

    test('the spike agent ties its one action to the type and answers only "card spike" requests', () => {
        const agent = read(AGENT);
        expect(agent).toContain('developer_name: "Customer_Summary_Coworker_Spike"');
        expect(Array.from(agent.matchAll(/target: "([^"]+)"/g)).map((m) => m[1])).toEqual(['apex://CoworkerSpikeCardAction']);
        expect(fs.existsSync(path.join(SPIKE, 'classes', 'CoworkerSpikeCardAction.cls'))).toBe(true);
        expect(agent).toMatch(/card: object\n\s+description: "[^"]+"\n\s+complex_data_type_name: "c__coworkerSpikeSummaryCard"\n\s+is_displayable: True/);
        const descriptions = Array.from(agent.matchAll(/^ {4}description: "([^"]+)"/gm)).map((m) => m[1]);
        expect(descriptions.length).toBeGreaterThanOrEqual(3);
        descriptions.forEach((d) => expect(d).toContain("'card spike'"));
        expect(fs.existsSync(path.join(SPIKE, 'aiAuthoringBundles', 'Customer_Summary_Coworker_Spike', 'Customer_Summary_Coworker_Spike.bundle-meta.xml'))).toBe(true);
    });
});
