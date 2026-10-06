// The session rendering both Project Manager pages share
// (tools/lanes-board/sessions-ui.mjs). Nothing in it answers a session: its
// questions, prompts and plans are answered in the Claude app.
import { createRequire } from 'node:module';
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { pageFor } from '../tools/lanes-board/access.mjs';
import {
  ago, awayHtml, bellButtonHtml, bellListHtml, deliveredNote, folderOf, hooksNoticeHtml, md, needsLabel, questionsHtml, sessionNeeds,
  STATE_LABELS, APP_SESSIONS_URL, docHtml, docsHtml, olderCardHtml, viewerHtml, visualsHtml, workImagesHtml, commandBarHtml, commandNote, remotePanelHtml, logHtml, pushBoxHtml, pushState, sessionCardHtml, sessionFactsHtml, sessionPills, stateHtml,
} from '../tools/lanes-board/sessions-ui.mjs';
import * as UI from '../tools/lanes-board/sessions-ui.mjs';

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

describe('what is gone since Oct 6', () => {
  it('has nothing that answers a session, merges or draws the Questions tab', () => {
    for (const name of ['answerFor', 'pendingCard', 'questionsTabHtml', 'mountMerge', 'mergePanelHtml', 'mergeConfirmText', 'revealQuestion', 'approveLabel']) {
      assert.equal(UI[name], undefined, name);
    }
  });
});

describe('questionsHtml', () => {
  const qs = [{ header: 'Pick', question: 'Which <one>?', multiSelect: true, options: [{ label: 'A "1"', description: 'first' }] }];
  it('escapes the question and its options, read-only: they are answered in the app', () => {
    const html = questionsHtml(qs);
    assert.match(html, /<span class="chip">Pick<\/span>Which &lt;one&gt;\?/);
    assert.match(html, /data-label="A &quot;1&quot;" disabled/);
    assert.match(html, /data-multi="1"/);
    assert.doesNotMatch(html, /class="text other"/);
  });
});

describe('session list helpers', () => {
  it('says what a session needs: only a question asked in the app', () => {
    assert.equal(sessionNeeds({ asking: ['Which?'] }), true);
    assert.equal(sessionNeeds({ asking: null }), false);
    assert.equal(needsLabel({ asking: ['Which?'] }), 'Asking you (in the app)');
    assert.equal(needsLabel({ asking: null }), '');
  });
  it('draws its pills', () => {
    const html = sessionPills({ asking: ['Which?'], queued: 2 });
    assert.match(html, /Asking you \(in the app\)/);
    assert.match(html, /Reply queued/);
    assert.equal(sessionPills({ asking: null, queued: 0 }), '');
  });
  it('names a folder and a time', () => {
    assert.equal(folderOf('C:\\a\\b\\lane-x'), 'lane-x');
    assert.equal(ago(1000, 61_000), '1 min ago');
    assert.equal(ago(0), '');
  });
});

describe('question previews', () => {
  it('shows an option\'s preview as escaped monospace text', () => {
    const html = questionsHtml([{ question: 'Layout?', options: [{ label: 'A', preview: '<div>\n| x |' }] }]);
    assert.match(html, /<pre class="code pv">&lt;div&gt;\n\| x \|<\/pre>/);
    assert.doesNotMatch(html, /<div>\n/);
  });
});

describe('the Away switch in the header', () => {
  it('shows on or off, and that it only sends the bell\'s news to the lock screen', () => {
    const on = awayHtml({ on: true, since: Date.now(), from: 'phone' });
    assert.match(on, /class="away on"/);
    assert.match(on, /data-away checked/);
    assert.match(on, /from the phone/);
    assert.match(on, /lock screen/);
    const off = awayHtml({ on: false });
    assert.doesNotMatch(off, /checked/);
    assert.match(off, /Away is off/);
  });
  it('says when the installed hooks aren\'t this version\'s, and how to fix it', () => {
    const html = hooksNoticeHtml({ current: false, problems: ['The installed relay hook differs from this version\'s.'] });
    assert.match(html, /class="hookwarn"/);
    assert.match(html, /The installed relay hook differs from this version's\./);
    assert.match(html, /npm run board:hooks/);
    assert.equal(hooksNoticeHtml({ current: true, problems: [] }), '');
    assert.equal(hooksNoticeHtml(null), '');
  });
});

describe('the bell', () => {
  const rec = (id, read, extra = {}) => ({ id, kind: 'asked', session: 's1', text: 'Lane <one> is waiting on you to answer questions in the app', detail: 'Which <camera>?',
    target: { tab: 'sessions', session: 's1' }, time: Date.now() - 120000, read, ...extra });

  it('shows its unread count, or none', () => {
    const on = bellButtonHtml({ unread: 3, records: [] });
    assert.match(on, /data-bell-open/);
    assert.match(on, /<b class="belln"[^>]*>3<\/b>/);
    assert.match(on, /aria-label="Notifications, 3 unread"/);
    assert.doesNotMatch(bellButtonHtml({ unread: 0, records: [] }), /belln/);
  });
  it('lists records newest first, escaped, unread ones marked, with Mark all read', () => {
    const html = bellListHtml({ unread: 1, records: [rec('event:a', false), rec('event:b', true, { kind: 'turn', text: 'Lane two finished its turn', detail: '' })] });
    assert.match(html, /data-bell-all/);
    assert.match(html, /<li class="brec unread" data-bell="event:a" data-session="s1">/);
    assert.match(html, /Lane &lt;one&gt; is waiting on you to answer questions in the app/);
    assert.match(html, /Which &lt;camera&gt;\?/);
    assert.match(html, /2 min ago/);
    assert.ok(html.indexOf('event:a') < html.indexOf('event:b'));
    assert.match(html, /<li class="brec" data-bell="event:b"/);
  });
  it('opens an older record that pointed at the Questions tab at its session', () => {
    const old = rec('held:x', false, { target: { tab: 'questions', item: 'ab12-cd34', session: 's1' } });
    assert.match(bellListHtml({ unread: 1, records: [old] }), /<li class="brec unread" data-bell="held:x" data-session="s1">/);
  });
  it('says when there is nothing', () => {
    assert.match(bellListHtml({ unread: 0, records: [] }), /Nothing yet/);
    assert.doesNotMatch(bellListHtml({ unread: 0, records: [] }), /data-bell-all/);
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
    asking: null, queued: 0, context: null, stopping: false,
  };

  it('words every state', () => {
    assert.deepEqual(Object.keys(STATE_LABELS).sort(), ['asked', 'ended', 'idle', 'working']);
    assert.match(stateHtml(base), /class="state working"[^>]*>At work</);
    assert.match(stateHtml({ ...base, state: 'asked' }), /Asked in the app/);
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

  it('offers Show me, Stop now and End work, End work asking first, but never Approve or Merge', () => {
    const h = commandBarHtml(base);
    for (const c of ['show', 'stop', 'end']) assert.match(h, new RegExp(`data-cmd="${c}"`));
    assert.doesNotMatch(h, /data-cmd="approve"|Approve/);
    assert.doesNotMatch(h, /data-cmd="merge"|Merge/);
    assert.match(h, />Show me</);
    assert.match(h, />Stop now</);
    assert.match(h, />End work</);
    assert.match(commandBarHtml({ ...base, stopping: true }), /data-cmd="stop" disabled/);
    assert.match(commandBarHtml({ ...base, state: 'ended' }), /data-cmd="end" disabled/);
  });

  it('offers Compact and Open in the Claude app to every session', () => {
    const h = commandBarHtml({ ...base, remote: 'https://claude.ai/code/session_01X' });
    assert.match(h, /data-cmd="compact"[^>]*>Compact</);
    assert.match(h, /href="https:\/\/claude.ai\/code\/session_01X"[^>]*>Open in the Claude app</);
    const none = commandBarHtml({ ...base, remote: null });
    assert.match(none, /data-cmd="compact"/);
    assert.match(none, /data-cmd="app"[^>]*>Open in the Claude app</);
  });

  it('says when what was sent reaches the session', () => {
    assert.equal(deliveredNote('next-step'), 'Sent: it gets this before its next step.');
    assert.equal(deliveredNote('turn-end'), 'Queued: it gets this when its turn next ends.');
  });

  it('says what happens to each command', () => {
    assert.equal(commandNote('show', 'next-step'), 'Sent: it gets this before its next step.');
    assert.equal(commandNote('show', 'turn-end'), 'Queued: it gets this when its turn next ends.');
    assert.match(commandNote('stop', 'next-step'), /stops before its next step/);
    assert.doesNotMatch(commandNote('stop', 'next-step'), /Away/);
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

describe('Compact and Open in the Claude app', () => {
  const d = { id: '11111111-2222-4333-8444-555555555555', title: 'Lane <7>', remote: 'https://claude.ai/code/session_01X' };

  it('says to type /compact in the Claude app, then opens the session there', () => {
    const h = remotePanelHtml(d, { compact: true });
    assert.match(h, /\/compact/);
    assert.match(h, /data-copy="\/compact"/);
    assert.match(h, /href="https:\/\/claude.ai\/code\/session_01X"/);
  });

  it('without a link, says how to turn Remote Control on, and offers the app\'s session list', () => {
    for (const compact of [true, false]) {
      const h = remotePanelHtml({ ...d, remote: null }, { compact });
      assert.match(h, /Connect new sessions to Remote Control/);
      assert.match(h, /\/rc/);
      assert.match(h, new RegExp(`href="${APP_SESSIONS_URL.replace(/[/.]/g, '\\$&')}"`));
      assert.match(h, /Lane &lt;7&gt;/);
    }
  });

});

describe('Visuals', () => {
  const v = (extra = {}) => ({ id: '1700000000000-0', kind: 'still', caption: 'The <shrine>', task: 'M1 7', time: Date.now() - 60_000,
    url: '/media/s/1700000000000-0.png', poster: null, ...extra });

  it('lists posted shots and clips, newest first as given, each opening the viewer', () => {
    const h = visualsHtml([v({ kind: 'clip', url: '/media/s/a.mp4', poster: '/media/s/a.poster.jpg', caption: 'A run' }), v()]);
    assert.match(h, /<h2>Visuals<\/h2>/);
    assert.match(h, /data-vis="0"[^]*<video [^>]*src="\/media\/s\/a.mp4"[^>]*>/);
    for (const attr of ['autoplay', 'loop', 'muted', 'playsinline', 'poster="/media/s/a.poster.jpg"']) assert.match(h, new RegExp(`<video [^>]*${attr}`));
    assert.match(h, /data-vis="1"[^]*<img [^>]*src="\/media\/s\/1700000000000-0.png"[^>]*loading="lazy"/);
    assert.match(h, /The &lt;shrine&gt;/);
    assert.match(h, /M1 7/);
    assert.doesNotMatch(h, /<shrine>/);
  });

  it('shows nothing when the session posted nothing', () => {
    assert.equal(visualsHtml([]), '');
    assert.equal(visualsHtml(undefined), '');
  });

  it('shows one visual full screen, with its caption, task, time and place in the list', () => {
    const list = [v({ kind: 'clip', url: '/media/s/a.mp4', caption: 'A run' }), v()];
    const clip = viewerHtml(list, 0);
    assert.match(clip, /<video [^>]*src="\/media\/s\/a.mp4"[^>]*autoplay[^>]*loop[^>]*muted[^>]*playsinline[^>]*controls/);
    assert.match(clip, /1 of 2/);
    assert.match(clip, /A run/);
    const still = viewerHtml(list, 1);
    assert.match(still, /<img [^>]*src="\/media\/s\/1700000000000-0.png"/);
    assert.match(still, /2 of 2/);
    assert.match(still, /The &lt;shrine&gt; · M1 7/);
    assert.match(still, /data-viewer-close/);
  });

  it('lists older sessions known by their media, each opening its page', () => {
    const h = olderCardHtml({ id: '11111111-2222-4333-8444-555555555555', title: 'Lane <x>', cwd: 'C:\\w\\lane-x', count: 3, latest: Date.now() - 5 * 86_400_000 });
    assert.match(h, /data-session="11111111-2222-4333-8444-555555555555"/);
    assert.match(h, /Lane &lt;x&gt;/);
    assert.match(h, /3 visuals/);
    assert.match(h, /lane-x/);
  });
});

describe('the bell and new visuals', () => {
  it("opens a new-visuals record at the session's visuals", () => {
    const h = bellListHtml({ unread: 1, records: [{ id: 'visuals:s:1-0', kind: 'visuals', session: 's', text: 'Lane posted a shot', detail: 'x', time: 1, read: false,
      target: { tab: 'sessions', session: 's', visuals: true } }] });
    assert.match(h, /data-visuals="1" data-session="s"/);
  });
});

describe('Images of the work', () => {
  it('lists the images of the work under Visuals, each opening the viewer, and nothing when there are none', () => {
    const h = workImagesHtml([{ id: '9-0', kind: 'still', url: '/work/s/9-0', caption: 'arena <1>.png', source: 'C:\\w\\shots\\arena <1>.png', time: Date.now() }]);
    assert.match(h, /<h2>Images of the work<\/h2>/);
    assert.match(h, /data-work="0"[^]*<img [^>]*src="\/work\/s\/9-0"[^>]*loading="lazy"/);
    assert.match(h, /arena &lt;1&gt;\.png/);
    assert.equal(workImagesHtml([]), '');
  });
});

describe('Docs', () => {
  // The UMD build sets globalThis.marked, as it sets window.marked on the pages.
  const marked = (createRequire(import.meta.url)('../tools/second-brain/vendor/marked.umd.js'), globalThis.marked);
  const S1 = '11111111-2222-4333-8444-555555555555';
  const pr = { number: 7, title: 'Lane <x>', url: 'https://github.com/o/r/pull/7', state: 'OPEN', draft: false, base: 'main', head: 'lane/x', body: '## Summary\n\n<img src=x onerror=alert(1)>',
    additions: 12, deletions: 3, checks: [{ name: 'test', state: 'SUCCESS' }, { name: 'lint', state: 'FAILURE' }], files: [{ path: 'docs/plan.md', additions: 12, deletions: 3 }] };

  it('serves the second brain\'s Markdown library to the pages', () => {
    assert.deepEqual(pageFor('/marked.js', ''), { file: '../second-brain/vendor/marked.umd.js', type: 'text/javascript; charset=utf-8' });
  });

  it('renders Markdown with any HTML in it shown as text, and only web links', () => {
    const h = docHtml('# Title\n\n<script>alert(1)</script>\n\n[a](javascript:alert(1)) [b](https://e.com) ![i](data:image/png;base64,AA)', marked);
    assert.match(h, /<h1[^>]*>Title<\/h1>/);
    assert.doesNotMatch(h, /<script/);
    assert.match(h, /&lt;script&gt;/);
    assert.doesNotMatch(h, /javascript:|data:image/);
    assert.match(h, /<a href="https:\/\/e.com" target="_blank" rel="noopener">b<\/a>/);
  });

  it('lists its documents (Markdown opens in the reader, HTML and PDF in a new tab), its pull request and its artifacts', () => {
    const h = docsHtml({ docs: [{ path: 'C:\\w\\docs\\plan.md', name: 'plan.md', dir: 'docs', kind: 'md', time: 1 },
      { path: 'C:\\w\\r <1>.html', name: 'r <1>.html', dir: '', kind: 'html', time: 1 }],
    artifacts: [{ url: 'https://claude.ai/artifact/Rep0rt', title: 'Report <x>', time: 1 }], pr }, S1, { marked });
    assert.match(h, /<h2>Docs<\/h2>/);
    assert.match(h, /<button [^>]*data-doc="0"[^>]*>[^]*plan.md/);
    assert.match(h, new RegExp(`<a [^>]*href="/doc\\?session=${S1}&amp;path=C%3A%5Cw%5Cr%20%3C1%3E.html"[^>]*target="_blank"`));
    assert.match(h, /r &lt;1&gt;\.html/);
    assert.match(h, /<a href="https:\/\/claude.ai\/artifact\/Rep0rt" target="_blank" rel="noopener">Report &lt;x&gt;<\/a>/);
    assert.match(h, /<a href="https:\/\/github.com\/o\/r\/pull\/7"[^>]*>PR #7<\/a> Lane &lt;x&gt;/);
    assert.match(h, /\+12 −3/);
    assert.match(h, /test[^]*lint/);
    assert.match(h, /docs\/plan.md/);
    assert.match(h, /<h2[^>]*>Summary<\/h2>/);
    assert.doesNotMatch(h, /<img src=x/);
  });

  it('shows nothing when it wrote and published nothing and has no pull request', () => {
    assert.equal(docsHtml({ docs: [], artifacts: [], pr: null }, S1, { marked }), '');
    assert.equal(docsHtml(null, S1, { marked }), '');
  });
});
