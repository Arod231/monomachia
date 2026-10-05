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
  return `<div class="pcard" data-pid="${esc(p.id)}"><div class="ch"><i class="sw owner"></i><b>Finished its turn and is waiting for your reply</b>${when}</div>
    <div class="m">Type below and send. It waits up to 20 minutes, then goes idle; meanwhile the app shows it as working.</div>
    <div class="row">${back}</div></div>`;
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

// Refreshes every "5 min ago" under root from its data-t.
export function refreshTimes(root) {
  for (const el of root.querySelectorAll('[data-t]')) if (el.dataset.t) el.textContent = ago(Number(el.dataset.t));
}
