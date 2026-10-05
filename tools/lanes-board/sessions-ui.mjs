// How both Project Manager pages draw sessions and what they wait on: a
// session's pills, the Away switch, the Questions tab with the questions,
// permission prompts and turn ends the relay hands over, and a little Markdown. index.html and m.html load it from
// /sessions-ui.mjs; tests/lanes-board-sessions-ui.test.mjs checks it. Everything
// returns data or HTML, with every value from a session escaped; the last
// section works on cards the page hands it, so both pages answer alike.

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

// ---------- the Away switch and the Questions tab ----------
// q is /questions (sessions-api.mjs): { away: { on, since, from }, count,
// groups: [{ session, app, title, cwd, task, since, items }], asked: [...] }.

// The switch both pages show in their header, with what's waiting.
export function awayHtml(q) {
  const on = !!q?.away?.on;
  const n = q?.count ?? 0;
  const title = on ? `Away since ${new Date(q.away.since).toLocaleString([], { weekday: 'short', hour: '2-digit', minute: '2-digit' })}${q.away.from ? `, switched on from the ${q.away.from}` : ''}: sessions' questions, prompts and turn ends wait in the Questions tab`
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
    <div class="row">${a.app ? `<button class="btn small" data-open="${esc(a.app)}">${esc(openLabel)}</button>` : ''}<span class="m">${q.away.on ? 'It asked before Away was on, so it waits in the app.' : 'Away is off, so it waits in the app.'}</span></div></div></section>`);
  if (!held.length && !asked.length) {
    return `<div class="empty">${q.away.on ? 'Nothing waiting. Questions, permission prompts and finished turns from every session land here while Away is on.'
      : "Nothing waiting. Away is off, so sessions ask in the app's own dialogs; switch Away on before you leave the PC and they wait here instead."}</div>`;
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
  if (!records.length) return '<div class="bempty">Nothing yet. Questions, plans, permission prompts and finished turns from every session show here.</div>';
  return `<div class="bhead"><b>Notifications</b>${b.unread ? '<button class="btn small ghost" data-bell-all>Mark all read</button>' : ''}</div>
    <ul class="blist">${records.map((r) => `<li class="brec${r.read ? '' : ' unread'}" data-bell="${esc(r.id)}" data-tab="${esc(r.target?.tab)}"`
      + `${r.target?.item ? ` data-item="${esc(r.target.item)}"` : ''} data-session="${esc(r.target?.session)}">`
      + `<div class="bt">${esc(r.text)}</div>${r.detail ? `<div class="bd">${esc(r.detail)}</div>` : ''}`
      + `<div class="k" data-t="${Number(r.time) || ''}">${esc(ago(r.time))}</div></li>`).join('')}</ul>`;
}

// Runs the bell on a page: box holds its button, panel its list (hidden until
// opened); post(url, body) is the page's JSON post; go({ tab, item, session })
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
    go({ tab: rec.dataset.tab, item: rec.dataset.item ?? null, session: rec.dataset.session || null });
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
