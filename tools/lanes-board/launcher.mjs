// Starting a launched session with nobody at the PC. The board opens the
// launch's claude://code/new link: the Claude app puts the prompt in a new
// session's box and, for a folder named by a link, asks "Trust this
// workspace?". It never sends the prompt itself. press-send.ps1 then confirms
// that dialog when it names the repository and presses Send, through Windows UI
// Automation, so no mouse or keyboard is needed. A locked PC hides the app from
// UI Automation, so a launch made while it is locked waits and starts once the
// PC is unlocked. Launches start one at a time, since each link replaces the
// draft in the app's single new-session box.
// The rules live here; server.mjs gives them the real link, press and lock
// check, and tests/lanes-board-launcher.test.mjs gives them fakes.

// A launch's start, kept on its record in launches.json:
//   start: { state, reason?, at, attempts, pressedAt? }
//   queued   to be started (the board starts queued launches in launch order)
//   pressing the link is open and press-send.ps1 is at work
//   pressed  Send was pressed and the prompt left the box; its session shows
//            up in the app's records within seconds
//   waiting  not started: reason is one of REASONS (press-send.ps1's answers
//            other than pressed; the pages word each one, ui.mjs)
export const REASONS = ['locked', 'no-app', 'no-draft', 'no-send', 'not-taken', 'trust', 'error'];
export const LOST_MS = 3 * 60 * 1000; // pressed this long ago and still no session: something went wrong
export const LOCK_CHECK_MS = 15_000; // how often a launch waiting on the lock looks again
// A launch shows on its tasks this long; after that it no longer starts, links
// or shows, since its tasks can be launched again (server.mjs uses it too).
export const LAUNCH_FRESH_MS = 48 * 60 * 60 * 1000;
const GRACE_MS = 10_000; // app records can be stamped a little before the board's own clock

export const launchLink = (folder, prompt) => `claude://code/new?folder=${encodeURIComponent(folder)}&q=${encodeURIComponent(prompt)}`;

/**
 * A new session from the pages' "New session" button: a launch with no tasks,
 * which the owner prompts from the Claude app over Remote Control. The app only
 * makes a session once a prompt is sent, so it gets a short first prompt that
 * carries its tag (what links it to its session, as a lane's branch does) and
 * moves it onto the latest master: the app makes its worktree from whatever the
 * main checkout has checked out.
 */
export function newSessionLaunch({ now, repo }) {
  const tag = `pm-session-${now.toString(36)}`;
  const worktree = `${repo}\\.claude\\worktrees\\${tag}`;
  const goal = [
    `New session from the Project Manager (${tag}), in the Monomachia repository at ${repo}.`,
    `Setup, before anything else: work only in a worktree of ${repo}, never in a scratch or other folder, on the latest master.`,
    `If your working directory is not inside ${repo}, run git -C "${repo}" fetch origin master, then git -C "${repo}" worktree add "${worktree}" --detach origin/master, and move this session into it with the change_directory tool (find it with ToolSearch).`,
    'Otherwise run git fetch origin master and, if git status shows no changes, git switch --detach origin/master.',
    `If .godot-path or .assets-src-path is missing, copy it from ${repo}.`,
    'Then reply in one line with the commit you are on (git log --oneline -1) and wait for my next message: I will send the work from the Claude app.',
    'When I do, set this session\'s title to a short name for that work with the set_session_title tool (session_id "self"; find it with ToolSearch), and build any change on a new branch from origin/master, per CLAUDE.md.',
  ].join(' ');
  return { id: tag, kind: 'session', time: now, tasks: [], tag, goal, start: { state: 'queued', at: now, attempts: 0 } };
}

// Still waiting for its session: not linked to one, not ended, not lapsed.
const pending = (l, now) => !l.session && !l.endedAt && now - l.time < LAUNCH_FRESH_MS;

/**
 * The start queue. deps: list() -> the launch records (changed in place);
 * folder, the repository the links name; open(url); press({ prompt, folder })
 * -> { result }; locked() -> whether the PC is locked; save() writes the
 * records; now(). kick() starts every queued launch and returns the run (a
 * second kick joins it); tick(), on each board pass, queues the launches that
 * waited on the lock once the PC has stayed unlocked a while; retry(id) refuses
 * at once or queues the launch again and returns the run; recover() turns a
 * press the board was killed in the middle of into an error, at start-up, and
 * says how many it changed.
 */
export function createStarter({ list, folder, open, press, locked, save, now = Date.now }) {
  let running = null;
  let lockSeen = -Infinity;
  let unlockedAt = null; // when tick first found the PC unlocked again
  const set = (l, patch) => {
    const next = { ...l.start, ...patch, at: now() };
    if (next.state !== 'waiting') delete next.reason;
    l.start = next;
  };
  const isLocked = async () => { lockSeen = now(); return !!(await locked()); };
  const due = () => list().filter((l) => l.start?.state === 'queued' && pending(l, now())).sort((a, b) => a.time - b.time);

  async function startOne(l) {
    try {
      if (await isLocked()) set(l, { state: 'waiting', reason: 'locked' });
      else {
        set(l, { state: 'pressing', attempts: (l.start.attempts ?? 0) + 1 });
        await save();
        await open(launchLink(folder, l.goal));
        const { result } = await press({ prompt: l.goal, folder });
        if (result === 'pressed') set(l, { state: 'pressed', pressedAt: now() });
        else set(l, { state: 'waiting', reason: REASONS.includes(result) ? result : 'error' });
      }
    } catch {
      set(l, { state: 'waiting', reason: 'error' });
    }
    try { await save(); } catch { /* the next save writes it */ }
  }

  async function drain() {
    for (let l = due()[0]; l; l = due()[0]) await startOne(l);
  }
  // The run clears itself in a callback, which always comes after this
  // assignment, even for a run with nothing to start.
  function kick() {
    running ??= drain().finally(() => { running = null; });
    return running;
  }

  // The PC must stay unlocked for a lock check's span first: a press that the
  // lock cut short leaves its draft in the box, and if someone sends it by hand
  // on unlocking, that session is linked (and this launch skipped) by then.
  async function tick() {
    if (running) return undefined;
    const waiting = list().filter((l) => l.start?.state === 'waiting' && l.start.reason === 'locked' && pending(l, now()));
    if (!waiting.length) { unlockedAt = null; return undefined; }
    if (now() - lockSeen < LOCK_CHECK_MS) return undefined;
    if (await isLocked()) { unlockedAt = null; return undefined; }
    unlockedAt ??= now();
    if (now() - unlockedAt < LOCK_CHECK_MS) return undefined;
    unlockedAt = null;
    for (const l of waiting) set(l, { state: 'queued' });
    return kick();
  }

  function retry(id) {
    const l = list().find((x) => x.id === id);
    if (!l) throw new Error('Unknown launch');
    if (l.endedAt) throw new Error('That launch was ended');
    if (l.session) throw new Error('Its session has already started');
    if (!pending(l, now())) throw new Error('That launch is over two days old: launch its tasks again');
    const s = l.start ?? {};
    if (s.state === 'queued' || s.state === 'pressing') throw new Error('It is starting now');
    if (s.state === 'pressed' && now() - (s.pressedAt ?? s.at) < LOST_MS) throw new Error('It was just sent; give its session a few minutes to show up');
    set(l, { state: 'queued' });
    return kick();
  }

  function recover() {
    const cut = list().filter((l) => l.start?.state === 'pressing');
    for (const l of cut) set(l, { state: 'waiting', reason: 'error' });
    return cut.length;
  }

  return { kick, tick, retry, recover };
}

/**
 * How a launch's start reads on the pages: null for launches from before the
 * board pressed Send itself (they have no start), ended ones and lapsed ones;
 * { state: 'started' } once its session is linked; 'starting' while queued,
 * being pressed or just sent; else 'waiting' with a reason ('lost' when Send
 * was pressed but no session appeared) and whether a retry is offered (not
 * while the PC is locked: that one starts by itself on unlock).
 */
export function startView(l, now) {
  if (!l.start || l.endedAt) return null;
  if (l.session) return { state: 'started' };
  if (!pending(l, now)) return null;
  const s = l.start;
  if (s.state === 'queued' || s.state === 'pressing') return { state: 'starting' };
  if (s.state === 'pressed') {
    return now - (s.pressedAt ?? s.at) < LOST_MS ? { state: 'starting' } : { state: 'waiting', reason: 'lost', retry: true };
  }
  const reason = s.reason ?? 'error';
  return { state: 'waiting', reason, retry: reason !== 'locked' };
}

/**
 * The first prompt a session was sent, from the head of its transcript (JSON
 * lines): the text of the first user line that isn't meta or a tool result,
 * its parts joined by newlines. Null until there is one.
 */
export function firstPrompt(text) {
  for (const line of text.split(/\r?\n/)) {
    if (!line.includes('"user"')) continue;
    let o;
    try { o = JSON.parse(line); } catch { continue; }
    if (o.type !== 'user' || o.isMeta || !o.message) continue;
    const c = o.message.content;
    if (typeof c === 'string') return c;
    if (!Array.isArray(c)) continue;
    const parts = c.filter((p) => p?.type === 'text').map((p) => p.text);
    if (parts.length) return parts.join('\n');
  }
  return null;
}

/**
 * The app sessions worth reading for links: those with a transcript id, made
 * since the oldest launch still waiting for its session (less the grace). None
 * when no launch waits.
 */
export function linkCandidates(launches, sessions, now) {
  const waiting = launches.filter((l) => pending(l, now));
  if (!waiting.length) return [];
  const since = Math.min(...waiting.map((l) => l.time)) - GRACE_MS;
  return sessions.filter((s) => s.cli && s.created >= since);
}

const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/**
 * Links each launch still waiting for its session to the earliest app session
 * made since the launch (less the grace) whose first prompt names the launch's
 * lane branch (or a new session's tag), unless another launch took it. Naming
 * the branch makes it this launch's session, however late it started: the
 * board's press, a retry, or someone sending the draft by hand. The newest
 * launches go first, so a relaunch of the same tasks gets its own session.
 * sessions: [{ id, cli, created }] from the app's records; prompts: cli id ->
 * first prompt (missing until the transcript has one). Changes the launches in
 * place; true if any was linked.
 */
export function linkLaunches(launches, sessions, prompts, now) {
  const taken = new Set(launches.map((l) => l.session?.id).filter(Boolean));
  let linked = false;
  for (const l of launches.filter((x) => pending(x, now) && (x.branch || x.tag)).sort((a, b) => b.time - a.time)) {
    // The branch as a whole word: lane/gr-1.1 isn't lane/gr-1.10, but may end a sentence.
    const names = new RegExp(`${escapeRe(l.branch || l.tag)}(?![\\w-]|\\.\\w)`);
    const s = sessions
      .filter((x) => !taken.has(x.id) && x.cli && x.created >= l.time - GRACE_MS && names.test(prompts.get(x.cli) ?? ''))
      .sort((a, b) => a.created - b.created)[0];
    if (s) { l.session = { id: s.id, cli: s.cli }; taken.add(s.id); linked = true; }
  }
  return linked;
}

/** press-send.ps1's answer: its last line of JSON with a result, else an error. */
export function pressResult(stdout) {
  const lines = String(stdout ?? '').split(/\r?\n/).map((s) => s.trim()).filter(Boolean).reverse();
  for (const line of lines) {
    try {
      const o = JSON.parse(line);
      if (typeof o?.result === 'string') return o;
    } catch { /* not the answer */ }
  }
  return { result: 'error' };
}
