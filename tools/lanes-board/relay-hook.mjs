// Tells the Project Manager (npm run board) what Claude Code sessions do, and
// hands a session what the owner sent it from its page. It never holds a
// session: since Oct 6 (owner's choice) every permission prompt, plan and
// question is answered in the Claude app, and merges are done on GitHub or by
// a session the owner tells to merge. The Project Manager's bell is only told
// that a session asks in the app, or finished its turn.
//
// Install: npm run board:hooks copies this file to ~/.claude/hooks/lanes-relay/hook.mjs
// (with inbox.mjs beside it) and adds, to ~/.claude/settings.json (beside the
// lanes stop hook):
//   "hooks": {
//     "PermissionRequest": [{ "matcher": "*", "hooks": [{ "type": "command", "command": "node \"<home>/.claude/hooks/lanes-relay/hook.mjs\"", "timeout": 10 }] }],
//     "Stop": [{ "hooks": [{ "type": "command", "command": "node \"<home>/.claude/hooks/lanes-relay/hook.mjs\"", "timeout": 10 }] }]
//   }
//
// It talks to the board through files in ~/.claude/lanes-relay (LANES_RELAY
// overrides it, for tests), so it works whether or not the board is up; with no
// such folder it exits at once:
//   inbox/<session>/<n>.json  what the owner sent the session from its page,
//                        oldest first by name: the stop hook hands the oldest
//                        over before the session's next tool, and a turn end
//                        here takes the rest
//   stopnow/<session>.json  the owner pressed Stop now: the stop hook refuses the
//                        session's tools until its turn ends, when this removes it
//   events.jsonl         what happened in the app (a question asked there, or a
//                        turn finished), one JSON object per line, for the bell
// The board words every message (sessions.mjs ownerMessage); this file only
// carries them, so it stays free of dependencies but inbox.mjs, which is
// installed beside it.
import { appendFileSync, existsSync, rmSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { takeFromInbox } from './inbox.mjs';

const DIR = process.env.LANES_RELAY ?? path.join(os.homedir(), '.claude', 'lanes-relay');

if (!existsSync(DIR)) process.exit(0);

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => { input += c; });
process.stdin.on('end', () => {
  let out = null;
  try { out = main(JSON.parse(input || '{}')); } catch { /* never get in a session's way */ }
  if (out) process.stdout.write(JSON.stringify(out));
  process.exit(0);
});

function main(hook) {
  const id = hook.session_id;
  if (!id || !/^[\w-]+$/.test(id)) return null;
  const event = hook.hook_event_name;

  if (event === 'Stop') {
    // A Stop now has done its work once the turn ends (the stop hook refused
    // its tools until then).
    rmSync(path.join(DIR, 'stopnow', `${id}.json`), { force: true });
    // What the owner sent meanwhile goes in as the turn's next instruction.
    const texts = takeFromInbox(DIR, id, { all: true });
    if (texts.length) return { decision: 'block', reason: texts.join('\n\n') };
    note({ kind: 'turn-finished', session: id, cwd: hook.cwd ?? null, last: String(hook.last_assistant_message ?? '').slice(-1000) });
    return null;
  }

  // A question is answered in the app; the bell only says the session waits.
  // Every other prompt is the app's own dialog, untouched.
  if (event === 'PermissionRequest' && hook.tool_name === 'AskUserQuestion') {
    note({ kind: 'asked-in-app', session: id, cwd: hook.cwd ?? null,
      questions: (hook.tool_input?.questions ?? []).map((q) => String(q.question ?? '')) });
  }
  return null;
}

// An event for the Project Manager, appended to events.jsonl.
function note(event) {
  try { appendFileSync(path.join(DIR, 'events.jsonl'), `${JSON.stringify({ time: Date.now(), ...event })}\n`); } catch { /* not worth a session's time */ }
}
