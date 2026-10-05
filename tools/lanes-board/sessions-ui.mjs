// How both Project Manager pages draw sessions and what they wait on: a
// session's pills, the questions, permission prompts and turn ends the relay
// hands over, and a little Markdown. index.html and m.html load it from
// /sessions-ui.mjs; tests/lanes-board-sessions-ui.test.mjs checks it. Everything
// returns data or HTML, with every value from a session escaped; only picksOf
// reads the DOM, from a card the page hands it.

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
    pills.push(`<span class="pill need">${p.kind === 'permission' ? `Approve ${esc(p.tool)}` : p.kind === 'question' ? 'Asking you' : 'Waiting for your reply'}</span>`);
  }
  if (s.asking && !s.pending.some((p) => p.kind === 'question')) pills.push('<span class="pill need">Asking you (in the app)</span>');
  if (s.queued) pills.push('<span class="pill">Reply queued</span>');
  if (s.on) pills.push('<span class="pill">Answers from Project Manager</span>');
  return pills.length ? `<div class="pills">${pills.join('')}</div>` : '';
}

// A little Markdown: code blocks, inline code, bold, links.
export function md(text) {
  return String(text).split(/```[^\n]*\n?/).map((part, i) => {
    if (i % 2) return `<pre>${esc(part.replace(/\n$/, ''))}</pre>`;
    return esc(part)
      .replace(/`([^`\n]+)`/g, '<code>$1</code>')
      .replace(/\*\*([^*\n]+)\*\*/g, '<b>$1</b>')
      .replace(/\[([^\]\n]+)\]\((https?:\/\/[^)\s]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>')
      .replace(/\n/g, '<br>');
  }).join('');
}

// ---------- what a session waits on ----------
// p is a held item from the relay folder: { id, kind: question | permission |
// stop, tool, input, suggestions, time }.

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

// AskUserQuestion's questions; live: answerable here (else read-only).
export function questionsHtml(questions, live) {
  return questions.map((q, i) => `<div class="q" data-qi="${i}" data-multi="${q.multiSelect ? 1 : 0}">
      <div class="qh">${q.header ? `<span class="chip">${esc(q.header)}</span>` : ''}${esc(q.question)}${q.multiSelect ? ' <span class="m">(pick any)</span>' : ''}</div>
      <div class="opts">${(q.options ?? []).map((o) => `<button class="opt" data-label="${esc(o.label)}" ${live ? '' : 'disabled'}><b>${esc(o.label)}</b>${o.description ? `<span>${esc(o.description)}</span>` : ''}</button>`).join('')}
      ${live ? `<input class="text other" placeholder="Other: type your own answer">` : ''}</div></div>`).join('');
}

export function pendingCard(p) {
  const when = `<span class="k">${esc(ago(p.time))}</span>`;
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
  if (p.kind === 'question') {
    return `<div class="pcard" data-pid="${esc(p.id)}"><div class="ch"><i class="sw owner"></i><b>Asks you</b>${when}</div>
      ${questionsHtml(p.input?.questions ?? [], true)}
      <div class="row"><button class="btn primary" data-answer="${esc(p.id)}">Send answer${(p.input?.questions ?? []).length > 1 ? 's' : ''}</button>${back}</div></div>`;
  }
  return `<div class="pcard" data-pid="${esc(p.id)}"><div class="ch"><i class="sw owner"></i><b>Finished its turn and is waiting for your reply</b>${when}</div>
    <div class="m">Type below and send. It waits up to 20 minutes, then goes idle; meanwhile the app shows it as working.</div>
    <div class="row">${back}</div></div>`;
}

// The picks of a question card's buttons and Other boxes, in relayAnswer's
// shape (one list per question), read from the DOM by the page.
export function picksOf(card) {
  return [...card.querySelectorAll('.q')].map((q) => {
    const chosen = [...q.querySelectorAll('.opt.on')].map((o) => o.dataset.label);
    const other = q.querySelector('.other')?.value.trim();
    if (other) chosen.push(other);
    return q.dataset.multi === '1' ? chosen : chosen.slice(-1);
  });
}
