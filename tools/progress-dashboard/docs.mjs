// Cuts the build plan's task blocks and the spec's user stories, so a stage's
// page can show what each task delivers and how it is checked.
const TASK = /^(\s*)- \[[ x]\] \*\*(\d+b?\.\d+)\s+(.*?)\*\*/;
const PARENT = /^- \[[ x]\] \*\*(\d+b?)\.\s/;
const indentOf = (l) => l.match(/^\s*/)[0].length;

function blockAt(lines, i, stopAtTask = false) {
  const base = indentOf(lines[i]);
  let j = i + 1;
  while (j < lines.length && (!lines[j].trim() || indentOf(lines[j]) > base) && !(stopAtTask && TASK.test(lines[j]))) j++;
  while (j > i + 1 && !lines[j - 1].trim()) j--;
  return lines.slice(i, j).map((l) => l.slice(Math.min(base, indentOf(l)))).join('\n');
}

export function taskBlock(planText, id) {
  const lines = planText.replace(/\r/g, '').split('\n');
  const i = lines.findIndex((l) => l.match(TASK)?.[2] === id);
  return i < 0 ? null : blockAt(lines, i);
}

export function parentBlock(planText, major) {
  const lines = planText.replace(/\r/g, '').split('\n');
  const i = lines.findIndex((l) => l.match(PARENT)?.[1] === major);
  return i < 0 ? null : blockAt(lines, i, true);
}

export function storyIds(block) {
  const m = block?.match(/Stories:\s*([^\n·]*)/);
  if (!m) return [];
  const out = [];
  for (const [, a, b] of m[1].matchAll(/(\d+)(?:\s*[–-]\s*(\d+))?/g)) {
    for (let n = Number(a); n <= Number(b ?? a); n++) out.push(n);
  }
  return out;
}

export function parseStories(specText) {
  const section = specText.replace(/\r/g, '').split(/^## User Stories/m)[1]?.split(/^## /m)[0] ?? '';
  const map = new Map();
  for (const line of section.split('\n')) {
    const m = line.match(/^(\d+)\.\s+\[([ x])\]\s+(.*)$/);
    if (m) map.set(Number(m[1]), { n: Number(m[1]), done: m[2] === 'x', text: m[3] });
  }
  return map;
}

export function stageDocs(planText, specText, stage, states) {
  const stories = parseStories(specText);
  const majors = [...new Set(stage.tasks.map((id) => id.split('.')[0]))];
  return {
    n: stage.n, name: stage.name, full: stage.full,
    parents: majors.map((id) => ({ id, markdown: parentBlock(planText, id) })).filter((p) => p.markdown),
    tasks: stage.tasks.map((id) => {
      const markdown = taskBlock(planText, id) ?? '';
      const title = markdown.match(TASK)?.[3].replace(/[.;]\s*$/, '') ?? id;
      const st = states.get(id) ?? { state: 'rest', blockedBy: [] };
      return {
        id, title, state: st.state, blockedBy: st.blockedBy, markdown,
        stories: storyIds(markdown).map((n) => stories.get(n)).filter(Boolean),
      };
    }),
  };
}
