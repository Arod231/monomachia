// The session, question and permission rendering both Project Manager pages
// share (tools/lanes-board/sessions-ui.mjs).
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { pageFor } from '../tools/lanes-board/access.mjs';
import {
  ago, answerFor, approveLabel, awayHtml, bellButtonHtml, bellListHtml, deliveredNote, waitingText, folderOf, inputPreview, md, needsLabel, pendingCard, questionsHtml, questionsTabHtml, ruleText, sessionNeeds,
  STATE_LABELS, commandBarHtml, commandNote, mergeConfirmText, mergePanelHtml, logHtml, pushBoxHtml, pushState, sessionCardHtml, sessionFactsHtml, sessionPills, stateHtml,
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
  it('renders a plan\'s headings, lists and rules, escaped, keeping plain lines as they were', () => {
    assert.equal(md('a\nb'), 'a<br>b');
    assert.equal(md('# Plan <x>\nIntro:\n- one **1**\n- two\n1. first\n2) second\n---\nEnd'),
      '<h4 class="mdh">Plan &lt;x&gt;</h4>Intro:<ul><li>one <b>1</b></li><li>two</li></ul><ol><li>first</li><li>second</li></ol><hr>End');
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
  it('draws a plan rendered, with Approve, the prompt\'s own choices, Reject with a reason and Hand back', () => {
    const html = pendingCard({ id: 'ab12-cd34', kind: 'plan', tool: 'ExitPlanMode', time: 1, input: { plan: '## Steps\n- Build <it>' },
      suggestions: [{ type: 'setMode', mode: 'acceptEdits', destination: 'session' }, { type: 'addRules', rules: [{ toolName: 'Bash', ruleContent: 'npm test' }] }] });
    assert.match(html, /approve its plan/);
    assert.match(html, /<h4 class="mdh">Steps<\/h4><ul><li>Build &lt;it&gt;<\/li><\/ul>/);
    assert.match(html, /<button class="btn primary" data-approve="ab12-cd34">Approve<\/button>/);
    assert.match(html, /data-approve="ab12-cd34" data-sug="0">Approve, auto-accept edits</);
    assert.match(html, /data-approve="ab12-cd34" data-sug="1">Approve, and allow Bash\(npm test\)</);
    assert.match(html, /data-reject="ab12-cd34"/);
    assert.match(html, /class="text why"/);
    assert.match(html, /data-release="ab12-cd34"/);
  });
  it('names the modes a plan can be approved into', () => {
    assert.equal(approveLabel({ type: 'setMode', mode: 'acceptEdits' }), 'Approve, auto-accept edits');
    assert.equal(approveLabel({ type: 'setMode', mode: 'default' }), 'Approve, ask before edits');
    assert.equal(approveLabel({ type: 'setMode', mode: 'somethingNew' }), 'Approve, somethingNew');
  });
  it('draws a turn end with its summary, its last message, Approve & continue, Show me, a reply box and Hand back', () => {
    const html = pendingCard({ id: 'ab12-cd34', kind: 'stop', time: Date.now(), last: 'Task 6 is **done**. <Go on?>',
      summary: { status: 'review_ready', label: 'Ready for review', detail: 'Task <6> built', action: 'approve task 7' } });
    assert.match(html, /Finished its turn/);
    assert.match(html, /<span class="chip">Ready for review<\/span> Task &lt;6&gt; built/);
    assert.match(html, /Next: approve task 7/);
    assert.match(html, /Task 6 is <b>done<\/b>\. &lt;Go on\?&gt;/);
    assert.match(html, /data-turn="ab12-cd34" data-cmd="approve">Approve &amp; continue</);
    assert.match(html, /data-turn="ab12-cd34" data-cmd="show">Show me</);
    assert.match(html, /<textarea class="text turnreply"/);
    assert.match(html, /data-send="ab12-cd34"/);
    assert.match(html, /data-release="ab12-cd34"/);
  });
  it('draws a turn end with no summary yet', () => {
    const html = pendingCard({ id: 'ab12-cd34', kind: 'stop', time: Date.now(), last: 'Done.', summary: null });
    assert.doesNotMatch(html, /class="chip"/);
    assert.match(html, /Done\./);
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
    assert.match(sessionPills({ pending: [{ kind: 'plan', tool: 'ExitPlanMode' }], asking: null }), /Approve its plan/);
    assert.equal(sessionPills({ pending: [], asking: null }), '');
  });
  it('says what each held item waits for', () => {
    assert.equal(waitingText({ kind: 'permission', tool: 'Bash' }), 'wants to use Bash');
    assert.equal(waitingText({ kind: 'plan', tool: 'ExitPlanMode' }), 'asks you to approve its plan');
    assert.equal(waitingText({ kind: 'question' }), 'asks you a question');
    assert.equal(waitingText({ kind: 'stop' }), 'finished its turn and waits for your reply');
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

describe('the bell', () => {
  const rec = (id, read, extra = {}) => ({ id, kind: 'question', session: 's1', text: 'Lane <one> asks you a question', detail: 'Which <camera>?',
    target: { tab: 'questions', item: 'ab12-cd34', session: 's1' }, time: Date.now() - 120000, read, ...extra });

  it('shows its unread count, or none', () => {
    const on = bellButtonHtml({ unread: 3, records: [] });
    assert.match(on, /data-bell-open/);
    assert.match(on, /<b class="belln"[^>]*>3<\/b>/);
    assert.match(on, /aria-label="Notifications, 3 unread"/);
    assert.doesNotMatch(bellButtonHtml({ unread: 0, records: [] }), /belln/);
  });
  it('lists records newest first, escaped, unread ones marked, with Mark all read', () => {
    const html = bellListHtml({ unread: 1, records: [rec('held:a', false), rec('event:b', true, { kind: 'turn', text: 'Lane two finished its turn', detail: '' })] });
    assert.match(html, /data-bell-all/);
    assert.match(html, /<li class="brec unread" data-bell="held:a" data-tab="questions" data-item="ab12-cd34" data-session="s1">/);
    assert.match(html, /Lane &lt;one&gt; asks you a question/);
    assert.match(html, /Which &lt;camera&gt;\?/);
    assert.match(html, /2 min ago/);
    assert.ok(html.indexOf('held:a') < html.indexOf('event:b'));
    assert.match(html, /<li class="brec" data-bell="event:b"/);
  });
  it('says when there is nothing', () => {
    assert.match(bellListHtml({ unread: 0, records: [] }), /Nothing yet/);
    assert.doesNotMatch(bellListHtml({ unread: 0, records: [] }), /data-bell-all/);
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
  it('says when the installed hooks aren\'t this version\'s, and how to fix it', () => {
    const hooks = { current: false, problems: ['The installed relay hook differs from this version\'s.'] };
    const html = questionsTabHtml({ away, count: 0, groups: [], asked: [], hooks });
    assert.match(html, /class="hookwarn"/);
    assert.match(html, /The installed relay hook differs from this version&#39;s\.|The installed relay hook differs from this version's\./);
    assert.match(html, /npm run board:hooks/);
    assert.doesNotMatch(questionsTabHtml({ away, count: 0, groups: [], asked: [], hooks: { current: true, problems: [] } }), /hookwarn/);
    assert.doesNotMatch(questionsTabHtml({ away, count: 0, groups: [], asked: [] }), /hookwarn/);
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
  it('turns a turn end\'s buttons into their answers', () => {
    const c = { querySelector: (sel) => (sel === '.turnreply' ? el({ value: ' Rename it ' }) : null) };
    assert.deepEqual(answerFor(button({ turn: 't', cmd: 'approve' }), card()), { id: 't', command: 'approve' });
    assert.deepEqual(answerFor(button({ turn: 't', cmd: 'show' }), card()), { id: 't', command: 'show' });
    assert.deepEqual(answerFor(button({ send: 't' }), c), { id: 't', reply: 'Rename it' });
    assert.match(answerFor(button({ send: 't' }), { querySelector: () => el({ value: ' ' }) }).error, /Type a reply/);
  });
  it('says when what was sent reaches the session', () => {
    assert.equal(deliveredNote('now'), 'Sent: it carries on with it now.');
    assert.equal(deliveredNote('next-step'), 'Sent: it gets this before its next step.');
    assert.equal(deliveredNote('turn-end'), 'Queued: it gets this when its turn next ends.');
  });
  it('turns plan buttons into their answers', () => {
    assert.deepEqual(answerFor(button({ approve: 'p' }), card()), { id: 'p', behavior: 'allow' });
    assert.deepEqual(answerFor(button({ approve: 'p', sug: '1' }), card()), { id: 'p', behavior: 'allow', suggestion: 1 });
    assert.deepEqual(answerFor(button({ reject: 'p' }), card()), { id: 'p', behavior: 'deny', message: 'no' });
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

describe('pushBoxHtml', () => {
  const home = { supported: true, https: true, standalone: true, permission: 'default', subscribed: false, httpsUrl: 'https://pc.tail.ts.net' };
  it('offers Turn on notifications only in the Home Screen app over HTTPS', () => {
    assert.equal(pushState(home), 'off');
    assert.match(pushBoxHtml(home), /data-push="on"[^>]*>Turn on notifications</);
    assert.match(pushBoxHtml(home), /only while Away is on/);
  });
  it('says how to get there from a Safari tab or the plain-HTTP address', () => {
    const tab = { ...home, standalone: false };
    assert.equal(pushState(tab), 'not-home-screen');
    assert.match(pushBoxHtml(tab), /Add to Home Screen/);
    assert.doesNotMatch(pushBoxHtml(tab), /data-push="on"/);
    const http = { ...home, https: false };
    assert.equal(pushState(http), 'not-https');
    assert.match(pushBoxHtml(http), /https:\/\/pc\.tail\.ts\.net/);
    assert.doesNotMatch(pushBoxHtml(http), /data-push="on"/);
  });
  it('says when they are on (with Turn off), blocked or impossible here', () => {
    assert.equal(pushState({ ...home, subscribed: true }), 'on');
    assert.match(pushBoxHtml({ ...home, subscribed: true }), /data-push="off"/);
    assert.equal(pushState({ ...home, permission: 'denied' }), 'blocked');
    assert.match(pushBoxHtml({ ...home, permission: 'denied' }), /Settings/);
    assert.equal(pushState({ ...home, supported: false }), 'unsupported');
  });
  it('escapes the address', () => {
    assert.doesNotMatch(pushBoxHtml({ ...home, https: false, httpsUrl: 'https://<x>' }), /<x>/);
  });
});

describe('the session page', () => {
  const S1 = '11111111-2222-4333-8444-555555555555';
  const base = {
    id: S1, app: 'local_x', title: 'Lane <7>', cwd: 'C:\\repo\\.claude\\worktrees\\lane-pm-12', active: true, activity: Date.now(),
    state: 'working', summary: null, branch: 'lane/pm-12', task: { ref: 'pm:12', label: 'PM 12', title: 'The Sessions tab' },
    pr: { number: 51, title: 'PM <tasks>', url: 'https://github.com/o/r/pull/51', base: 'tools/pm', draft: true },
    pending: [], asking: null, queued: 0, context: null, stopping: false,
  };

  it('words every state', () => {
    assert.deepEqual(Object.keys(STATE_LABELS).sort(), ['asked', 'ended', 'idle', 'waiting', 'working']);
    assert.match(stateHtml(base), /class="state working"[^>]*>At work</);
    assert.match(stateHtml({ ...base, state: 'waiting' }), /Waiting on you/);
    assert.match(stateHtml({ ...base, stopping: true }), /Stopping/);
  });

  it('shows the branch, task and pull request, escaped', () => {
    const h = sessionFactsHtml(base);
    assert.match(h, /lane\/pm-12/);
    assert.match(h, /PM 12 The Sessions tab/);
    assert.match(h, /href="https:\/\/github.com\/o\/r\/pull\/51"[^>]*>PR #51</);
    assert.match(h, /into tools\/pm \(draft\)/);
    assert.doesNotMatch(h, /<tasks>/);
    assert.match(sessionFactsHtml({ ...base, branch: null, task: null, pr: null }), /No branch/);
  });

  it('shows the app\'s turn summary when it has one', () => {
    const h = sessionFactsHtml({ ...base, summary: { status: 'needs_input', label: 'Needs input', detail: 'Asked <which>', action: null } });
    assert.match(h, /Needs input/);
    assert.match(h, /Asked &lt;which&gt;/);
  });

  it('offers the four commands, End work asking first', () => {
    const h = commandBarHtml(base);
    for (const c of ['approve', 'show', 'stop', 'end']) assert.match(h, new RegExp(`data-cmd="${c}"`));
    assert.match(h, />Approve &amp; continue</);
    assert.match(h, />Show me</);
    assert.match(h, />Stop now</);
    assert.match(h, />End work</);
    assert.match(commandBarHtml({ ...base, stopping: true }), /data-cmd="stop" disabled/);
    assert.match(commandBarHtml({ ...base, state: 'ended' }), /data-cmd="end" disabled/);
  });

  it('offers Merge only to a session with an open pull request', () => {
    assert.match(commandBarHtml(base), /data-cmd="merge"[^>]*>Merge #51</);
    assert.doesNotMatch(commandBarHtml({ ...base, pr: null }), /data-cmd="merge"/);
  });

  it('says what happens to each command', () => {
    assert.equal(commandNote('approve', 'now'), 'Sent: it carries on with it now.');
    assert.equal(commandNote('show', 'next-step'), 'Sent: it gets this before its next step.');
    assert.equal(commandNote('approve', 'turn-end'), 'Queued: it gets this when its turn next ends.');
    assert.match(commandNote('stop', 'next-step'), /stops before its next step/);
    assert.match(commandNote('stop', 'stopped'), /already stopped/);
    assert.match(commandNote('stop', 'idle'), /nothing to stop/);
    assert.match(commandNote('end', 'next-step'), /stops at its next step/);
    assert.match(commandNote('end', 'turn-end'), /idle/);
  });

  it('lists a session on the phone with its state, summary and task, opening its page', () => {
    const h = sessionCardHtml({ ...base, summary: { label: 'Done', detail: 'Built it' } }, { gauge: () => '<i class="g"></i>' });
    assert.match(h, /data-session="11111111-2222-4333-8444-555555555555"/);
    assert.match(h, /Lane &lt;7&gt;/);
    assert.match(h, /At work/);
    assert.match(h, /Done/);
    assert.match(h, /PM 12/);
    assert.match(h, /<i class="g"><\/i>/);
  });

  it('folds tool calls in the conversation, and escapes everything', () => {
    const entries = [
      { kind: 'user', time: 1, text: 'Build <it>' },
      { kind: 'assistant', time: 2, text: 'On **it**.' },
      { kind: 'tool', time: 3, id: 't1', name: 'Bash', summary: 'npm test', input: '{"command":"npm test"}' },
      { kind: 'result', time: 4, tool: 't1', error: false, text: '<ok>' },
      { kind: 'tool', time: 5, id: 't2', name: 'Read', summary: 'a.md', input: '{}' },
    ];
    const h = logHtml({ entries, more: 3 }, new Set(['t1']));
    assert.match(h, /data-more/);
    assert.match(h, /Build &lt;it&gt;/);
    assert.match(h, /On <b>it<\/b>/);
    assert.match(h, /<details class="tl" data-tool="t1" open><summary><span class="tn">Bash<\/span> npm test/);
    assert.match(h, /&lt;ok&gt;/);
    assert.match(h, /data-tool="t2" ><summary><span class="tn">Read<\/span> a.md <span class="run">· no result yet/);
  });
});

describe('the Merge panel', () => {
  const m = { pr: { number: 51, title: 'PM <tasks>', url: 'https://github.com/o/r/pull/51', base: 'tools/pm', head: 'lane/pm-13', draft: false },
    ready: true, behind: false, reasons: [] };

  it('offers the merge, naming the pull request and its base, when ready', () => {
    const h = mergePanelHtml(m);
    assert.match(h, /data-merge-go="51"[^>]*>Merge #51 into tools\/pm</);
    assert.match(h, /PM &lt;tasks&gt;/);
    assert.doesNotMatch(h, /data-merge-update/);
  });

  it('gives every reason it isn\'t ready, with Update branch when behind', () => {
    const h = mergePanelHtml({ ...m, ready: false, behind: true, reasons: ['It is behind tools/pm.', 'Checks failed: <x>.'] });
    assert.doesNotMatch(h, /data-merge-go/);
    assert.match(h, /<li>It is behind tools\/pm\.<\/li>/);
    assert.match(h, /Checks failed: &lt;x&gt;\./);
    assert.match(h, /data-merge-update="51"[^>]*>Update branch</);
    assert.match(h, /data-merge-check/);
  });

  it('says when it is checking, or why it can\'t', () => {
    assert.match(mergePanelHtml(null), /Checking/);
    assert.match(mergePanelHtml(null, { error: 'No <pr>' }), /No &lt;pr&gt;/);
  });

  it('asks before merging, naming the pull request, its base and that the tap is the approval', () => {
    const t = mergeConfirmText(m);
    assert.match(t, /#51/);
    assert.match(t, /PM <tasks>/);
    assert.match(t, /into tools\/pm/);
    assert.match(t, /merge commit/);
    assert.match(t, /approval/);
  });
});
