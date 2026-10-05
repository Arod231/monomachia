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
//   waiting  not started: reason is one of REASONS
export const REASONS = ['locked', 'no-app', 'no-draft', 'no-send', 'not-taken', 'trust', 'error'];
export const LOST_MS = 3 * 60 * 1000; // pressed this long ago and still no session: something went wrong
export const LOCK_CHECK_MS = 15_000; // how often a launch waiting on the lock looks again
// A launch this old never starts by itself: by then its tasks no longer show as
// launched (LAUNCH_FRESH_MS in server.mjs) and may have been launched again.
export const START_MAX_AGE_MS = 48 * 60 * 60 * 1000;
const GRACE_MS = 10_000; // app records can be stamped a little before the board's own clock

export const launchLink = (folder, prompt) => `claude://code/new?folder=${encodeURIComponent(folder)}&q=${encodeURIComponent(prompt)}`;

/**
 * The start queue. deps: list() -> the launch records (changed in place);
 * folder, the repository the links name; open(url); press({ prompt, folder })
 * -> { result }; locked() -> whether the PC is locked; save() writes the
 * records; now(). kick() starts every queued launch and returns the run (a
 * second kick joins it); tick(), on each board pass, queues the launches that
 * waited on the lock once the PC is unlocked; retry(id) refuses at once or
 * queues the launch again and returns the run; recover() turns a press the
 * board was killed in the middle of into an error, at start-up, and says how
 * many it changed.
 */
export function createStarter({ list, folder, open, press, locked, save, now = Date.now }) {
  let running = null;
  let lockSeen = -Infinity;
  const set = (l, patch) => {
    const next = { ...l.start, ...patch, at: now() };
    if (next.state !== 'waiting') delete next.reason;
    l.start = next;
  };
  const isLocked = async () => { lockSeen = now(); return !!(await locked()); };
  const live = (l) => !l.session && !l.endedAt && now() - l.time < START_MAX_AGE_MS;
  const due = () => list().filter((l) => l.start?.state === 'queued' && live(l)).sort((a, b) => a.time - b.time);

  async function startOne(l) {
    try {
      if (await isLocked()) set(l, { state: 'waiting', reason: 'locked' });
      else {
        set(l, { state: 'pressing', attempts: (l.start.attempts ?? 0) + 1 });
        await save();
        await open(launchLink(folder, l.prompt ?? l.goal));
        const { result } = await press({ prompt: l.prompt ?? l.goal, folder });
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

  async function tick() {
    if (running) return undefined;
    const waiting = list().filter((l) => l.start?.state === 'waiting' && l.start.reason === 'locked' && live(l));
    if (!waiting.length || now() - lockSeen < LOCK_CHECK_MS) return undefined;
    if (await isLocked()) return undefined;
    for (const l of waiting) set(l, { state: 'queued' });
    return kick();
  }

  function retry(id) {
    const l = list().find((x) => x.id === id);
    if (!l) throw new Error('Unknown launch');
    if (l.endedAt) throw new Error('That launch was ended');
    if (l.session) throw new Error('Its session has already started');
    if (!live(l)) throw new Error('That launch is over two days old: launch its tasks again');
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
 * board pressed Send itself (they have no start) and for ended ones;
 * { state: 'started' } once its session is linked; 'starting' while queued,
 * being pressed or just sent; else 'waiting' with a reason ('lost' when Send
 * was pressed but no session appeared) and whether a retry is offered (not
 * while the PC is locked: that one starts by itself on unlock).
 */
export function startView(l, now) {
  if (!l.start || l.endedAt) return null;
  if (l.session) return { state: 'started' };
  const s = l.start;
  if (s.state === 'queued' || s.state === 'pressing') return { state: 'starting', since: s.at };
  if (s.state === 'pressed') {
    return now - (s.pressedAt ?? s.at) < LOST_MS ? { state: 'starting', since: s.at } : { state: 'waiting', reason: 'lost', retry: true, since: s.at };
  }
  const reason = s.reason ?? 'error';
  return { state: 'waiting', reason, retry: reason !== 'locked', since: s.at };
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

const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/**
 * Links each launch that has no session yet to the earliest app session made
 * since the launch (less a few seconds' grace) whose first prompt names the
 * launch's lane branch, unless another launch took it. Naming the branch makes
 * it this launch's session, however late it started: the board's press, a
 * retry, or someone sending the draft by hand. sessions: [{ id, cli, created }]
 * from the app's records; prompts: cli id -> first prompt (missing until the
 * transcript has one). Changes the launches in place; true if any was linked.
 */
export function linkLaunches(launches, sessions, prompts) {
  const taken = new Set(launches.map((l) => l.session?.id).filter(Boolean));
  let linked = false;
  for (const l of launches) {
    if (l.session || l.endedAt || !l.branch) continue;
    // The branch as a whole word: lane/gr-1.1 isn't lane/gr-1.10, but may end a sentence.
    const names = new RegExp(`${escapeRe(l.branch)}(?![\\w-]|\\.\\w)`);
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
