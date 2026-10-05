// Lets the owner answer Claude Code sessions from the Project Manager (npm run
// board): their permission prompts, plans, AskUserQuestion questions, and a
// reply when a turn ends. While the Away switch is on (the Questions tab, on
// the phone or the PC), every session's prompts and turn ends wait there; while
// it's off, every session keeps the app's own dialogs, and a question asked in
// the app or a finished turn is noted for the Project Manager.
//
// Install: copy this file to ~/.claude/hooks/lanes-relay/hook.mjs and add, to
// ~/.claude/settings.json (beside the lanes stop hook), with timeouts of 24 hours
// so a hold lasts as long as this file lets it:
//   "hooks": {
//     "PermissionRequest": [{ "matcher": "*", "hooks": [{ "type": "command", "command": "node \"<home>/.claude/hooks/lanes-relay/hook.mjs\"", "timeout": 86400 }] }],
//     "Stop": [{ "hooks": [{ "type": "command", "command": "node \"<home>/.claude/hooks/lanes-relay/hook.mjs\"", "timeout": 86400 }] }]
//   }
//
// It talks to the board through files in ~/.claude/lanes-relay (LANES_RELAY
// overrides it, for tests), so it works whether or not the board is up; with no
// such folder it exits at once:
//   away.json            the Away switch: { on, since, from }
//   pending/<id>.json    what a session waits on (written here)
//   answers/<id>.json    the board's answer (read here, then both removed)
//   inbox/<session>/<n>.json  what the owner sent the session while no turn end
//                        was held, oldest first by name: the stop hook hands the
//                        oldest over before the session's next tool, and a turn
//                        end here takes the rest
//   events.jsonl         what happened in the app meanwhile (a question asked
//                        there, or a turn finished, while Away was off), one JSON
//                        object per line
// A prompt waits up to 24 hours for the board (LANES_RELAY_WAIT_MS), then falls
// back to the app's dialog; so does switching Away off. A turn's end waits the
// same, so the owner can reply; meanwhile the app shows the session as working,
// and "Hand back to the app" on the board ends the wait.
// The board shapes every answer and words every message (sessions.mjs
// relayAnswer, ownerMessage); this file only carries them, so it stays free of
// dependencies.
import { appendFileSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const DIR = process.env.LANES_RELAY ?? path.join(os.homedir(), '.claude', 'lanes-relay');
const WAIT_MS = Number(process.env.LANES_RELAY_WAIT_MS) || 24 * 60 * 60 * 1000;
const POLL_MS = 400;

const readJson = (file) => { try { return JSON.parse(readFileSync(file, 'utf8')); } catch { return null; } };
const away = () => readJson(path.join(DIR, 'away.json'))?.on === true;

if (!existsSync(DIR)) process.exit(0);

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => { input += c; });
process.stdin.on('end', async () => {
  let out = null;
  try { out = await main(JSON.parse(input || '{}')); } catch { /* never get in a session's way */ }
  if (out) process.stdout.write(JSON.stringify(out));
  process.exit(0);
});

let pendingFile = null;
const cleanup = () => { if (pendingFile) rmSync(pendingFile, { force: true }); };
process.on('exit', cleanup);
for (const sig of ['SIGTERM', 'SIGINT', 'SIGHUP']) process.on(sig, () => process.exit(0));

async function main(hook) {
  const id = hook.session_id;
  if (!id || !/^[\w-]+$/.test(id)) return null;
  const event = hook.hook_event_name;

  if (event === 'Stop') {
    // What the owner sent meanwhile goes in first, Away or not.
    const sent = takeInbox(id);
    if (sent) return continueWith(sent);
    const last = String(hook.last_assistant_message ?? '');
    if (!away()) {
      note({ kind: 'turn-finished', session: id, cwd: hook.cwd ?? null, last: last.slice(-1000) });
      return null;
    }
    const answer = await ask(hook, { kind: 'stop', last: last.slice(-4000) }, id);
    return answer?.reply ? continueWith(answer.reply) : null;
  }

  if (event === 'PermissionRequest') {
    const question = hook.tool_name === 'AskUserQuestion';
    if (!away()) {
      if (question) note({ kind: 'asked-in-app', session: id, cwd: hook.cwd ?? null,
        questions: (hook.tool_input?.questions ?? []).map((q) => String(q.question ?? '')) });
      return null;
    }
    const answer = await ask(hook, {
      kind: question ? 'question' : hook.tool_name === 'ExitPlanMode' ? 'plan' : 'permission', tool: hook.tool_name, input: hook.tool_input ?? {},
      suggestions: hook.permission_suggestions ?? null, mode: hook.permission_mode ?? null,
    });
    if (!answer || answer.release || !answer.behavior) return null;
    const decision = { behavior: answer.behavior };
    if (answer.behavior === 'allow') {
      if (answer.updatedInput) decision.updatedInput = answer.updatedInput;
      if (answer.updatedPermissions) decision.updatedPermissions = answer.updatedPermissions;
    } else if (answer.message) decision.message = answer.message;
    return { hookSpecificOutput: { hookEventName: 'PermissionRequest', decision } };
  }
  return null;
}

// An event for the Project Manager, appended to events.jsonl.
function note(event) {
  try { appendFileSync(path.join(DIR, 'events.jsonl'), `${JSON.stringify({ time: Date.now(), ...event })}\n`); } catch { /* not worth a session's time */ }
}

// The board's words, as the turn's next instruction.
function continueWith(text) {
  return { decision: 'block', reason: text };
}

// Everything in a session's inbox, oldest first, joined; null when it's empty.
// Each message is removed as it's taken.
function takeInbox(session) {
  const dir = path.join(DIR, 'inbox', session);
  let names = [];
  try { names = readdirSync(dir).filter((n) => n.endsWith('.json')).sort(); } catch { return null; }
  const texts = [];
  for (const n of names) {
    const m = readJson(path.join(dir, n));
    try { rmSync(path.join(dir, n)); } catch { continue; } // taken already
    if (m?.text) texts.push(String(m.text));
  }
  return texts.length ? texts.join('\n\n') : null;
}

// Writes the pending item and waits for the board's answer (or, for a turn's
// end, anything sent to the session's inbox). Null when Away goes off, when
// handed back, or out of time.
async function ask(hook, item, inboxOf = null) {
  const pid = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10).padEnd(4, '0')}`;
  for (const sub of ['pending', 'answers']) mkdirSync(path.join(DIR, sub), { recursive: true });
  pendingFile = path.join(DIR, 'pending', `${pid}.json`);
  const answerFile = path.join(DIR, 'answers', `${pid}.json`);
  writeFileSync(pendingFile, JSON.stringify({
    id: pid, session: hook.session_id, cwd: hook.cwd ?? null, transcript: hook.transcript_path ?? null,
    time: Date.now(), pid: process.pid, ...item,
  }, null, 2));
  const until = Date.now() + WAIT_MS;
  try {
    while (Date.now() < until) {
      const a = readJson(answerFile);
      if (a) { rmSync(answerFile, { force: true }); return a.release ? null : a; }
      if (inboxOf) {
        const sent = takeInbox(inboxOf);
        if (sent) return { reply: sent };
      }
      if (!away()) return null;
      await new Promise((r) => setTimeout(r, POLL_MS));
    }
    return null;
  } finally {
    cleanup();
    pendingFile = null;
  }
}
