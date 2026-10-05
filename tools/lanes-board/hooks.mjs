// The hooks the Project Manager runs in every Claude Code session, as user
// settings install them: what they are, how ~/.claude/settings.json registers
// them, and whether the installed copies are this checkout's. Pure, no I/O:
// install-hooks.mjs does the install (only with the owner's OK), the server
// reports the status on both pages, and tests/lanes-board-hooks.test.mjs checks
// both.

// Claude Code ends a hook at its timeout, so a holding hook gets a minute more
// than the relay hook holds (24 minutes, LANES_RELAY_WAIT_MS): it gives up and
// clears its card itself.
const HOLD_S = 25 * 60;

// Each hook: its folder under ~/.claude/hooks/, its tracked file here, and the
// events it is registered for. `hold` events wait for the owner (HOLD_S).
export const HOOKS = [
  { name: 'lanes-relay', label: 'relay hook', file: 'relay-hook.mjs', events: [
    { event: 'PermissionRequest', matcher: '*', timeout: HOLD_S, hold: true },
    { event: 'Stop', timeout: HOLD_S, hold: true },
  ] },
  { name: 'lanes-stop', label: 'stop hook', file: 'stop-hook.mjs', events: [
    { event: 'PreToolUse', matcher: '*', timeout: 10 },
    { event: 'Stop', timeout: 10 },
  ] },
];

// The command a setting runs for a hook; claudeDir is ~/.claude.
export function hookCommand(claudeDir, name) {
  return `node "${String(claudeDir).replace(/\\/g, '/')}/hooks/${name}/hook.mjs"`;
}

const findHook = (groups, command) => (groups ?? []).flatMap((g) => g.hooks ?? []).find((h) => h.command === command) ?? null;

// settings with every hook registered and every holding timeout at least 25
// minutes; other settings and hooks are left as they are. A copy: settings is
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

// Whether the installed hooks are this checkout's and registered as they must
// be. tracked and installed map a hook's name to its file's text (installed:
// null when missing); settings is ~/.claude/settings.json's contents.
export function hooksStatus({ tracked, installed, settings, home }) {
  const problems = [];
  const norm = (s) => String(s).replace(/\r\n/g, '\n');
  for (const h of HOOKS) {
    const have = installed?.[h.name];
    if (have == null) problems.push(`The ${h.label} isn't installed.`);
    else if (norm(have) !== norm(tracked[h.name])) problems.push(`The installed ${h.label} differs from this version's.`);
  }
  for (const h of HOOKS) {
    const command = hookCommand(home, h.name);
    for (const e of h.events) {
      const found = findHook(settings?.hooks?.[e.event], command);
      if (!found) problems.push(`The ${h.label} isn't registered for ${e.event}.`);
      else if (e.hold && !(found.timeout >= e.timeout)) problems.push(`The ${h.label}'s ${e.event} timeout is ${found.timeout ?? 'the default'} s, not 25 minutes.`);
    }
  }
  return { current: problems.length === 0, problems };
}
