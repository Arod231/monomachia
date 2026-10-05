// The session, question and permission rendering both Project Manager pages
// share (tools/lanes-board/sessions-ui.mjs).
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { pageFor } from '../tools/lanes-board/access.mjs';
import {
  ago, folderOf, inputPreview, md, needsLabel, pendingCard, questionsHtml, ruleText, sessionNeeds, sessionPills,
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
  const s = { pending: [{ kind: 'permission', tool: 'Bash' }], asking: null, queued: true, on: true };
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
    assert.match(html, /Answers from Project Manager/);
    assert.equal(sessionPills({ pending: [], asking: null }), '');
  });
  it('names a folder and a time', () => {
    assert.equal(folderOf('C:\\a\\b\\lane-x'), 'lane-x');
    assert.equal(ago(1000, 61_000), '1 min ago');
    assert.equal(ago(0), '');
  });
});
