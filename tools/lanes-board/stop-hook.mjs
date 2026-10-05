// Stops a Claude Code session whose lane was ended from the lanes board
// (npm run board, "End work" on a launched task). It runs as a PreToolUse ("*")
// and Stop hook from user settings; npm run board:hooks installs it by copying
// this file to ~/.claude/hooks/lanes-stop/hook.mjs (with inbox.mjs beside it)
// and adding, to ~/.claude/settings.json:
//   "hooks": {
//     "PreToolUse": [{ "matcher": "*", "hooks": [{ "type": "command", "command": "node \"<home>/.claude/hooks/lanes-stop/hook.mjs\"", "timeout": 10 }] }],
//     "Stop": [{ "hooks": [{ "type": "command", "command": "node \"<home>/.claude/hooks/lanes-stop/hook.mjs\"", "timeout": 10 }] }]
//   }
// The board writes ~/.claude/lanes-stop.json (LANES_STOP_FILE overrides it, for
// tests); with no file this exits at once. A session listed by id, or working
// inside the ended lane's worktree since before it was ended, is stopped at its
// next step (continue:false) once: the entry stays in force for two minutes after
// it first fires, so the turn's own Stop hook also lets it end, and then the
// session can be used again. Launching the lane again cancels its entries.
//
// Before a session's next tool, it also hands over the oldest message the owner
// sent it from the Project Manager (the relay folder's inbox/<session>/, see
// relay-hook.mjs; LANES_RELAY overrides the folder), as context the session reads
// with that tool call (inbox.mjs). A session with neither a stop list nor an
// inbox folder of its own is let go at once.
import { existsSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { inboxDir, takeFromInbox } from './inbox.mjs';

const FILE = process.env.LANES_STOP_FILE ?? path.join(os.homedir(), '.claude', 'lanes-stop.json');
const RELAY = process.env.LANES_RELAY ?? path.join(os.homedir(), '.claude', 'lanes-relay');
const GRACE_MS = 2 * 60 * 1000;
const STALE_MS = 7 * 24 * 60 * 60 * 1000;

const stopList = existsSync(FILE);
if (!stopList && !existsSync(path.join(RELAY, 'inbox'))) process.exit(0);

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => { input += c; });
process.stdin.on('end', () => {
  let hook = {};
  try { hook = JSON.parse(input || '{}'); } catch { /* never get in a session's way */ }
  const id = String(hook.session_id ?? '');
  // Before anything else: nothing here concerns a session with no inbox of its own.
  const inbox = /^[\w-]+$/.test(id) && existsSync(inboxDir(RELAY, id));
  if (!stopList && !inbox) process.exit(0);
  let out = null;
  try { out = stopOf(hook); } catch { /* never get in a session's way */ }
  if (!out && inbox && hook.hook_event_name === 'PreToolUse') { try { out = messageFor(id); } catch { /* likewise */ } }
  if (out) process.stdout.write(JSON.stringify(out));
  process.exit(0);
});

// The oldest message in the session's inbox, taken, as context for this tool call.
function messageFor(id) {
  const [text] = takeFromInbox(RELAY, id);
  return text ? { hookSpecificOutput: { hookEventName: 'PreToolUse', additionalContext: text } } : null;
}

// The output that stops an ended lane's session, or null.
function stopOf(hook) {
  if (!stopList) return null;
  const list = JSON.parse(readFileSync(FILE, 'utf8'));
  const now = Date.now();
  const norm = (p) => path.normalize(p ?? '').toLowerCase();
  const cwd = norm(hook.cwd);
  // When this session began: its transcript file's creation. A relaunch of the
  // same tasks reuses the lane's worktree, and its new session must not inherit
  // the stop, so a worktree match only stops sessions begun before the end.
  let began = null;
  try { if (hook.transcript_path) began = statSync(hook.transcript_path).birthtimeMs || null; } catch { /* no transcript yet */ }
  const entry = (list.entries ?? []).find((e) => {
    if (e.cancelledAt) return false; // the board launched this lane again
    const live = e.firedAt ? now - e.firedAt < GRACE_MS : now - e.requestedAt < STALE_MS;
    if (!live) return false;
    if (hook.session_id && (e.sessions ?? []).includes(hook.session_id)) return true;
    const inside = !!e.worktree && (cwd === norm(e.worktree) || cwd.startsWith(norm(e.worktree) + path.sep));
    return inside && (began === null || began < e.requestedAt);
  });
  if (!entry) return null;
  if (!entry.firedAt) {
    entry.firedAt = now;
    entry.firedBy = hook.session_id ?? null;
    writeFileSync(FILE, JSON.stringify(list, null, 2));
  }
  const why = `Work on ${entry.label ?? 'this lane'} was ended from the Project Manager. Stop here: run nothing more. Your commits, branch and pull request stay as they are. To carry on later, the owner messages this session.`;
  const out = { continue: false, stopReason: why, systemMessage: why };
  if (hook.hook_event_name === 'PreToolUse') {
    out.hookSpecificOutput = { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: why };
  }
  return out;
}
