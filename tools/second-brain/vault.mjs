// Builds the second brain: an Obsidian vault of the project's knowledge
// (docs/specs/second-brain.md). Pure: it reads only through the source it's
// given and returns notes, so the board, the standalone server and the tests
// can all build the same vault from a git ref or a working tree.
//
// A source has list() (repo paths, posix), read(path) (text) and subjects()
// ([{ subject, files }], newest first). buildVault returns the hand-written
// notes under brain/ plus the generated ones under brain/generated/.

export const VAULT = 'brain';
export const GENERATED = `${VAULT}/generated`;

// Labels for the main docs; any other doc is named after its first heading.
const DOC_LABELS = {
  'README.md': 'README',
  'docs/design.md': 'Design doc',
  'docs/mvp-spec.md': 'MVP spec',
  'docs/specs/godot-rebuild.md': 'Rebuild spec',
  'docs/plans/godot-rebuild.md': 'Rebuild plan',
};

// Glossary terms too common to be worth a "Mentions" link everywhere.
const COMMON_TERMS = new Set(['fighter', 'weapon', 'round', 'match', 'block', 'arena', 'counter', 'flash', 'gate', 'lock in']);

const ID = String.raw`\d+b?(?:\.\d+)?|[A-Z]{1,4}\.\d+`;

// ---------------------------------------------------------------- parsers

/** Plain text of a heading or label: no Markdown emphasis or code marks. */
export function plain(s) {
  return s.replace(/\[([^\]]*)\]\([^)]*\)/g, '$1').replace(/[*_`]/g, '').replace(/\s+/g, ' ').trim();
}

/**
 * A name Obsidian accepts as a file name and a link target, at most about 80
 * characters so paths stay under Windows limits. `raw` keeps Markdown marks (for
 * code paths like moonlit_shrine).
 */
export function safeName(s, raw = false) {
  let name = (raw ? s : plain(s))
    .replace(/:\s*/g, ' - ')
    .replace(/[\\/*?"<>|#^[\]]/g, '-')
    .replace(/\s+/g, ' ')
    .trim();
  if (name.length > 80 && name.indexOf(' (') > 40) name = name.slice(0, name.indexOf(' ('));
  if (name.length > 80) name = name.slice(0, name.lastIndexOf(' ', 80));
  return name.replace(/[\s.,;-]+$/, '');
}

/** Task ids a commit subject names: "(task 7.1)", "(godot-rebuild 22.6, 22.8-22.10, first step)". */
export function taskIdsInSubject(subject) {
  const ids = [];
  for (const [, inner] of subject.matchAll(/\(([^)]*)\)/g)) {
    if (!/^\s*(tasks?|godot-rebuild)\b/i.test(inner)) continue;
    const rest = inner.replace(/^\s*(tasks?|godot-rebuild)\b/i, '');
    for (const m of rest.matchAll(/(\d+b?)\.(\d+)\s*[-–]\s*(\d+b?)\.(\d+)|(\d+b?(?:\.\d+)?)/g)) {
      if (m[5]) ids.push(m[5]);
      else if (m[1] === m[3]) for (let i = +m[2]; i <= +m[4]; i++) ids.push(`${m[1]}.${i}`);
      else ids.push(`${m[1]}.${m[2]}`, `${m[3]}.${m[4]}`);
    }
  }
  return [...new Set(ids)];
}

/** GLOSSARY.md entries: one per term, so "Light attack / Heavy attack" gives two. */
export function parseGlossary(md) {
  const entries = [];
  let section = '';
  const lines = md.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const h = /^##\s+(.+)/.exec(lines[i]);
    if (h) { section = plain(h[1]); continue; }
    if (!/^\*\*[^*]+\*\*(\s*\/\s*\*\*[^*]+\*\*)*:\s*$/.test(lines[i])) continue;
    const terms = [...lines[i].matchAll(/\*\*([^*]+)\*\*/g)].map((m) => m[1].trim());
    const definition = [];
    let avoid = '';
    for (i++; i < lines.length && lines[i].trim(); i++) {
      const a = /^_Avoid_:\s*(.*)/.exec(lines[i]);
      if (a) avoid = a[1].trim();
      else definition.push(lines[i].trim());
    }
    for (const term of terms) {
      entries.push({ term, section, definition: definition.join(' '), avoid, also: terms.filter((t) => t !== term) });
    }
  }
  return entries;
}

/**
 * A Markdown doc split at its top level of headings below the title: `##` in
 * most docs, `###` in one whose only `##` headings are absent.
 */
export function splitSections(md) {
  const lines = md.split(/\r?\n/);
  const headings = [];
  let fence = false;
  lines.forEach((line, i) => {
    if (/^\s*(```|~~~)/.test(line)) fence = !fence;
    const m = !fence && /^(#{1,6})\s+(.+?)\s*#*\s*$/.exec(line);
    if (m) headings.push({ i, level: m[1].length, text: m[2] });
  });
  const h1 = headings.find((h) => h.level === 1);
  const levels = headings.filter((h) => h.level > 1).map((h) => h.level);
  const level = levels.length ? Math.min(...levels) : 0;
  const tops = headings.filter((h) => h.level === level);
  const introStart = h1 ? h1.i + 1 : 0;
  const intro = lines.slice(introStart, tops.length ? tops[0].i : lines.length).join('\n').trim();
  const sections = tops.map((h, k) => ({
    heading: plain(h.text),
    level,
    body: lines.slice(h.i + 1, k + 1 < tops.length ? tops[k + 1].i : lines.length).join('\n').trim(),
  }));
  return { title: h1 ? plain(h1.text) : null, intro, sections };
}

/** A GDScript file's class, base and one-line purpose from its doc comment. */
export function parseScriptSummary(gd) {
  const lines = gd.split(/\r?\n/);
  const className = lines.map((l) => /^class_name\s+(\w+)/.exec(l)?.[1]).find(Boolean) ?? null;
  const base = lines.map((l) => /^extends\s+(\S+)/.exec(l)?.[1]).find(Boolean) ?? null;
  // The first comment block: `##` doc comments, or plain `#` ones in a script without them.
  let start = lines.findIndex((l) => /^##(\s|$)/.test(l));
  let mark = '##';
  if (start < 0) {
    start = lines.findIndex((l) => /^#(\s|$)/.test(l) && !/^#!/.test(l));
    mark = '#';
    if (start < 0 || lines.slice(0, start).some((l) => /^(func|var|const|signal)\b/.test(l))) {
      return { className, base, summary: '', doc: '' };
    }
  }
  const block = [];
  for (let i = start; i < lines.length && lines[i].startsWith(mark) && (mark === '#' ? !lines[i].startsWith('##') : true); i++) {
    block.push(lines[i].slice(mark.length).replace(/^ /, ''));
  }
  const doc = block.join('\n').trim();
  const paragraphs = doc.split(/\n\s*\n/).map((p) => p.replace(/\s*\n\s*/g, ' ').trim()).filter(Boolean);
  let port = '';
  let para = paragraphs[0] ?? '';
  // "Port of v0.1-web-mvp:src/sim/fighter.ts." alone says nothing; "Port of the X interface in …: …" does, so it stays.
  const p = /^Port of (\S+\.(?:ts|js))\.(\s|$)/.exec(para);
  if (p) {
    port = p[1];
    const rest = para.slice(p[0].length).trim();
    para = rest || paragraphs[1] || '';
  }
  return { className, base, summary: firstSentence(para) + (port ? ` (port of ${port})` : ''), doc };
}

function firstSentence(s) {
  const m = /^(.+?[.!?])(\s+(?=[A-Z(`"])|$)/.exec(s);
  return (m ? m[1] : s).trim();
}

/**
 * A plan's tasks (`- [x] **ID Title**` lines and their sub-bullets; a retired
 * task is `- [-] ~~**ID Title**~~`) and, when it has a "Build order", its
 * stages with id ranges expanded.
 */
export function parsePlan(md) {
  const lines = md.split(/\r?\n/);
  const tasks = [];
  let section = '';
  let phase = '';
  const taskLine = new RegExp(String.raw`^(\s*)- \[([ xX-])\] (?:~~)?\*\*(${ID})[.:]?\s+(.*?)\*\*(?:~~)?(.*)$`);
  for (let i = 0; i < lines.length; i++) {
    const h = /^(#{2,3})\s+(.+)/.exec(lines[i]);
    if (h) { if (h[1] === '##') { section = plain(h[2]); phase = ''; } else phase = plain(h[2]); continue; }
    if (section !== 'Tasks') continue;
    const m = taskLine.exec(lines[i]);
    if (!m) continue;
    const indent = m[1].length;
    const body = [];
    let j = i + 1;
    for (; j < lines.length; j++) {
      const l = lines[j];
      if (!l.trim()) { body.push(''); continue; }
      if (/^#{1,6}\s/.test(l) || taskLine.test(l) || l.search(/\S/) <= indent) break;
      body.push(l.slice(indent + 2));
    }
    const text = body.join('\n').trim();
    const blocked = /^\s*- Blocked by:\s*(.*)$/m.exec(text)?.[1] ?? '';
    tasks.push({
      id: m[3],
      title: plain(m[4]).replace(/[.:]$/, ''),
      lead: plain(m[5]),
      done: m[2].toLowerCase() === 'x',
      retired: m[2] === '-',
      parent: indent > 0 ? tasks.findLast((t) => t.depth === 0)?.id ?? null : null,
      depth: indent > 0 ? 1 : 0,
      phase,
      text,
      blockedByText: blocked,
      waitsOnOwner: /owner'?s OK/i.test(blocked),
    });
    i = j - 1;
  }
  const order = tasks.map((t) => t.id);
  const known = new Set(order);
  for (const t of tasks) t.blockedBy = idsIn(t.blockedByText.split(' · ')[0].replace(/\([^)]*\)/g, ''), order).filter((id) => known.has(id) && id !== t.id);

  const stages = [];
  const build = md.split(/^## Build order\s*$/m)[1]?.split(/^## /m)[0] ?? '';
  for (const m of build.matchAll(/^(\d+)\.\s+\*\*(.+?):?\*\*:?\s*(.*)$/gm)) {
    stages.push({ n: +m[1], name: plain(m[2]).replace(/:$/, ''), ids: idsIn(m[3].replace(/\([^)]*\)/g, ''), order) });
  }
  return { tasks, stages };
}

/** Ids in a list like "16.1–16.7, 14.1, then 18.12", ranges expanded in plan order. */
function idsIn(text, order) {
  const out = [];
  const re = new RegExp(String.raw`(${ID})(?:\s*[–-]\s*(${ID}))?`, 'g');
  for (const m of text.matchAll(re)) {
    const a = order.indexOf(m[1]);
    const b = m[2] ? order.indexOf(m[2]) : -1;
    if (m[2] && a >= 0 && b >= a) out.push(...order.slice(a, b + 1));
    else out.push(m[1], ...(m[2] ? [m[2]] : []));
  }
  return [...new Set(out)];
}

// ------------------------------------------------------------------ links

/** Link targets in a note: `[[Name]]`, `[[Name|label]]`, `[[Name#Heading]]`, not inside code. */
export function linksIn(text) {
  const prose = text.replace(/```[\s\S]*?```/g, '').replace(/`[^`\n]*`/g, '');
  return [...prose.matchAll(/(?<!!)\[\[([^\]|#]*)(?:#[^\]|]*)?(?:\|[^\]]*)?\]\]/g)].map((m) => m[1].trim()).filter(Boolean);
}

/** Links resolve by note name, ignoring case and any folder, as in Obsidian. */
export function resolveLinks(notes) {
  const byName = new Map(notes.map((n) => [n.name.toLowerCase(), n]));
  const out = [];
  for (const n of notes) {
    for (const target of linksIn(n.text)) {
      const name = target.split('/').pop().replace(/\.md$/i, '').toLowerCase();
      out.push({ from: n.name, target, to: byName.get(name)?.name ?? null });
    }
  }
  return out;
}

// ---------------------------------------------------------------- builder

export function buildVault(source) {
  const files = source.list().slice().sort();
  const has = new Set(files);
  const notes = [];
  const names = new Map(); // lower-case name -> name

  const handWritten = files.filter((f) => f.startsWith(`${VAULT}/`) && f.endsWith('.md') && !f.startsWith(`${GENERATED}/`) && !f.startsWith(`${VAULT}/.`));
  for (const path of handWritten) {
    const name = path.split('/').pop().slice(0, -3);
    names.set(name.toLowerCase(), name);
    notes.push({ path, name, text: source.read(path) });
  }
  const claim = (wanted, raw = false) => {
    let name = safeName(wanted, raw);
    for (let k = 2; names.has(name.toLowerCase()); k++) name = `${safeName(wanted, raw)} (${k})`;
    names.set(name.toLowerCase(), name);
    return name;
  };
  const emit = (folder, name, lines) => notes.push({ path: `${GENERATED}/${folder ? `${folder}/` : ''}${name}.md`, name, text: lines.filter((l) => l !== null).join('\n').replace(/\n{3,}/g, '\n\n').trim() + '\n' });
  const banner = (from) => `> Generated from ${from}. Don't edit: \`npm run brain\` rebuilds it.`;
  const link = (name, label) => `[[${name}${label && label !== name ? `|${label}` : ''}]]`;

  // Glossary: a note per term, and terms linked wherever a note mentions them.
  const glossary = has.has('GLOSSARY.md') ? parseGlossary(source.read('GLOSSARY.md')) : [];
  const termNote = new Map(glossary.map((g) => [g.term.toLowerCase(), claim(g.term)]));
  const glossaryHub = glossary.length ? claim('Glossary') : null;
  const termPatterns = glossary
    .filter((g) => !COMMON_TERMS.has(g.term.toLowerCase()))
    .map((g) => ({ name: termNote.get(g.term.toLowerCase()), re: new RegExp(String.raw`\b${g.term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(e?s)?\b`, 'i') }));
  const mentions = (text, self) => {
    const found = termPatterns.filter((t) => t.name !== self && t.re.test(text)).map((t) => link(t.name));
    return found.length ? `**Mentions:** ${found.join(' · ')}` : null;
  };
  const linkTerms = (text) => text.replace(/\*\*([^*]+)\*\*/g, (all, t) => (termNote.has(t.toLowerCase()) ? link(termNote.get(t.toLowerCase()), t) : all));

  // Names for docs, plans and code first, so any note can link any other.
  const docPaths = files.filter((f) => (f === 'README.md' || f.startsWith('docs/')) && f.endsWith('.md'));
  const docs = docPaths.map((path) => {
    const md = source.read(path);
    const split = splitSections(md);
    const notes = /^docs\/plans\/godot-rebuild-notes\/(.+)\.md$/.exec(path);
    const label = claim(DOC_LABELS[path] ?? (notes ? `Rebuild plan notes ${notes[1]}` : null) ?? split.title ?? untitledLabel(path));
    const plan = /^docs\/plans\/[^/]+\.md$/.test(path) && /^## Tasks\s*$/m.test(md) ? parsePlan(md) : null;
    return { path, label, split, plan, slug: path.split('/').pop().slice(0, -3) };
  });
  const docByPath = new Map(docs.map((d) => [d.path, d]));
  for (const d of docs) {
    d.sectionNames = d.split.sections.map((s) => (d.plan && s.heading === 'Tasks' ? null : claim(`${d.label} - ${s.heading}`)));
    if (!d.plan) continue;
    const prefix = d.slug === 'godot-rebuild' ? 'Task ' : `${d.slug} task `;
    d.taskName = new Map(d.plan.tasks.map((t) => [t.id, claim(`${prefix}${t.id}`)]));
    d.stageName = new Map(d.plan.stages.map((s) => [s.n, claim(`${d.slug === 'godot-rebuild' ? '' : `${d.slug} `}Stage ${s.n} - ${s.name.split(':')[0]}`)]));
  }
  const rebuild = docs.find((d) => d.plan && d.slug === 'godot-rebuild') ?? docs.find((d) => d.plan);

  const scripts = files.filter((f) => f.startsWith('game/') && f.endsWith('.gd') && !f.startsWith('game/addons/'));
  const folders = new Set();
  for (const s of scripts) {
    const parts = s.split('/').slice(0, -1);
    for (let k = 1; k <= parts.length; k++) folders.add(parts.slice(0, k).join('/'));
  }
  const folderName = new Map([...folders].sort().map((f) => [f, claim(f.replace(/\//g, '.'), true)]));
  const codeHub = folders.size ? claim('Code map') : null;

  // Which tasks touched which folder: "(task X.Y)" in commit subjects and doc comments.
  const tasksByFolder = new Map();
  const foldersByTask = new Map();
  const touch = (folder, id) => {
    if (!rebuild?.taskName.has(id) || !folderName.has(folder)) return;
    (tasksByFolder.get(folder) ?? tasksByFolder.set(folder, new Set()).get(folder)).add(id);
    (foldersByTask.get(id) ?? foldersByTask.set(id, new Set()).get(id)).add(folder);
  };
  for (const { subject, files: touched } of source.subjects()) {
    const ids = taskIdsInSubject(subject);
    if (!ids.length) continue;
    for (const f of touched) if (f.startsWith('game/')) for (const id of ids) touch(f.split('/').slice(0, -1).join('/'), id);
  }
  const scriptInfo = new Map(scripts.map((s) => [s, parseScriptSummary(source.read(s))]));
  for (const [s, info] of scriptInfo) for (const [, id] of info.doc.matchAll(/\btasks? (\d+b?\.\d+)/g)) touch(s.split('/').slice(0, -1).join('/'), id);

  // Relative links to other docs become wikilinks to their hub notes.
  const rewriteDocLinks = (text, from) => text.replace(/\[([^\]]+)\]\(([^)#\s]+\.md)(#[^)]*)?\)/g, (all, label, target) => {
    const dir = from.split('/').slice(0, -1);
    for (const part of target.split('/')) part === '..' ? dir.pop() : part !== '.' && dir.push(part);
    const d = docByPath.get(dir.join('/'));
    return d ? link(d.label, label) : all;
  });

  // ---- glossary notes
  if (glossaryHub) {
    const sections = [...new Set(glossary.map((g) => g.section))];
    emit('glossary', glossaryHub, [
      banner('`GLOSSARY.md`'), '', '# Glossary', '',
      'The words the design docs, specs and code use for the game\'s concepts.', '',
      ...sections.flatMap((s) => [`## ${s}`, '', ...glossary.filter((g) => g.section === s).map((g) => `- ${link(termNote.get(g.term.toLowerCase()))}: ${plain(g.definition).split(/(?<=\.)\s/)[0]}`), '']),
    ]);
    for (const g of glossary) {
      const name = termNote.get(g.term.toLowerCase());
      emit('glossary', name, [
        '---', 'tags: [glossary]', '---', '',
        banner(`\`GLOSSARY.md\` (${g.section})`), '', `# ${g.term}`, '',
        linkTerms(g.definition), '',
        g.avoid ? `**Avoid:** ${g.avoid}` : null,
        g.also.length ? `**See also:** ${g.also.map((t) => link(termNote.get(t.toLowerCase()))).join(' · ')}` : null,
        `**In:** ${link(glossaryHub)} › ${g.section}`,
      ]);
    }
  }

  // ---- doc hubs and section notes
  for (const d of docs) {
    const folder = `docs/${d.label}`;
    const stageList = d.plan?.stages.length
      ? ['## Stages', '', ...d.plan.stages.map((s) => `- ${link(d.stageName.get(s.n))}: ${s.ids.filter((id) => d.plan.tasks.find((t) => t.id === id)?.done).length} of ${s.ids.length} done`), '']
      : [];
    const phases = d.plan ? [...new Set(d.plan.tasks.map((t) => t.phase))] : [];
    const taskList = d.plan
      ? ['## Tasks', '', ...phases.flatMap((p) => [p ? `### ${p}` : null, '', ...d.plan.tasks.filter((t) => t.phase === p && t.depth === 0).map((t) => `- ${t.done ? '✓' : t.retired ? '–' : '○'} ${link(d.taskName.get(t.id))}: ${t.title}`), ''])]
      : [];
    emit(folder, d.label, [
      banner(`\`${d.path}\``), '', `# ${d.label}`, '',
      d.split.title && d.split.title !== d.label ? `*${d.split.title}*` : null, '',
      rewriteDocLinks(d.split.intro, d.path), '',
      d.split.sections.length ? '## Sections' : null, '',
      ...d.split.sections.map((s, k) => (d.sectionNames[k] ? `- ${link(d.sectionNames[k], s.heading)}` : null)),
      '',
      ...stageList,
      ...taskList,
    ]);
    d.split.sections.forEach((s, k) => {
      const name = d.sectionNames[k];
      if (!name) return;
      const prev = d.sectionNames.slice(0, k).filter(Boolean).pop();
      const next = d.sectionNames.slice(k + 1).find(Boolean);
      emit(folder, name, [
        banner(`\`${d.path}\``), '',
        `**In:** ${link(d.label)}${prev ? ` · **Previous:** ${link(prev)}` : ''}${next ? ` · **Next:** ${link(next)}` : ''}`, '',
        `# ${s.heading}`, '',
        rewriteDocLinks(s.body, d.path), '',
        mentions(s.body),
      ]);
    });
  }

  // ---- plan stages and tasks
  for (const d of docs.filter((x) => x.plan)) {
    const folder = `plan/${d.label}`;
    const byId = new Map(d.plan.tasks.map((t) => [t.id, t]));
    const stageOf = new Map();
    for (const s of d.plan.stages) for (const id of s.ids) if (!stageOf.has(id)) stageOf.set(id, s.n);
    const blocks = new Map();
    for (const t of d.plan.tasks) for (const b of t.blockedBy) (blocks.get(b) ?? blocks.set(b, []).get(b)).push(t.id);
    const tl = (id) => link(d.taskName.get(id));

    for (const s of d.plan.stages) {
      const ts = s.ids.map((id) => byId.get(id)).filter(Boolean);
      emit(folder, d.stageName.get(s.n), [
        '---', 'tags: [stage]', '---', '',
        banner(`the build order in \`${d.path}\``), '',
        `**Plan:** ${link(d.label)} · ${ts.filter((t) => t.done).length} of ${ts.length} tasks done`, '',
        `# Stage ${s.n}: ${s.name}`, '',
        ...ts.map((t) => `- ${t.done ? '✓' : t.retired ? '–' : '○'} ${tl(t.id)}: ${t.title}`),
      ]);
    }
    for (const t of d.plan.tasks) {
      const subtasks = d.plan.tasks.filter((x) => x.parent === t.id);
      const stage = stageOf.get(t.id);
      emit(`${folder}/tasks`, d.taskName.get(t.id), [
        '---', `tags: [task, ${t.done ? 'done' : t.retired ? 'retired' : 'todo'}]`, '---', '',
        banner(`\`${d.path}\``), '',
        [`**Status:** ${t.done ? 'done ✓' : t.retired ? 'retired' : 'to do'}`,
          stage ? `**Stage:** ${link(d.stageName.get(stage))}` : null,
          t.parent && byId.has(t.parent) ? `**Part of:** ${tl(t.parent)}` : null,
          `**Plan:** ${link(d.label)}${t.phase ? ` › ${t.phase}` : ''}`].filter(Boolean).join(' · '), '',
        `# ${t.id} ${t.title}`, '',
        t.lead || null, '',
        rewriteDocLinks(t.text, d.path), '',
        t.blockedBy.length || t.waitsOnOwner ? `**Blocked by:** ${[...t.blockedBy.map(tl), ...(t.waitsOnOwner ? ["the owner's OK"] : [])].join(' · ')}` : null,
        blocks.get(t.id)?.length ? `**Blocks:** ${blocks.get(t.id).map(tl).join(' · ')}` : null,
        subtasks.length ? `**Subtasks:** ${subtasks.map((x) => `${x.done ? '✓' : '○'} ${tl(x.id)}`).join(' · ')}` : null,
        d === rebuild && foldersByTask.get(t.id) ? `**Code:** ${[...foldersByTask.get(t.id)].sort().map((f) => link(folderName.get(f))).join(' · ')}` : null,
        mentions(`${t.title} ${t.lead} ${t.text}`),
      ]);
    }
  }

  // ---- code map
  if (codeHub) {
    const sorted = [...folders].sort();
    emit('code', codeHub, [
      banner('the scripts under `game/`'), '', '# Code map', '',
      'The Godot game in `game/`, a note per folder: each script\'s purpose from its doc comment, and the plan tasks that changed it.', '',
      ...sorted.map((f) => `${'  '.repeat(f.split('/').length - 1)}- ${link(folderName.get(f))} (${scripts.filter((s) => s.startsWith(`${f}/`)).length} scripts)`),
    ]);
    for (const f of sorted) {
      const own = scripts.filter((s) => s.split('/').slice(0, -1).join('/') === f);
      const parent = f.split('/').slice(0, -1).join('/');
      const children = sorted.filter((c) => c.split('/').slice(0, -1).join('/') === f);
      const ids = [...(tasksByFolder.get(f) ?? [])].sort(compareIds);
      emit('code', folderName.get(f), [
        '---', 'tags: [code]', '---', '',
        banner(`the scripts in \`${f}/\``), '',
        `**In:** ${parent ? link(folderName.get(parent)) : link(codeHub)}${children.length ? ` · **Folders:** ${children.map((c) => link(folderName.get(c))).join(' · ')}` : ''}`, '',
        `# ${f}/`, '',
        own.length ? '## Scripts' : null, '',
        ...own.map((s) => {
          const info = scriptInfo.get(s);
          return `- \`${s.split('/').pop()}\`${info.className ? ` (${info.className})` : ''}${info.summary ? `: ${info.summary}` : ''}`;
        }),
        '',
        ids.length ? `**Tasks:** ${ids.map((id) => link(rebuild.taskName.get(id))).join(' · ')}` : null,
        mentions(own.map((s) => scriptInfo.get(s).doc).join('\n')),
      ]);
    }
  }

  return { notes: notes.sort((a, b) => a.path.localeCompare(b.path)) };
}

/** "docs/research/animation-spike/critique.md" -> "Animation spike critique". */
function untitledLabel(path) {
  const words = path.replace(/\.md$/, '').split('/').slice(-2).join(' ').replace(/[-_]/g, ' ');
  return words.charAt(0).toUpperCase() + words.slice(1);
}

function compareIds(a, b) {
  const pa = a.split('.').map((x) => parseInt(x, 10));
  const pb = b.split('.').map((x) => parseInt(x, 10));
  return pa[0] - pb[0] || (pa[1] ?? 0) - (pb[1] ?? 0) || a.localeCompare(b);
}
