// How both Project Manager pages draw sessions: a session's pills and page,
// the Away switch (lock-screen notifications), the bell, and a little
// Markdown. Nothing here answers a session: since Oct 6 (owner's choice) its
// questions, permission prompts and plans are answered in the Claude app, and
// pull requests are merged on GitHub or by a session told to. index.html and
// m.html load it from /sessions-ui.mjs; tests/lanes-board-sessions-ui.test.mjs
// checks it. Most of it returns data or HTML, with every value from a session
// escaped. The mount* functions act on the page itself (fetch, post, run
// their own timers and listeners); the pages check those by hand.

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

export const sessionNeeds = (s) => !!s.asking;
export const needsLabel = (s) => (s.asking ? 'Asking you (in the app)' : '');

export function sessionPills(s) {
  const pills = [];
  if (s.asking) pills.push('<span class="pill need">Asking you (in the app)</span>');
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

// ---------- what a session asks in the app ----------

// AskUserQuestion's questions, read-only: they are answered in the app. An
// option's preview (a mockup) is shown as monospace text, never as HTML.
export function questionsHtml(questions) {
  return questions.map((q, i) => `<div class="q" data-qi="${i}" data-multi="${q.multiSelect ? 1 : 0}">
      <div class="qh">${q.header ? `<span class="chip">${esc(q.header)}</span>` : ''}${esc(q.question)}${q.multiSelect ? ' <span class="m">(pick any)</span>' : ''}</div>
      <div class="opts">${(q.options ?? []).map((o) => `<button class="opt" data-label="${esc(o.label)}" disabled><b>${esc(o.label)}</b>${o.description ? `<span>${esc(o.description)}</span>` : ''}${o.preview ? `<pre class="code pv">${esc(o.preview)}</pre>` : ''}</button>`).join('')}
      </div></div>`).join('');
}

// What the page says once a reply or command is sent (`when` from the server).
export function deliveredNote(when) {
  return when === 'next-step' ? 'Sent: it gets this before its next step.' : 'Queued: it gets this when its turn next ends.';
}

// ---------- the session page ----------
// d is a session from /sessions or /session (sessions-api.mjs), with its state
// (sessions.mjs sessionState), turn summary, branch, task and pull request.

export const STATE_LABELS = { asked: 'Asked in the app', ended: 'Ended', working: 'At work', idle: 'Idle' };

export function stateHtml(d) {
  const state = STATE_LABELS[d.state] ? d.state : 'idle';
  const label = d.stopping ? 'Stopping' : STATE_LABELS[state];
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

// Show me, Stop now, Compact, Open in the Claude app and End work (End work
// asks first). No Approve or Merge: approvals are given in the Claude app, and
// pull requests merged on GitHub or by a session told to.
export function commandBarHtml(d) {
  const off = (yes) => (yes ? ' disabled' : '');
  return `<div class="cmds" data-session="${esc(d.id)}">`
    + `<button class="btn small" data-cmd="show">Show me</button>`
    + `<button class="btn small" data-cmd="stop"${off(d.stopping)}>Stop now</button>`
    + `<button class="btn small" data-cmd="compact">Compact</button>`
    + (d.remote ? `<a class="btn small" href="${esc(d.remote)}" target="_blank" rel="noopener">Open in the Claude app</a>`
      : `<button class="btn small" data-cmd="app">Open in the Claude app</button>`)
    + `<button class="btn small danger" data-cmd="end"${off(d.state === 'ended')}>End work</button></div>`;
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

// What the page says once a command is sent (`when` from the server).
export function commandNote(command, when) {
  if (command === 'stop') {
    return { 'next-step': 'Stop now sent: it stops before its next step and ends its turn.',
      idle: "It isn't working: there's nothing to stop." }[when] ?? 'Stop now sent.';
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

// Images of the work (d.workImages, work-images.mjs): renders it opened from
// its shots folder and viewport shots, newest first, in the same viewer.
export function workImagesHtml(images) {
  if (!images?.length) return '';
  const items = images.map((v, i) => `<figure class="vis" data-work="${i}"><img src="${esc(v.url)}" alt="${esc(v.caption)}" loading="lazy">`
    + `<figcaption>${esc(v.caption)}<span class="k"> · ${esc(ago(v.time))}</span></figcaption></figure>`);
  return `<div class="sh"><h2>Images of the work</h2><span class="m">${images.length}</span></div><div class="vgrid">${items.join('')}</div>`;
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
    // Hides it at once, leaving history alone (another session was opened).
    dismiss() { box.hidden = true; box.innerHTML = ''; },
  };
}

// ---------- Docs ----------
// /docs (docs-api.mjs): the documents a session wrote, its pull request and
// the artifacts it published. Markdown is rendered with the second brain's
// library (marked, served at /marked.js), with any HTML in it shown as text
// and only web links kept, so a document can't act as the Project Manager.

export function docHtml(text, marked) {
  const m = new marked.Marked({ gfm: true });
  m.use({ renderer: {
    html: ({ text: t }) => esc(t),
    link({ href, title, tokens }) {
      const inner = this.parser.parseInline(tokens);
      return /^(https?:|mailto:|#)/i.test(href ?? '')
        ? `<a href="${esc(href)}"${title ? ` title="${esc(title)}"` : ''} target="_blank" rel="noopener">${inner}</a>` : inner;
    },
    image: ({ href, text: alt }) => (/^https:/i.test(href ?? '') ? `<img src="${esc(href)}" alt="${esc(alt)}" loading="lazy">` : esc(alt)),
  } });
  return m.parse(String(text ?? ''));
}

const KIND_LABEL = { md: 'Markdown', html: 'HTML page', pdf: 'PDF' };
export const docUrl = (session, file) => `/doc?session=${session}&path=${encodeURIComponent(file)}`;

function prHtml(pr, marked) {
  const state = pr.draft ? 'draft' : String(pr.state ?? '').toLowerCase();
  const checks = pr.checks.length ? `<ul class="checks">${pr.checks.map((c) => {
    const s = String(c.state).toUpperCase();
    const cls = ['SUCCESS', 'NEUTRAL', 'SKIPPED'].includes(s) ? 'ok' : ['FAILURE', 'ERROR', 'CANCELLED', 'TIMED_OUT', 'ACTION_REQUIRED'].includes(s) ? 'bad' : 'wait';
    return `<li class="${cls}">${esc(c.name)} <span class="k">${esc(s.toLowerCase().replace(/_/g, ' '))}</span></li>`;
  }).join('')}</ul>` : '<div class="k">No checks.</div>';
  const shown = pr.files.slice(0, 40);
  const files = `<ul class="pfiles">${shown.map((f) => `<li><code>${esc(f.path)}</code> <span class="k">+${Number(f.additions)} −${Number(f.deletions)}</span></li>`).join('')}`
    + `${pr.files.length > shown.length ? `<li class="k">and ${pr.files.length - shown.length} more</li>` : ''}</ul>`;
  const body = pr.body?.trim() ? (marked ? `<div class="mdoc">${docHtml(pr.body, marked)}</div>` : `<pre class="code">${esc(pr.body)}</pre>`) : '<div class="k">No description.</div>';
  return `<details class="prbox"><summary><a href="${esc(pr.url)}" target="_blank" rel="noopener">PR #${Number(pr.number)}</a> ${esc(pr.title)}`
    + ` <span class="k">${esc(state)} · ${esc(pr.head)} into ${esc(pr.base)} · +${Number(pr.additions)} −${Number(pr.deletions)}</span></summary>`
    + `<h4 class="mdh">Checks</h4>${checks}<h4 class="mdh">Changed files (${pr.files.length})</h4>${files}<h4 class="mdh">Description</h4>${body}</details>`;
}

// d: /docs; session: its id; marked: the library, when loaded.
export function docsHtml(d, session, { marked = null } = {}) {
  if (!d || (!d.docs?.length && !d.artifacts?.length && !d.pr)) return '';
  const docs = d.docs.map((x, i) => {
    const where = `<span class="k">${esc([KIND_LABEL[x.kind], x.dir, ago(x.time)].filter(Boolean).join(' · '))}</span>`;
    return x.kind === 'md' ? `<li><button class="dlink" data-doc="${i}">${esc(x.name)}</button> ${where}</li>`
      : `<li><a class="dlink" href="${esc(docUrl(session, x.path))}" target="_blank" rel="noopener">${esc(x.name)}</a> ${where}</li>`;
  });
  const arts = d.artifacts.map((a) => `<li><a href="${esc(a.url)}" target="_blank" rel="noopener">${esc(a.title)}</a> <span class="k">artifact · ${esc(ago(a.time))}</span></li>`);
  return `<div class="sh"><h2>Docs</h2></div>${d.pr ? prHtml(d.pr, marked) : ''}`
    + `${docs.length || arts.length ? `<ul class="dlist">${docs.join('')}${arts.join('')}</ul>` : ''}`;
}

const READER_CSS = `
.dlist{list-style:none;padding:0;margin:6px 0 14px}.dlist li{padding:6px 0;border-bottom:1px solid #8882}
.dlink{background:none;border:0;padding:0;font:inherit;color:inherit;text-decoration:underline;cursor:pointer;text-align:left}
.prbox{margin:6px 0 10px}.prbox summary{cursor:pointer}.prbox .checks,.prbox .pfiles{list-style:none;padding:0;margin:4px 0}
.prbox .checks li::before{content:'● '}.prbox .checks .ok::before{color:#2a8a3e}.prbox .checks .bad::before{color:#c4302b}.prbox .checks .wait::before{color:#c58a00}
.mdoc{overflow-wrap:anywhere;line-height:1.5}.mdoc pre{overflow:auto;padding:8px;background:#8881;border-radius:6px}.mdoc table{border-collapse:collapse;display:block;overflow:auto}
.mdoc td,.mdoc th{border:1px solid #8884;padding:3px 6px}.mdoc img{max-width:100%}
.reader{position:fixed;inset:0;z-index:1000;background:var(--page,#fff);color:var(--text,#111);display:flex;flex-direction:column}
.reader[hidden]{display:none}
.reader .rbar{display:flex;gap:10px;align-items:center;padding:calc(env(safe-area-inset-top) + 6px) 12px 6px;border-bottom:1px solid #8883}
.reader .rbar b{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.reader .rbody{flex:1;overflow:auto;padding:12px 16px calc(env(safe-area-inset-bottom) + 16px);-webkit-overflow-scrolling:touch}
.reader .rbtn{background:#8882;color:inherit;border:0;border-radius:8px;padding:7px 11px;font-size:15px;cursor:pointer}`;

// The full-screen reader of a session's Markdown documents, shared by both
// pages: open(session, doc) fetches it and renders it; Back (or the phone's
// back gesture) closes it.
export function mountReader({ marked = () => window.marked } = {}) {
  const style = document.createElement('style');
  style.textContent = READER_CSS;
  document.head.append(style);
  const box = document.createElement('div');
  box.className = 'reader';
  box.hidden = true;
  document.body.append(box);
  const hide = () => { box.hidden = true; box.innerHTML = ''; };
  function close() { if (box.hidden) return; if (history.state?.reader) history.back(); else hide(); }
  window.addEventListener('popstate', (e) => { if (!e.state?.reader && !box.hidden) hide(); });
  box.addEventListener('click', (e) => { if (e.target.closest('[data-reader-close]')) close(); });
  document.addEventListener('keydown', (e) => { if (!box.hidden && e.key === 'Escape') close(); });
  return {
    async open(session, doc) {
      if (box.hidden) history.pushState({ ...(history.state ?? {}), reader: true }, '', location.href);
      box.hidden = false;
      box.innerHTML = `<div class="rbar"><button class="rbtn" data-reader-close>‹ Back</button><b>${esc(doc.name)}</b></div>`
        + '<div class="rbody"><div class="k">Loading…</div></div>';
      const body = box.querySelector('.rbody');
      try {
        const r = await fetch(docUrl(session, doc.path), { cache: 'no-store' });
        const text = await r.text();
        const from = r.headers.get('x-doc-from');
        body.innerHTML = r.ok
          ? `${from ? `<div class="k">From ${esc(from)}</div>` : ''}<div class="mdoc">${marked() ? docHtml(text, marked()) : `<pre class="code">${esc(text)}</pre>`}</div>`
          : `<p>${esc(text)}</p>`;
      } catch (err) { body.innerHTML = `<p>Couldn't load it: ${esc(err.message)}</p>`; }
    },
    close,
    // Hides it at once, leaving history alone (another session was opened).
    dismiss: hide,
  };
}

// ---------- the Away switch ----------
// away is /away (sessions-api.mjs): { on, since, from }. While it's on, the
// bell's news reaches the lock screen of every phone that turned
// notifications on; it holds nothing back from the app.

// The switch both pages show in their header.
export function awayHtml(away) {
  const on = !!away?.on;
  const title = on ? `Away since ${new Date(away.since).toLocaleString([], { weekday: 'short', hour: '2-digit', minute: '2-digit' })}${away.from ? `, switched on from the ${away.from}` : ''}: the bell's news goes to your phone's lock screen`
    : "Away is off: the bell's news stays on these pages. Switch it on before you leave the PC to get it on your phone's lock screen.";
  return `<label class="away${on ? ' on' : ''}" title="${esc(title)}"><input type="checkbox" data-away ${on ? 'checked' : ''}><span>Away</span></label>`;
}

// When the hooks installed in user settings aren't this version's (hooks.mjs):
// what's wrong, and the fix. hooks is /sessions' hooks: { current, problems }.
export function hooksNoticeHtml(hooks) {
  if (!hooks || hooks.current) return '';
  return `<div class="hookwarn"><b>The hooks in your user settings aren't this version's</b>, so replies, Stop now and the bell may not work as shown here.
    <ul>${hooks.problems.map((p) => `<li>${esc(p)}</li>`).join('')}</ul>
    To fix it, ask a session to run <code>npm run board:hooks</code> (it changes your user settings, so it asks you first).</div>`;
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
  if (!records.length) return '<div class="bempty">Nothing yet. Questions asked in the app, finished turns, pull requests ready to merge and new visuals from every session show here.</div>';
  return `<div class="bhead"><b>Notifications</b>${b.unread ? '<button class="btn small ghost" data-bell-all>Mark all read</button>' : ''}</div>
    <ul class="blist">${records.map((r) => `<li class="brec${r.read ? '' : ' unread'}" data-bell="${esc(r.id)}"`
      + `${r.target?.visuals ? ' data-visuals="1"' : ''} data-session="${esc(r.target?.session ?? r.session)}">`
      + `<div class="bt">${esc(r.text)}</div>${r.detail ? `<div class="bd">${esc(r.detail)}</div>` : ''}`
      + `<div class="k" data-t="${Number(r.time) || ''}">${esc(ago(r.time))}</div></li>`).join('')}</ul>`;
}

// Runs the bell on a page: box holds its button, panel its list (hidden until
// opened); post(url, body) is the page's JSON post; go({ session, visuals })
// takes the page to a record's session. Polls /bell every few seconds.
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
    go({ session: rec.dataset.session || null, visuals: rec.dataset.visuals === '1' });
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

// Refreshes every "5 min ago" under root from its data-t.
export function refreshTimes(root) {
  for (const el of root.querySelectorAll('[data-t]')) if (el.dataset.t) el.textContent = ago(Number(el.dataset.t));
}
