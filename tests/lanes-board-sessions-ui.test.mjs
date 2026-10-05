// The session, question and permission rendering both Project Manager pages
// share (tools/lanes-board/sessions-ui.mjs).
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { pageFor } from '../tools/lanes-board/access.mjs';
import {
  ago, answerFor, awayHtml, folderOf, inputPreview, md, needsLabel, pendingCard, questionsHtml, questionsTabHtml, ruleText, sessionNeeds,
  sessionPills,
} from '../tools/lanes-board/sessions-ui.mjs';

describe('the board serves sessions-ui.mjs to its pages', () => {
  it('as JavaScript', () => {
    assert.deepEqual(pageFor('/sessions-ui.mjs', ''), { file: 'sessions-ui.mjs', type: 'text/javascript; charset=utf-8' });
  });
});

describe('md', () => {
  it('escapes HTML and renders code, bold and https links only', () => {
    assert.equal(md('<b>x</b> **y** `z`'), '&lt;b&gt;x&lt;/b&gt; <b>y</b> <code>z</code>');
    assert.equal(md('```js\n<i>\n```'), '<pre>&lt;i&gt;</pre>');
    assert.match(md('[a](https://e.com)'), /<a href="https:\/\/e.com" target="_blank" rel="noopener">a<\/a>/);
    assert.doesNotMatch(md('[a](javascript:alert(1))'), /<a /);
  });
});

describe('inputPreview and ruleText', () => {
  it('shows a command, an edit and a plan the way the owner reads them', () => {
    assert.equal(inputPreview('Bash', { command: 'ls', description: 'List' }), 'ls\n\n# List');
    assert.equal(inputPreview('Edit', { file_path: 'a.md', old_string: 'x', new_string: 'y' }), 'a.md\n\n- x\n+ y');
    assert.equal(inputPreview('ExitPlanMode', { plan: '# Plan' }), '# Plan');
  });
  it('names the rule an "Always allow" adds', () => {
    assert.equal(ruleText([{ type: 'addRules', rules: [{ toolName: 'Bash', ruleContent: 'npm test:*' }] }]), 'Bash(npm test:*)');
    assert.equal(ruleText([{ type: 'setMode', mode: 'acceptEdits' }]), 'switch to acceptEdits');
  });
});

describe('questionsHtml', () => {
  const qs = [{ header: 'Pick', question: 'Which <one>?', multiSelect: true, options: [{ label: 'A "1"', description: 'first' }] }];
  it('escapes the question and its options, and offers Other when live', () => {
    const html = questionsHtml(qs, true);
    assert.match(html, /<span class="chip">Pick<\/span>Which &lt;one&gt;\?/);
    assert.match(html, /data-label="A &quot;1&quot;"/);
    assert.match(html, /data-multi="1"/);
    assert.match(html, /class="text other"/);
  });
  it('is read-only otherwise', () => {
    const html = questionsHtml(qs, false);
    assert.match(html, /disabled/);
    assert.doesNotMatch(html, /other/);
  });
});

describe('pendingCard', () => {
  it('draws a permission with Allow, Always allow naming its rule, Deny and Hand back', () => {
    const html = pendingCard({ id: 'ab12-cd34', kind: 'permission', tool: 'Bash', input: { command: 'rm -rf <x>' }, time: Date.now(),
      suggestions: [{ type: 'addRules', rules: [{ toolName: 'Bash', ruleContent: 'rm:*' }] }] });
    assert.match(html, /Wants to use Bash/);
    assert.match(html, /rm -rf &lt;x&gt;/);
    assert.match(html, /data-allow="ab12-cd34"/);
    assert.match(html, /don't ask again for Bash\(rm:\*\)/);
    assert.match(html, /data-deny="ab12-cd34"/);
    assert.match(html, /data-release="ab12-cd34"/);
  });
  it('draws a question with one Send for all its questions', () => {
    const html = pendingCard({ id: 'ab12-cd34', kind: 'question', time: Date.now(), input: { questions: [{ question: 'A?' }, { question: 'B?' }] } });
    assert.match(html, /Send answers/);
    assert.match(html, /data-answer="ab12-cd34"/);
  });
  it('draws a turn end waiting for a reply', () => {
    assert.match(pendingCard({ id: 'ab12-cd34', kind: 'stop', time: Date.now() }), /waiting for your reply/);
  });
});

describe('session list helpers', () => {
  const s = { pending: [{ kind: 'permission', tool: 'Bash' }], asking: null, queued: true };
  it('says what a session needs', () => {
    assert.equal(sessionNeeds(s), true);
    assert.equal(sessionNeeds({ pending: [], asking: null }), false);
    assert.equal(needsLabel(s), 'Waiting on you');
    assert.equal(needsLabel({ pending: [], asking: ['Which?'] }), 'Asking you (in the app)');
    assert.equal(needsLabel({ pending: [], asking: null }), '');
  });
  it('draws its pills', () => {
    const html = sessionPills(s);
    assert.match(html, /Approve Bash/);
    assert.match(html, /Reply queued/);
    assert.equal(sessionPills({ pending: [], asking: null }), '');
  });
  it('names a folder and a time', () => {
    assert.equal(folderOf('C:\\a\\b\\lane-x'), 'lane-x');
    assert.equal(ago(1000, 61_000), '1 min ago');
    assert.equal(ago(0), '');
  });
});

describe('question previews and the free-form reply', () => {
  it('shows an option\'s preview as escaped monospace text', () => {
    const html = questionsHtml([{ question: 'Layout?', options: [{ label: 'A', preview: '<div>\n| x |' }] }], true);
    assert.match(html, /<pre class="code pv">&lt;div&gt;\n\| x \|<\/pre>/);
    assert.doesNotMatch(html, /<div>\n/);
  });
  it('offers a reply in the owner\'s own words on a held question', () => {
    assert.match(pendingCard({ id: 'ab12-cd34', kind: 'question', time: 1, input: { questions: [{ question: 'A?' }] } }), /class="text freeform"/);
  });
});

describe('the Away switch in the header', () => {
  it('shows on or off and the number waiting', () => {
    const on = awayHtml({ away: { on: true, since: Date.now(), from: 'phone' }, count: 3 });
    assert.match(on, /class="away on"/);
    assert.match(on, /data-away checked/);
    assert.match(on, /<b class="awayn"[^>]*>3<\/b>/);
    assert.match(on, /from the phone/);
    const off = awayHtml({ away: { on: false }, count: 0 });
    assert.doesNotMatch(off, /checked|awayn/);
    assert.match(off, /Away is off/);
  });
});

describe('questionsTabHtml', () => {
  const away = { on: true, since: 1, from: 'PC' };
  const group = { session: 's1', app: 'local_x', title: 'Lane <one>', cwd: 'C:\\w\\lane-pm', task: { ref: 'pm:6', label: 'PM 6', title: 'Away' }, since: 1,
    items: [{ id: 'ab12-cd34', kind: 'question', time: 1, input: { questions: [{ question: 'Which?', options: [{ label: 'A' }] }] } }] };
  const asked = { session: 's2', app: 'local_y', title: 'Other lane', cwd: 'C:\\w\\x', task: null, time: 2, questions: [{ question: 'Shall I?', options: [{ label: 'Yes' }] }] };

  it('groups held items by session, with its title, task and folder', () => {
    const html = questionsTabHtml({ away, count: 1, groups: [group], asked: [] });
    assert.match(html, /data-session="s1"/);
    assert.match(html, /Lane &lt;one&gt;/);
    assert.match(html, /PM 6 Away · lane-pm/);
    assert.match(html, /data-answer="ab12-cd34"/);
  });
  it('lists questions asked in the app read-only, with a button to open them', () => {
    const html = questionsTabHtml({ away, count: 1, groups: [], asked: [asked] }, { openLabel: 'Open on PC' });
    assert.match(html, /Asked in the app/);
    assert.match(html, /disabled/);
    assert.doesNotMatch(html, /data-answer/);
    assert.match(html, /data-open="local_y">Open on PC/);
  });
  it('says what Away means when nothing waits', () => {
    assert.match(questionsTabHtml({ away, count: 0, groups: [], asked: [] }), /Nothing waiting\. Questions/);
    assert.match(questionsTabHtml({ away: { on: false }, count: 0, groups: [], asked: [] }), /Away is off/);
  });
});

describe('answerFor', () => {
  // Just enough of a card for the rules: options picked, Other boxes, the reply box.
  const el = (props = {}) => ({ dataset: {}, value: '', classList: { contains: () => false }, ...props });
  const card = ({ picked = [], other = [], reply = '', multi = [] } = {}) => ({
    querySelector: (sel) => (sel === '.freeform' ? el({ value: reply }) : sel === '.why' ? el({ value: 'no' }) : null),
    querySelectorAll: () => picked.map((labels, i) => ({
      dataset: { multi: multi[i] ? '1' : '0' },
      querySelectorAll: () => labels.map((l) => ({ dataset: { label: l } })),
      querySelector: () => (other[i] ? el({ value: other[i] }) : null),
    })),
  });
  const button = (d) => ({ dataset: d });

  it('turns permission buttons into their answers', () => {
    assert.deepEqual(answerFor(button({ allow: 'p' }), card()), { id: 'p', behavior: 'allow' });
    assert.deepEqual(answerFor(button({ always: 'p' }), card()), { id: 'p', behavior: 'allow', always: true });
    assert.deepEqual(answerFor(button({ deny: 'p' }), card()), { id: 'p', behavior: 'deny', message: 'no' });
    assert.deepEqual(answerFor(button({ release: 'p' }), card()), { id: 'p', release: true });
    assert.equal(answerFor(button({}), card()), null);
  });
  it('collects one pick per question, several on a multi-select, plus Other', () => {
    const c = card({ picked: [['A'], ['B', 'C']], other: [null, 'D'], multi: [false, true] });
    assert.deepEqual(answerFor(button({ answer: 'q' }), c), { id: 'q', picks: [['A'], ['B', 'C', 'D']] });
    assert.deepEqual(answerFor(button({ answer: 'q' }), card({ picked: [['A'], ['B']], other: ['Mine'] })), { id: 'q', picks: [['Mine'], ['B']] });
  });
  it('sends the owner\'s own words instead when typed, and asks for an answer otherwise', () => {
    assert.deepEqual(answerFor(button({ answer: 'q' }), card({ picked: [[]], reply: ' Something else ' })), { id: 'q', reply: 'Something else' });
    assert.match(answerFor(button({ answer: 'q' }), card({ picked: [['A'], []] })).error, /Pick an answer/);
  });
});
