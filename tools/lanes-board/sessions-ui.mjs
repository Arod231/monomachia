// How both Project Manager pages draw sessions and what they wait on: a
// session's pills, the Away switch, the Questions tab with the questions,
// plans, permission prompts and turn ends the relay hands over, the bell, and a
// little Markdown. index.html and m.html load it from /sessions-ui.mjs;
// tests/lanes-board-sessions-ui.test.mjs checks it. Most of it returns data or
// HTML, with every value from a session escaped; answerFor and the card
// helpers read cards the page hands them, so both pages answer alike. Two
// functions act on the page itself: mountBell (fetches /bell, posts reads,
// runs its own timer and listeners) and revealQuestion (scrolls and flashes a
// card); the pages check those by hand.

export const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

export function ago(ms, now = Date.now()) {
  if (!ms) return '';
  const s = Math.max(0, Math.round((now - ms) / 1000));
  if (s < 60) return `${s} s ago`;
  if (s < 3600) return `${Math.round(s / 60)} min ago`;
  if (s < 86400) return `${Math.round(s / 3600)} h ago`;
  return `${Math.round(s / 86400)} d ago`;
}

export const folderOf = (cwd) => String(cwd ?? '').split(/[\\/]/).filter(Boolean).slice(-1)[0] ?? '';

// ---------- sessions in a list ----------
// s is a session from /sessions (sessions-api.mjs).

export const sessionNeeds = (s) => s.pending.length > 0 || !!s.asking;
export const needsLabel = (s) => (s.pending.length ? 'Waiting on you' : s.asking ? 'Asking you (in the app)' : '');

export function sessionPills(s) {
  const pills = [];
  for (const p of s.pending) {
    const what = { permission: `Approve ${esc(p.tool)}`, plan: 'Approve its plan', question: 'Asking you' }[p.kind] ?? 'Waiting for your reply';
    pills.push(`<span class="pill need">${what}</span>`);
  }
  if (s.asking && !s.pending.some((p) => p.kind === 'question')) pills.push('<span class="pill need">Asking you (in the app)</span>');
  if (s.queued) pills.push('<span class="pill">Reply queued</span>');
  return pills.length ? `<div class="pills">${pills.join('')}</div>` : '';
}

// A little Markdown, escaped first: code blocks, headings, lists, rules,
// inline code, bold and https links. Other lines keep their line breaks.
const inline = (s) => esc(s)
  .replace(/`([^`\n]+)`/g, '<code>$1</code>')
  .replace(/\*\*([^*\n]+)\*\*/g, '<b>$1</b>')
  .replace(/\[([^\]\n]+)\]\((https?:\/\/[^)\s]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>');

function mdBlocks(part) {
  const out = [];
  let lines = [];
  let list = null;
  const endLines = () => { if (lines.length) out.push(lines.join('<br>')); lines = []; };
  const endList = () => { if (list) out.push(`<${list.tag}>${list.items.map((x) => `<li>${x}</li>`).join('')}</${list.tag}>`); list = null; };
  for (const line of part.split('\n')) {
    const h = line.match(/^#{1,6}\s+(.*)$/);
    const li = line.match(/^\s*([-*]|\d+[.)])\s+(.*)$/);
    if (/^\s*(-{3,}|\*{3,}|_{3,})\s*$/.test(line)) { endLines(); endList(); out.push('<hr>'); }
    else if (h) { endLines(); endList(); out.push(`<h4 class="mdh">${inline(h[1])}</h4>`); }
    else if (li) {
      endLines();
      const tag = /\d/.test(li[1]) ? 'ol' : 'ul';
      if (list?.tag !== tag) { endList(); list = { tag, items: [] }; }
      list.items.push(inline(li[2]));
    } else { endList(); lines.push(inline(line)); }
  }
  endLines();
  endList();
  return out.join('');
}

export function md(text) {
  return String(text).split(/```[^\n]*\n?/).map((part, i) => (i % 2 ? `<pre>${esc(part.replace(/\n$/, ''))}</pre>` : mdBlocks(part))).join('');
}

// ---------- what a session waits on ----------
// p is a held item from the relay folder: { id, kind: question | permission |
// plan | stop, tool, input, suggestions, time }.

// What a held item waits for, after the session's name.
export function waitingText(p) {
  return { permission: `wants to use ${p.tool}`, plan: 'asks you to approve its plan', question: 'asks you a question' }[p.kind]
    ?? 'finished its turn and waits for your reply';
}

export function inputPreview(tool, input) {
  if (!input || typeof input !== 'object') return String(input ?? '');
  if (tool === 'Bash' || tool === 'PowerShell') return `${input.command ?? ''}${input.description ? `\n\n# ${input.description}` : ''}`;
  if (tool === 'Edit') return `${input.file_path}\n\n- ${String(input.old_string ?? '').slice(0, 1500)}\n+ ${String(input.new_string ?? '').slice(0, 1500)}`;
  if (tool === 'Write') return `${input.file_path}\n\n${String(input.content ?? '').split('\n').slice(0, 40).join('\n')}`;
  if (tool === 'ExitPlanMode') return String(input.plan ?? JSON.stringify(input, null, 2));
  const s = JSON.stringify(input, null, 2);
  return s.length > 3000 ? `${s.slice(0, 3000)}…` : s;
}

// The rule an "Always allow" adds, from the prompt's permission suggestions.
export function ruleText(sug) {
  return (sug ?? []).map((s) => {
    if (s.type === 'setMode') return `switch to ${s.mode}`;
    const rules = (s.rules ?? []).map((r) => `${r.toolName}${r.ruleContent ? `(${r.ruleContent})` : ''}`).join(', ');
    return `${rules || 'this'}${s.directories ? ` ${s.directories.join(', ')}` : ''}`;
  }).join('; ');
}

// The button for one of a plan prompt's own choices: a mode to go on in, or a
// rule to add.
const MODES = { acceptEdits: 'auto-accept edits', default: 'ask before edits', bypassPermissions: 'bypass permissions', auto: 'auto mode', dontAsk: "don't ask" };
export function approveLabel(sug) {
  return sug?.type === 'setMode' ? `Approve, ${MODES[sug.mode] ?? sug.mode}` : `Approve, and allow ${ruleText([sug])}`;
}

// AskUserQuestion's questions; live: answerable here (else read-only). An
// option's preview (a mockup) is shown as monospace text, never as HTML.
export function questionsHtml(questions, live) {
  return questions.map((q, i) => `<div class="q" data-qi="${i}" data-multi="${q.multiSelect ? 1 : 0}">
      <div class="qh">${q.header ? `<span class="chip">${esc(q.header)}</span>` : ''}${esc(q.question)}${q.multiSelect ? ' <span class="m">(pick any)</span>' : ''}</div>
      <div class="opts">${(q.options ?? []).map((o) => `<button class="opt" data-label="${esc(o.label)}" ${live ? '' : 'disabled'}><b>${esc(o.label)}</b>${o.description ? `<span>${esc(o.description)}</span>` : ''}${o.preview ? `<pre class="code pv">${esc(o.preview)}</pre>` : ''}</button>`).join('')}
      ${live ? `<input class="text other" placeholder="Other: type your own answer">` : ''}</div></div>`).join('');
}

export function pendingCard(p) {
  const when = `<span class="k" data-t="${Number(p.time) || ''}">${esc(ago(p.time))}</span>`;
  const back = `<button class="btn small ghost" data-release="${esc(p.id)}" title="Stop waiting for the Project Manager: the app shows its own prompt">Hand back to the app</button>`;
  if (p.kind === 'permission') {
    const always = Array.isArray(p.suggestions) && p.suggestions.length;
    return `<div class="pcard" data-pid="${esc(p.id)}"><div class="ch"><i class="sw owner"></i><b>Wants to use ${esc(p.tool)}</b>${when}</div>
      <pre class="code">${esc(inputPreview(p.tool, p.input))}</pre>
      <div class="row"><button class="btn primary" data-allow="${esc(p.id)}">Allow</button>
        ${always ? `<button class="btn" data-always="${esc(p.id)}" title="Adds a permission rule">Allow, and don't ask again for ${esc(ruleText(p.suggestions))}</button>` : ''}
        <button class="btn" data-deny="${esc(p.id)}">Deny</button><input class="text why" placeholder="Why (optional): sent to Claude with a deny"></div>
      <div class="row">${back}</div></div>`;
  }
  if (p.kind === 'plan') {
    const plan = typeof p.input?.plan === 'string' ? md(p.input.plan) : `<pre class="code">${esc(inputPreview(p.tool, p.input))}</pre>`;
    return `<div class="pcard" data-pid="${esc(p.id)}"><div class="ch"><i class="sw owner"></i><b>Asks you to approve its plan</b>${when}</div>
      <div class="plan">${plan}</div>
      <div class="row"><button class="btn primary" data-approve="${esc(p.id)}">Approve</button>${(Array.isArray(p.suggestions) ? p.suggestions : [])
        .map((s, i) => `<button class="btn" data-approve="${esc(p.id)}" data-sug="${i}">${esc(approveLabel(s))}</button>`).join('')}</div>
      <div class="row"><button class="btn" data-reject="${esc(p.id)}">Reject</button><input class="text why" placeholder="Why, and what to change (optional): sent to Claude"></div>
      <div class="row">${back}</div></div>`;
  }
  if (p.kind === 'question') {
    return `<div class="pcard" data-pid="${esc(p.id)}"><div class="ch"><i class="sw owner"></i><b>Asks you</b>${when}</div>
      ${questionsHtml(p.input?.questions ?? [], true)}
      <textarea class="text freeform" rows="2" placeholder="Or reply in your own words instead of picking"></textarea>
      <div class="row"><button class="btn primary" data-answer="${esc(p.id)}">Send answer${(p.input?.questions ?? []).length > 1 ? 's' : ''}</button>${back}</div></div>`;
  }
  // A turn end: the app's summary of the turn once written, the session's last
  // message, two quick replies and a reply box.
  const s = p.summary;
  return `<div class="pcard" data-pid="${esc(p.id)}"><div class="ch"><i class="sw owner"></i><b>Finished its turn</b>${when}</div>
    ${s ? `<div class="sum"><span class="chip">${esc(s.label)}</span> ${esc(s.detail)}${s.action ? `<div class="m">Next: ${esc(s.action)}</div>` : ''}</div>` : ''}
    ${p.last ? `<div class="plan last">${md(p.last)}</div>` : ''}
    <div class="row"><button class="btn primary" data-turn="${esc(p.id)}" data-cmd="approve">Approve &amp; continue</button>
      <button class="btn" data-turn="${esc(p.id)}" data-cmd="show">Show me</button></div>
    <textarea class="text turnreply" rows="2" placeholder="Or reply: it carries on with your words"></textarea>
    <div class="row"><button class="btn" data-send="${esc(p.id)}">Send reply</button>${back}</div></div>`;
}

// What the page says once a reply or command is sent (`when` from the server).
export function deliveredNote(when) {
  return { now: 'Sent: it carries on with it now.', 'next-step': 'Sent: it gets this before its next step.' }[when]
    ?? 'Queued: it gets this when its turn next ends.';
}

// ---------- the session page ----------
// d is a session from /sessions or /session (sessions-api.mjs), with its state
// (sessions.mjs sessionState), turn summary, branch, task and pull request.

export const STATE_LABELS = { waiting: 'Waiting on you', asked: 'Asked in the app', ended: 'Ended', working: 'At work', idle: 'Idle' };

export function stateHtml(d) {
  const state = STATE_LABELS[d.state] ? d.state : 'idle';
  const label = d.stopping && state !== 'waiting' ? 'Stopping' : STATE_LABELS[state];
  return `<span class="state ${state}${d.stopping ? ' stopping' : ''}">${label}</span>`;
}

// The app's turn summary, then the branch, plan task and pull request.
export function sessionFactsHtml(d) {
  const rows = [];
  if (d.summary) rows.push(`<div class="fact sum"><b>${esc(d.summary.label)}</b>${d.summary.detail ? ` ${esc(d.summary.detail)}` : ''}</div>`);
  rows.push(`<div class="fact"><span class="fk">Branch</span> ${d.branch ? `<code>${esc(d.branch)}</code>` : 'No branch (detached, or not a git folder)'}</div>`);
  if (d.task) rows.push(`<div class="fact"><span class="fk">Task</span> ${esc(d.task.label)} ${esc(d.task.title)}</div>`);
  if (d.pr) {
    rows.push(`<div class="fact"><span class="fk">Pull request</span> <a href="${esc(d.pr.url)}" target="_blank" rel="noopener">PR #${Number(d.pr.number)}</a>`
      + ` ${esc(d.pr.title)}, into ${esc(d.pr.base)}${d.pr.draft ? ' (draft)' : ''}</div>`);
  }
  return rows.join('');
}

// Approve & continue, Show me, Stop now and End work (End work asks first).
export function commandBarHtml(d) {
  const off = (yes) => (yes ? ' disabled' : '');
  return `<div class="cmds" data-session="${esc(d.id)}">`
    + `<button class="btn small primary" data-cmd="approve">Approve &amp; continue</button>`
    + `<button class="btn small" data-cmd="show">Show me</button>`
    + `<button class="btn small" data-cmd="stop"${off(d.stopping)}>Stop now</button>`
    + `${d.pr ? `<button class="btn small" data-cmd="merge">Merge #${Number(d.pr.number)}</button>` : ''}`
    + `<button class="btn small" data-cmd="compact">Compact</button>`
    + (d.remote ? `<a class="btn small" href="${esc(d.remote)}" target="_blank" rel="noopener">Open in the Claude app</a>`
      : `<button class="btn small" data-cmd="app">Open in the Claude app</button>`)
    + `<button class="btn small danger" data-cmd="end"${off(d.state === 'ended')}>End work</button></div>`;
}

// The Merge panel under the command bar: m is /merge (merge-api.mjs), null
// while it's being checked; error when it couldn't be.
export function mergePanelHtml(m, { error = null } = {}) {
  if (error) return `<div class="mergep"><p>${esc(error)}</p><button class="btn small" data-merge-check>Check again</button></div>`;
  if (!m) return '<div class="mergep"><p>Checking the pull request…</p></div>';
  const n = Number(m.pr.number);
  const head = `<p><a href="${esc(m.pr.url)}" target="_blank" rel="noopener">PR #${n}</a> ${esc(m.pr.title)}, into <code>${esc(m.pr.base)}</code></p>`;
  if (m.ready) {
    return `<div class="mergep ready">${head}<p>Ready: out of draft, every check passed, no conflicts, up to date with its base.</p>`
      + `<button class="btn primary" data-merge-go="${n}">Merge #${n} into ${esc(m.pr.base)}</button></div>`;
  }
  return `<div class="mergep">${head}<p>Not ready to merge yet:</p><ul>${m.reasons.map((r) => `<li>${esc(r)}</li>`).join('')}</ul>`
    + `${m.behind ? `<button class="btn small primary" data-merge-update="${n}">Update branch</button> ` : ''}<button class="btn small" data-merge-check>Check again</button></div>`;
}

// Runs the Merge panel (panel: its element, outside anything re-rendered):
// session() is the session shown; say(text, error) tells the owner what happened.
export function mountMerge({ panel, post, session, say }) {
  let m = null;
  async function check() {
    m = null;
    panel.innerHTML = mergePanelHtml(null);
    const id = session();
    try {
      const d = await (await fetch(`/merge?session=${encodeURIComponent(id)}`, { cache: 'no-store' })).json();
      if (id !== session()) return;
      if (d.error) panel.innerHTML = mergePanelHtml(null, { error: d.error });
      else { m = d; panel.innerHTML = mergePanelHtml(m); }
    } catch (err) { panel.innerHTML = mergePanelHtml(null, { error: `Couldn't ask GitHub: ${err.message}` }); }
  }
  panel.addEventListener('click', async (e) => {
    const b = e.target.closest('button');
    if (!b) return;
    if (b.dataset.mergeCheck !== undefined) { check(); return; }
    if (b.dataset.mergeUpdate) {
      b.disabled = true;
      try {
        await post('/merge/update', { session: session(), number: Number(b.dataset.mergeUpdate) });
        say('Asked GitHub to bring the branch up to date with its base: its checks run again, so check back in a few minutes.');
      } catch (err) { say(`Couldn't update the branch: ${err.message}`, true); }
      check();
      return;
    }
    if (b.dataset.mergeGo && m) {
      if (!confirm(mergeConfirmText(m))) return;
      b.disabled = true;
      try {
        const r = await post('/merge', { session: session(), number: Number(b.dataset.mergeGo) });
        say(`Merged #${r.number} into ${r.base}. Its session ${r.told === 'now' ? 'has been' : 'will be'} told to tidy up its local branch.`);
        panel.hidden = true;
      } catch (err) { say(`Couldn't merge: ${err.message}`, true); check(); }
    }
  });
  return {
    toggle() { panel.hidden = !panel.hidden; if (!panel.hidden) check(); },
    show() { panel.hidden = false; check(); },
    hide() { panel.hidden = true; panel.innerHTML = ''; m = null; },
  };
}

// ---------- Compact and Open in the Claude app ----------
// No link or local interface can type into a session or run a slash command
// in it; Remote Control can, from the Claude app on the phone. So Compact
// opens the session there with /compact to type, and a session with no
// Remote Control address gets how to turn it on, and the app's session list.
export const APP_SESSIONS_URL = 'https://claude.ai/code';

// The panel under the command bar for Compact (compact: true) or Open in the
// Claude app on a session with no Remote Control address.
export function remotePanelHtml(d, { compact = false } = {}) {
  const say = compact ? '<p>Compact runs in the Claude app: there, type <code>/compact</code> in this session and send it. It frees the context and the session carries on.</p>' : '';
  if (d.remote) {
    return `<div class="mergep">${say}<p><button class="btn small" data-copy="/compact">Copy /compact</button> `
      + `<a class="btn small primary" href="${esc(d.remote)}" target="_blank" rel="noopener">Open in the Claude app</a></p></div>`;
  }
  return `<div class="mergep">${say}<p>${esc(d.title)} has no Remote Control link, so the Claude app can't open it straight away. To give it one:</p><ul>`
    + '<li>for sessions from now on, turn on <b>Connect new sessions to Remote Control</b> in the Claude app (Settings, Claude Code);</li>'
    + '<li>for this one, type <code>/rc</code> in it once at the PC.</li></ul>'
    + `<p>Meanwhile it may be in the Claude app's session list. ${compact ? '<button class="btn small" data-copy="/compact">Copy /compact</button> ' : ''}`
    + `<a class="btn small" href="${APP_SESSIONS_URL}" target="_blank" rel="noopener">Open the session list</a></p></div>`;
}

// Runs the Compact / Open in the Claude app panel: detail() is the session
// shown; say(text, error) tells the owner what happened. show('compact' | 'app')
// opens it, or closes it when it already shows that.
export function mountRemote({ panel, detail, say }) {
  let kind = null;
  panel.addEventListener('click', async (e) => {
    const b = e.target.closest('[data-copy]');
    if (!b) return;
    try { await navigator.clipboard.writeText(b.dataset.copy); say(`Copied ${b.dataset.copy}: paste it in the session in the Claude app.`); }
    catch { say(`Couldn't copy here: type ${b.dataset.copy} in the Claude app.`, true); }
  });
  return {
    show(what) {
      const d = detail();
      if (!d || (kind === what && !panel.hidden)) { this.hide(); return; }
      kind = what;
      panel.innerHTML = remotePanelHtml(d, { compact: what === 'compact' });
      panel.hidden = false;
    },
    hide() { kind = null; panel.hidden = true; panel.innerHTML = ''; },
  };
}

// The confirmation before a merge.
export function mergeConfirmText(m) {
  return `Merge pull request #${m.pr.number} "${m.pr.title}" into ${m.pr.base}? It merges with a merge commit and deletes the branch ${m.pr.head} on GitHub; `
    + 'the session is then told to tidy up its own. Your tap is the approval for this pull request.';
}

// What the page says once a command is sent (`when` from the server).
export function commandNote(command, when) {
  if (command === 'stop') {
    return { 'next-step': 'Stop now sent: it stops before its next step and ends its turn; with Away on, it then waits for you.',
      stopped: 'It has already stopped: it is waiting for you.', idle: "It isn't working: there's nothing to stop." }[when] ?? 'Stop now sent.';
  }
  if (command === 'end') {
    return when === 'next-step' ? 'Work ended: it stops at its next step. Its branch and pull request stay as they are.'
      : 'Work ended: it is idle, and stops at once if it wakes. Its branch and pull request stay as they are.';
  }
  return deliveredNote(when);
}

// One session in the phone's Sessions list; gauge(context, active) draws its gauge.
export function sessionCardHtml(s, { gauge = () => '' } = {}) {
  return `<li class="scard" data-session="${esc(s.id)}"><div class="t1"><b>${esc(s.title)}</b>${gauge(s.context, s.active)}</div>`
    + `<div class="t2">${stateHtml(s)}<span class="k">${esc(folderOf(s.cwd))} · ${s.active ? 'now' : esc(ago(s.activity))}</span></div>`
    + `${s.summary ? `<div class="k sum"><b>${esc(s.summary.label)}</b> ${esc(s.summary.detail)}</div>` : ''}`
    + `${s.task ? `<div class="k">${esc(s.task.label)} ${esc(s.task.title)}</div>` : ''}${sessionPills(s)}</li>`;
}

// The conversation: the owner's and the session's words, each tool call folded
// with its result (openTools: the ids unfolded).
export function logHtml(d, openTools = new Set()) {
  const results = new Map(d.entries.filter((e) => e.kind === 'result').map((e) => [e.tool, e]));
  const toolIds = new Set(d.entries.filter((e) => e.kind === 'tool').map((e) => e.id));
  const time = (t) => (t ? ` · ${esc(new Date(t).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }))}` : '');
  const parts = d.entries.map((e) => {
    if (e.kind === 'user') return `<div class="msg u"><div class="who">You${time(e.time)}</div><div class="tx">${md(e.text)}</div></div>`;
    if (e.kind === 'assistant') return `<div class="msg a"><div class="tx">${md(e.text)}</div></div>`;
    if (e.kind === 'system') return `<div class="sys">${esc(e.text)}</div>`;
    if (e.kind === 'tool') {
      const r = results.get(e.id);
      const input = typeof e.input === 'string' ? e.input : JSON.stringify(e.input, null, 2);
      return `<details class="tl${r?.error ? ' err' : ''}" data-tool="${esc(e.id)}" ${openTools.has(e.id) ? 'open' : ''}><summary><span class="tn">${esc(e.name)}</span> ${esc(e.summary)}${r ? '' : ' <span class="run">· no result yet</span>'}</summary>`
        + `<pre class="code">${esc(input)}</pre>${r ? `<pre class="code">${esc(r.text || '(no output)')}</pre>` : ''}</details>`;
    }
    if (e.kind === 'result' && !toolIds.has(e.tool)) return `<details class="tl${e.error ? ' err' : ''}"><summary><span class="tn">Result</span></summary><pre class="code">${esc(e.text)}</pre></details>`;
    return '';
  });
  return (d.more ? '<div class="more"><button class="btn small" data-more>Show earlier turns</button></div>' : '') + parts.join('');
}

// ---------- Visuals ----------
// What a session posted with `npm run post` (d.visuals from /session, newest
// first): stills, and clips playing inline, looping and silent like GIFs. A
// tap opens the viewer (mountViewer) at that one.
const visLine = (v) => [v.caption, v.task].filter(Boolean).map(esc).join(' · ');
const clipTag = (v, extra = '') => `<video src="${esc(v.url)}"${v.poster ? ` poster="${esc(v.poster)}"` : ''} autoplay loop muted playsinline preload="metadata"${extra}></video>`;
export function visualsHtml(visuals) {
  if (!visuals?.length) return '';
  const items = visuals.map((v, i) => `<figure class="vis" data-vis="${i}">`
    + (v.kind === 'clip' ? clipTag(v) : `<img src="${esc(v.url)}" alt="${esc(v.caption ?? '')}" loading="lazy">`)
    + `<figcaption>${visLine(v) || '<span class="k">No caption</span>'}<span class="k"> · ${esc(ago(v.time))}</span></figcaption></figure>`);
  return `<div class="sh"><h2>Visuals</h2><span class="m">${visuals.length}</span></div><div class="vgrid">${items.join('')}</div>`;
}

// One visual full screen: list[i], with its place in the list.
export function viewerHtml(list, i) {
  const v = list[i];
  const media = v.kind === 'clip' ? clipTag(v, ' controls') : `<img src="${esc(v.url)}" alt="${esc(v.caption ?? '')}">`;
  return `<div class="vbar"><button class="vbtn" data-viewer-close aria-label="Back">‹ Back</button><span>${i + 1} of ${list.length}</span></div>`
    + `<div class="vstage">${media}</div>`
    + `<div class="vcap">${visLine(v) || 'No caption'}<span class="k"> · ${esc(new Date(v.time).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' }))}</span></div>`
    + (list.length > 1 ? `<button class="vbtn vprev" data-viewer-step="-1" aria-label="Previous"${i === 0 ? ' disabled' : ''}>‹</button>`
      + `<button class="vbtn vnext" data-viewer-step="1" aria-label="Next"${i === list.length - 1 ? ' disabled' : ''}>›</button>` : '');
}

// A session past the Sessions list's 3 days, known by what it posted.
export function olderCardHtml(o) {
  return `<li class="scard" data-session="${esc(o.id)}"><div class="t1"><b>${esc(o.title)}</b></div>`
    + `<div class="t2"><span class="k">${esc(folderOf(o.cwd))} · ${o.count} visual${o.count === 1 ? '' : 's'}, the last ${esc(ago(o.latest))}</span></div></li>`;
}

const VIEWER_CSS = `
.vgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:8px;margin:6px 0 14px}
.vis{margin:0;cursor:pointer;border-radius:8px;overflow:hidden;background:#0003}
.vis img,.vis video{display:block;width:100%;aspect-ratio:16/9;object-fit:cover;background:#000}
.vis figcaption{font-size:12px;padding:5px 7px;line-height:1.3}
.viewer{position:fixed;inset:0;z-index:1000;background:#000;color:#eee;display:flex;flex-direction:column;touch-action:pan-y}
.viewer[hidden]{display:none}
.viewer .vbar{display:flex;justify-content:space-between;align-items:center;padding:calc(env(safe-area-inset-top) + 6px) 10px 6px;font-size:14px}
.viewer .vstage{flex:1;display:flex;align-items:center;justify-content:center;min-height:0}
.viewer .vstage img,.viewer .vstage video{max-width:100%;max-height:100%;object-fit:contain}
.viewer .vcap{padding:8px 12px calc(env(safe-area-inset-bottom) + 10px);font-size:14px}
.viewer .vbtn{background:#fff2;color:#fff;border:0;border-radius:8px;padding:8px 12px;font-size:16px;cursor:pointer}
.viewer .vbtn[disabled]{opacity:.3}
.viewer .vprev,.viewer .vnext{position:absolute;top:50%;transform:translateY(-50%);font-size:28px;padding:6px 14px}
.viewer .vprev{left:8px}.viewer .vnext{right:8px}`;

// The full-screen viewer, shared by both pages: open(list, i) shows list[i];
// a swipe or the arrow keys step through, and Back (or the phone's own back
// gesture, through a history entry of its own) closes it.
export function mountViewer() {
  const style = document.createElement('style');
  style.textContent = VIEWER_CSS;
  document.head.append(style);
  const box = document.createElement('div');
  box.className = 'viewer';
  box.hidden = true;
  document.body.append(box);
  let list = [];
  let at = 0;
  const show = () => { box.innerHTML = viewerHtml(list, at); };
  const step = (d) => { const n = at + d; if (n >= 0 && n < list.length) { at = n; show(); } };
  function close() {
    if (box.hidden) return;
    if (history.state?.viewer) history.back(); else { box.hidden = true; box.innerHTML = ''; }
  }
  window.addEventListener('popstate', (e) => { if (!e.state?.viewer && !box.hidden) { box.hidden = true; box.innerHTML = ''; } });
  box.addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b) return;
    if (b.dataset.viewerClose !== undefined) close();
    else if (b.dataset.viewerStep) step(Number(b.dataset.viewerStep));
  });
  document.addEventListener('keydown', (e) => {
    if (box.hidden) return;
    if (e.key === 'Escape') close();
    else if (e.key === 'ArrowLeft') step(-1);
    else if (e.key === 'ArrowRight') step(1);
  });
  let x0 = null;
  box.addEventListener('touchstart', (e) => { x0 = e.touches.length === 1 ? e.touches[0].clientX : null; }, { passive: true });
  box.addEventListener('touchend', (e) => {
    if (x0 == null) return;
    const dx = e.changedTouches[0].clientX - x0;
    x0 = null;
    if (Math.abs(dx) > 50) step(dx < 0 ? 1 : -1);
  });
  return {
    open(items, i) {
      list = items;
      at = Math.max(0, Math.min(i, items.length - 1));
      if (!list.length) return;
      if (box.hidden) history.pushState({ ...(history.state ?? {}), viewer: true }, '', location.href);
      box.hidden = false;
      show();
    },
    close,
  };
}

// ---------- the Away switch and the Questions tab ----------
// q is /questions (sessions-api.mjs): { away: { on, since, from }, count,
// groups: [{ session, app, title, cwd, task, since, items }], asked: [...] }.

// The switch both pages show in their header, with what's waiting.
export function awayHtml(q) {
  const on = !!q?.away?.on;
  const n = q?.count ?? 0;
  const title = on ? `Away since ${new Date(q.away.since).toLocaleString([], { weekday: 'short', hour: '2-digit', minute: '2-digit' })}${q.away.from ? `, switched on from the ${q.away.from}` : ''}: sessions' permission prompts, plans and turn ends wait in the Questions tab (questions stay in the app)`
    : "Away is off: sessions ask in the app's own dialogs. Switch it on before you leave the PC.";
  return `<label class="away${on ? ' on' : ''}" title="${esc(title)}"><input type="checkbox" data-away ${on ? 'checked' : ''}><span>Away</span>`
    + `${n ? `<b class="awayn" aria-label="${n} waiting">${n}</b>` : ''}</label>`;
}

const groupHead = (g, when) => `<div class="qgh"><b>${esc(g.title)}</b><span class="k">${g.task ? `${esc(g.task.label)} ${esc(g.task.title)} · ` : ''}${esc(folderOf(g.cwd))}</span>`
  + `<span class="k" data-t="${Number(when) || ''}">${esc(ago(when))}</span></div>`;

// The Questions tab: held items grouped by session, then the questions asked
// in the app (read-only, with a button to open the session: openLabel).
export function questionsTabHtml(q, { openLabel = 'Open in the app' } = {}) {
  if (!q) return '<div class="empty">Loading…</div>';
  return hooksNotice(q.hooks) + questionsList(q, openLabel);
}

// When the hooks installed in user settings aren't this version's (hooks.mjs),
// Away can't work as this page says: what's wrong, and the fix.
function hooksNotice(hooks) {
  if (!hooks || hooks.current) return '';
  return `<div class="hookwarn"><b>The hooks in your user settings aren't this version's</b>, so Away may not work as shown here.
    <ul>${hooks.problems.map((p) => `<li>${esc(p)}</li>`).join('')}</ul>
    To fix it, ask a session to run <code>npm run board:hooks</code> (it changes your user settings, so it asks you first).</div>`;
}

function questionsList(q, openLabel) {
  const held = q.groups.map((g) => `<section class="qgroup" data-session="${esc(g.session)}">${groupHead(g, g.since)}
    ${g.items.map((p) => pendingCard(p)).join('')}</section>`);
  const asked = q.asked.map((a) => `<section class="qgroup" data-session="${esc(a.session)}">${groupHead(a, a.time)}
    <div class="pcard info"><div class="ch"><i class="sw owner"></i><b>Asks you, in the app</b></div>
    ${questionsHtml(a.questions, false)}
    <div class="row">${a.remote ? `<a class="btn small" href="${esc(a.remote)}" target="_blank" rel="noopener">Open in the Claude app</a>` : ''}${a.app ? `<button class="btn small" data-open="${esc(a.app)}">${esc(openLabel)}</button>` : ''}<span class="m">Questions are answered in the app.</span></div></div></section>`);
  if (!held.length && !asked.length) {
    return `<div class="empty">${q.away.on ? 'Nothing waiting. Permission prompts, plans and finished turns from every session land here while Away is on; questions stay in the app, and the bell tells you when one waits.'
      : "Nothing waiting. Away is off, so sessions ask in the app's own dialogs; switch Away on before you leave the PC and their permission prompts and finished turns wait here instead."}</div>`;
  }
  return held.join('') + (asked.length ? `<div class="qsub">Asked in the app</div>` + asked.join('') : '');
}

// The body to post to /relay/answer for a click on a card's button, null for
// a button that isn't an answer, or { error } when the card isn't filled in.
export function answerFor(b, card) {
  const d = b.dataset;
  if (d.allow) return { id: d.allow, behavior: 'allow' };
  if (d.always) return { id: d.always, behavior: 'allow', always: true };
  if (d.deny) return { id: d.deny, behavior: 'deny', message: card?.querySelector('.why')?.value ?? '' };
  if (d.approve) return d.sug == null || d.sug === '' ? { id: d.approve, behavior: 'allow' } : { id: d.approve, behavior: 'allow', suggestion: Number(d.sug) };
  if (d.reject) return { id: d.reject, behavior: 'deny', message: card?.querySelector('.why')?.value ?? '' };
  if (d.turn) return { id: d.turn, command: d.cmd };
  if (d.send) {
    const reply = card?.querySelector('.turnreply')?.value.trim();
    return reply ? { id: d.send, reply } : { error: 'Type a reply first, or tap Approve & continue.' };
  }
  if (d.release) return { id: d.release, release: true };
  if (!d.answer) return null;
  const reply = card?.querySelector('.freeform')?.value.trim();
  if (reply) return { id: d.answer, reply };
  const picks = [...card.querySelectorAll('.q')].map((q) => {
    const chosen = [...q.querySelectorAll('.opt.on')].map((o) => o.dataset.label);
    const other = q.querySelector('.other')?.value.trim();
    if (other) chosen.push(other);
    return q.dataset.multi === '1' ? chosen : chosen.slice(-1);
  });
  if (picks.some((p) => !p.length)) return { error: 'Pick an answer for each question, type one under Other, or reply in your own words.' };
  return { id: d.answer, picks };
}

// A tap on an option: one at a time, or any number on a multi-select question.
export function toggleOpt(opt) {
  const q = opt.closest('.q');
  if (q?.dataset.multi !== '1') for (const o of q?.querySelectorAll('.opt') ?? []) if (o !== opt) o.classList.remove('on');
  opt.classList.toggle('on');
}

// What the owner has picked and typed on each card, so a redraw keeps it.
export function captureCards(root) {
  const state = new Map();
  for (const card of root.querySelectorAll('.pcard[data-pid]')) {
    state.set(card.dataset.pid, {
      on: [...card.querySelectorAll('.opt.on')].map((o) => `${o.closest('.q')?.dataset.qi}:${o.dataset.label}`),
      text: [...card.querySelectorAll('input.text, textarea.text')].map((t) => t.value),
    });
  }
  return state;
}
export function restoreCards(root, state) {
  for (const card of root.querySelectorAll('.pcard[data-pid]')) {
    const st = state.get(card.dataset.pid);
    if (!st) continue;
    for (const o of card.querySelectorAll('.opt')) if (st.on.includes(`${o.closest('.q')?.dataset.qi}:${o.dataset.label}`)) o.classList.add('on');
    [...card.querySelectorAll('input.text, textarea.text')].forEach((t, i) => { t.value = st.text[i] ?? ''; });
  }
}

// ---------- the bell ----------
// b is /bell (bell-api.mjs): { unread, records } newest first. A record's
// target says where a tap goes; the page marks it read and goes there.

export function bellButtonHtml(b) {
  const n = b?.unread ?? 0;
  return `<button class="bell" data-bell-open aria-label="Notifications${n ? `, ${n} unread` : ''}" title="Notifications">`
    + '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15zM10 20a2 2 0 0 0 4 0"/></svg>'
    + `${n ? `<b class="belln" aria-hidden="true">${n > 99 ? '99+' : n}</b>` : ''}</button>`;
}

export function bellListHtml(b) {
  const records = b?.records ?? [];
  if (!records.length) return '<div class="bempty">Nothing yet. Questions asked in the app, plans, permission prompts, finished turns, pull requests ready to merge and new visuals from every session show here.</div>';
  return `<div class="bhead"><b>Notifications</b>${b.unread ? '<button class="btn small ghost" data-bell-all>Mark all read</button>' : ''}</div>
    <ul class="blist">${records.map((r) => `<li class="brec${r.read ? '' : ' unread'}" data-bell="${esc(r.id)}" data-tab="${esc(r.target?.tab)}"`
      + `${r.target?.item ? ` data-item="${esc(r.target.item)}"` : ''}${r.target?.merge ? ` data-merge="${Number(r.target.merge)}"` : ''}${r.target?.visuals ? ' data-visuals="1"' : ''} data-session="${esc(r.target?.session)}">`
      + `<div class="bt">${esc(r.text)}</div>${r.detail ? `<div class="bd">${esc(r.detail)}</div>` : ''}`
      + `<div class="k" data-t="${Number(r.time) || ''}">${esc(ago(r.time))}</div></li>`).join('')}</ul>`;
}

// Runs the bell on a page: box holds its button, panel its list (hidden until
// opened); post(url, body) is the page's JSON post; go({ tab, item, session, merge })
// takes the page to a record's target. Polls /bell every few seconds.
// push (the phone page's mountPush) puts lock-screen notifications at the top of the list.
export function mountBell({ box, panel, post, go, push = null, everyMs = 5000 }) {
  let view = null;
  let timer = null;
  let shown = '';
  const draw = () => {
    const button = bellButtonHtml(view);
    if (button !== shown) { shown = button; box.innerHTML = button; }
    if (!panel.hidden) panel.innerHTML = (push?.html() ?? '') + bellListHtml(view);
  };
  push?.onChange(draw);
  async function poll() {
    try {
      const d = await (await fetch('/bell', { cache: 'no-store' })).json();
      if (Array.isArray(d.records)) { view = d; draw(); }
    } catch { /* the page's stamp shows the server's state */ }
    clearTimeout(timer);
    timer = setTimeout(poll, document.hidden ? 30000 : everyMs);
  }
  box.addEventListener('click', (e) => {
    if (!e.target.closest('[data-bell-open]')) return;
    panel.hidden = !panel.hidden;
    draw();
    if (!panel.hidden) poll();
  });
  panel.addEventListener('click', async (e) => {
    const p = e.target.closest('[data-push]');
    if (p && push) { push.act(p.dataset.push); return; }
    if (e.target.closest('[data-bell-all]')) {
      try { view = await post('/bell/read', { all: true }); } catch { /* next poll */ }
      draw();
      return;
    }
    const rec = e.target.closest('[data-bell]');
    if (!rec) return;
    panel.hidden = true;
    try { view = await post('/bell/read', { ids: [rec.dataset.bell] }); } catch { /* next poll */ }
    draw();
    go({ tab: rec.dataset.tab, item: rec.dataset.item ?? null, session: rec.dataset.session || null, merge: Number(rec.dataset.merge) || null,
      visuals: rec.dataset.visuals === '1' });
  });
  document.addEventListener('click', (e) => {
    if (!panel.hidden && !panel.contains(e.target) && !box.contains(e.target)) panel.hidden = true;
  });
  document.addEventListener('visibilitychange', () => { if (!document.hidden) poll(); });
  poll();
  return { poll };
}

// ---------- lock-screen notifications ----------
// Where this device stands (env: { supported, https, standalone, permission,
// subscribed }): on, off (can be turned on), blocked, or why it can't be here.
// iOS shows web notifications only from a Home Screen app, and only over HTTPS.
export function pushState(env) {
  if (!env?.https) return 'not-https';
  if (!env.standalone) return 'not-home-screen';
  if (!env.supported) return 'unsupported';
  if (env.permission === 'denied') return 'blocked';
  return env.subscribed ? 'on' : 'off';
}

// The box at the top of the phone's bell list: "Turn on notifications", or why not.
export function pushBoxHtml(env) {
  const at = env?.httpsUrl ? `<b>${esc(env.httpsUrl)}</b>` : "the Project Manager's HTTPS address (Tailscale Serve)";
  const busy = env?.busy ? ' disabled' : '';
  const err = env?.error ? `<div class="pusherr">${esc(env.error)}</div>` : '';
  const body = {
    'not-https': `Lock-screen notifications need the Home Screen app made from ${at}: open it in Safari, tap Share, then Add to Home Screen, and open the Project Manager from there.`,
    'not-home-screen': 'Lock-screen notifications work only in the Home Screen app: tap Share, then Add to Home Screen, and open the Project Manager from there to turn them on.',
    unsupported: "This browser can't show lock-screen notifications (an iPhone needs iOS 16.4 or later).",
    blocked: 'Notifications are blocked for the Project Manager. Allow them in Settings, Notifications, Project Manager, then come back here.',
    on: `Lock-screen notifications are on; they arrive while Away is on. <button class="btn small ghost" data-push="off"${busy}>Turn off</button>`,
    off: `<button class="btn small primary" data-push="on"${busy}>Turn on notifications</button> They arrive on the lock screen only while Away is on.`,
  }[pushState(env)];
  return `<div class="pushbox">${body}${err}</div>`;
}

const fromB64u = (s) => {
  const b = atob(String(s).replace(/-/g, '+').replace(/_/g, '/'));
  return Uint8Array.from(b, (c) => c.charCodeAt(0));
};

// Lock-screen notifications on this device, for mountBell's push: registers
// the service worker (/sw.js), keeps the board told of this device's
// subscription, and turns them on or off (act('on' | 'off'), from a tap: iOS
// asks for permission only then).
export function mountPush({ post }) {
  const env = {
    supported: 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window,
    https: location.protocol === 'https:',
    standalone: navigator.standalone === true || matchMedia('(display-mode: standalone)').matches,
    permission: window.Notification?.permission ?? 'default',
    subscribed: false, httpsUrl: null, publicKey: null, busy: false, error: null,
  };
  let reg = null;
  let changed = () => {};
  async function refresh() {
    try { const d = await (await fetch('/push', { cache: 'no-store' })).json(); env.httpsUrl = d.https; env.publicKey = d.publicKey; } catch { /* next time */ }
    if (env.supported && env.https) {
      try {
        reg = await navigator.serviceWorker.register('/sw.js');
        const sub = await reg.pushManager.getSubscription();
        env.subscribed = !!sub;
        if (sub) await post('/push/subscribe', { subscription: sub.toJSON() });
      } catch { /* shown as off */ }
    }
    env.permission = window.Notification?.permission ?? 'default';
    changed();
  }
  async function act(what) {
    env.error = null;
    try {
      if (what === 'on') {
        const permission = await Notification.requestPermission();
        env.permission = permission;
        if (permission === 'granted') {
          env.busy = true; changed();
          reg ??= await navigator.serviceWorker.register('/sw.js');
          await navigator.serviceWorker.ready;
          const sub = await reg.pushManager.getSubscription()
            ?? await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: fromB64u(env.publicKey) });
          await post('/push/subscribe', { subscription: sub.toJSON() });
          env.subscribed = true;
        }
      } else if (what === 'off') {
        env.busy = true; changed();
        const sub = await reg?.pushManager.getSubscription();
        if (sub) { await post('/push/unsubscribe', { endpoint: sub.endpoint }); await sub.unsubscribe(); }
        env.subscribed = false;
      }
    } catch (err) { env.error = `Couldn't turn notifications ${what}: ${err.message}`; }
    env.busy = false;
    changed();
  }
  refresh();
  document.addEventListener('visibilitychange', () => { if (!document.hidden) refresh(); });
  return { html: () => pushBoxHtml(env), act, onChange: (fn) => { changed = fn; } };
}

// Brings a held item's card (or its session's group) into view in the
// Questions tab once it is drawn, and flashes it.
export function revealQuestion(root, { item, session }, tries = 20) {
  const el = (item && root.querySelector(`.pcard[data-pid="${CSS.escape(item)}"]`))
    || (session && root.querySelector(`.qgroup[data-session="${CSS.escape(session)}"]`));
  if (!el) { if (tries > 0) setTimeout(() => revealQuestion(root, { item, session }, tries - 1), 150); return; }
  el.scrollIntoView({ behavior: 'smooth', block: 'center' });
  el.classList.add('flash');
  setTimeout(() => el.classList.remove('flash'), 1600);
}

// Refreshes every "5 min ago" under root from its data-t.
export function refreshTimes(root) {
  for (const el of root.querySelectorAll('[data-t]')) if (el.dataset.t) el.textContent = ago(Number(el.dataset.t));
}
