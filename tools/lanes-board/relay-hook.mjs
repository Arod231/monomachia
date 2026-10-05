// Lets the owner answer Claude Code sessions from the Project Manager (npm run
// board): their permission prompts, their AskUserQuestion questions, and a
// reply when a turn ends. While the Away switch is on (the Questions tab, on
// the phone or the PC), every session's prompts wait there; while it's off,
// every session keeps the app's own dialogs, and a question asked in the app is
// noted for the Project Manager.
//
// Install: copy this file to ~/.claude/hooks/lanes-relay/hook.mjs and add, to
// ~/.claude/settings.json (beside the lanes stop hook):
//   "hooks": {
//     "PermissionRequest": [{ "matcher": "*", "hooks": [{ "type": "command", "command": "node \"<home>/.claude/hooks/lanes-relay/hook.mjs\"", "timeout": 1500 }] }],
//     "Stop": [{ "hooks": [{ "type": "command", "command": "node \"<home>/.claude/hooks/lanes-relay/hook.mjs\"", "timeout": 1500 }] }]
//   }
//
// It talks to the board through files in ~/.claude/lanes-relay (LANES_RELAY
// overrides it, for tests), so it works whether or not the board is up; with no
// such folder it exits at once:
//   away.json            the Away switch: { on, since, from }
//   pending/<id>.json    what a session waits on (written here)
//   answers/<id>.json    the board's answer (read here, then both removed)
//   replies/<session>.json  a reply typed while the session was busy or idle,
//                           handed over when its turn next ends
//   events.jsonl         what happened in the app meanwhile (a question asked
//                        there while Away was off), one JSON object per line
// A prompt waits up to 20 minutes for the board (LANES_RELAY_WAIT_MS), then
// falls back to the app's dialog; so does switching Away off. A turn's end
// waits the same, so the owner can reply; meanwhile the app shows the session
// as working, and "Hand back to the app" on the board ends the wait.
// The board shapes every answer (sessions.mjs relayAnswer); this file only
// carries it, so it stays free of dependencies.
import { appendFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const DIR = process.env.LANES_RELAY ?? path.join(os.homedir(), '.claude', 'lanes-relay');
const WAIT_MS = Number(process.env.LANES_RELAY_WAIT_MS) || 20 * 60 * 1000;
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
  if (!id) return null;
  const event = hook.hook_event_name;

  if (event === 'Stop') {
    // A reply queued for this session goes in first, Away or not.
    const queued = path.join(DIR, 'replies', `${id}.json`);
    const q = readJson(queued);
    if (q?.text) { rmSync(queued, { force: true }); return continueWith(q.text); }
    if (!away()) return null;
    const answer = await ask(hook, { kind: 'stop', last: String(hook.last_assistant_message ?? '').slice(-4000) }, queued);
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

// The owner's words, as the turn's next instruction.
function continueWith(text) {
  return { decision: 'block', reason: `The owner replied from the Project Manager:\n\n${text}` };
}

// Writes the pending item and waits for the board's answer (or a queued reply,
// for a turn's end). Null when Away goes off, when handed back, or out of time.
async function ask(hook, item, queuedReply = null) {
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
      if (queuedReply) {
        const q = readJson(queuedReply);
        if (q?.text) { rmSync(queuedReply, { force: true }); return { reply: q.text }; }
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
