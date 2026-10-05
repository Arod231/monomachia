// The hooks the Project Manager runs in every Claude Code session, as user
// settings install them: what they are, where their files go, how
// ~/.claude/settings.json registers them, and whether the installed copies are
// this checkout's. Pure, no I/O: install-hooks.mjs does the install (only with
// the owner's OK), the server reports the status on both pages, and
// tests/lanes-board-hooks.test.mjs checks both.

const DAY_S = 24 * 60 * 60;

// Each hook: its folder under ~/.claude/hooks/, its tracked file here, the
// modules installed beside it, and the events it is registered for. `hold`
// events wait for the owner, so their timeout must last as long as the hook
// holds (24 hours, LANES_RELAY_WAIT_MS).
export const HOOKS = [
  { name: 'lanes-relay', label: 'relay hook', file: 'relay-hook.mjs', shared: ['inbox.mjs'], events: [
    { event: 'PermissionRequest', matcher: '*', timeout: DAY_S, hold: true },
    { event: 'Stop', timeout: DAY_S, hold: true },
  ] },
  { name: 'lanes-stop', label: 'stop hook', file: 'stop-hook.mjs', shared: ['inbox.mjs'], events: [
    { event: 'PreToolUse', matcher: '*', timeout: 10 },
    { event: 'Stop', timeout: 10 },
  ] },
];

const slash = (p) => String(p).replace(/\\/g, '/');

// Every file a hook installs: { from: its file in tools/lanes-board/, to: its
// path under claudeDir (~/.claude) }. The hook itself becomes hook.mjs.
export function hookFiles(claudeDir, h) {
  const dir = `${slash(claudeDir)}/hooks/${h.name}`;
  return [{ from: h.file, to: `${dir}/hook.mjs` }, ...(h.shared ?? []).map((f) => ({ from: f, to: `${dir}/${f}` }))];
}

// The command a setting runs for a hook.
export function hookCommand(claudeDir, name) {
  return `node "${slash(claudeDir)}/hooks/${name}/hook.mjs"`;
}

const findHook = (groups, command) => (groups ?? []).flatMap((g) => g.hooks ?? []).find((h) => h.command === command) ?? null;

// settings with every hook registered and every holding timeout at least 24
// hours; other settings and hooks are left as they are. A copy: settings is
// not changed.
export function withHooks(settings, claudeDir) {
  const out = structuredClone(settings ?? {});
  out.hooks ??= {};
  for (const h of HOOKS) {
    const command = hookCommand(claudeDir, h.name);
    for (const e of h.events) {
      const groups = (out.hooks[e.event] ??= []);
      const found = findHook(groups, command);
      if (found) {
        if (e.hold && !(found.timeout >= e.timeout)) found.timeout = e.timeout;
        continue;
      }
      const entry = { type: 'command', command, timeout: e.timeout };
      const group = groups.find((g) => (e.matcher ? g.matcher === e.matcher : !g.matcher));
      if (group) (group.hooks ??= []).push(entry);
      else groups.push(e.matcher ? { matcher: e.matcher, hooks: [entry] } : { hooks: [entry] });
    }
  }
  return out;
}

// The status of the hooks under claudeDir against the tracked files in
// boardDir, read with read(path) -> text, or null when missing (synchronous;
// the caller's I/O).
export function hooksStatusOf({ claudeDir, boardDir, read }) {
  const files = HOOKS.flatMap((h) => hookFiles(claudeDir, h));
  const tracked = Object.fromEntries(files.map((f) => [f.from, read(`${slash(boardDir)}/${f.from}`)]));
  const installed = Object.fromEntries(files.map((f) => [f.to, read(f.to)]));
  let settings = {};
  try { settings = JSON.parse(read(`${slash(claudeDir)}/settings.json`) ?? '{}'); } catch { /* broken: every registration reads as missing */ }
  return hooksStatus({ tracked, installed, settings, claudeDir });
}

// Whether the installed hooks are this checkout's and registered as they must
// be. tracked maps a file in tools/lanes-board/ to its text; installed maps an
// installed path (hookFiles' `to`) to its text, or null when missing; settings
// is ~/.claude/settings.json's contents; claudeDir is ~/.claude.
export function hooksStatus({ tracked, installed, settings, claudeDir }) {
  const problems = [];
  const norm = (s) => String(s).replace(/\r\n/g, '\n');
  for (const h of HOOKS) {
    const files = hookFiles(claudeDir, h);
    if (files.some((f) => installed?.[f.to] == null)) problems.push(`The ${h.label} isn't installed.`);
    else if (files.some((f) => norm(installed[f.to]) !== norm(tracked[f.from]))) problems.push(`The installed ${h.label} differs from this version's.`);
  }
  for (const h of HOOKS) {
    const command = hookCommand(claudeDir, h.name);
    for (const e of h.events) {
      const found = findHook(settings?.hooks?.[e.event], command);
      if (!found) problems.push(`The ${h.label} isn't registered for ${e.event}.`);
      else if (e.hold && !(found.timeout >= e.timeout)) problems.push(`The ${h.label}'s ${e.event} timeout is ${found.timeout ?? 'the default'} s, not 24 hours.`);
    }
  }
  return { current: problems.length === 0, problems };
}
