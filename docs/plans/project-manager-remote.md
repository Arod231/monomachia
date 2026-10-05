# Plan: Project Manager remote session control

Spec: `docs/specs/project-manager-remote.md` · branch `tools/project-manager-remote` · pull request #36

## Destination

The owner runs the project's sessions from the iPhone. With Away on, every session's permission prompts, plan approvals and turn ends wait in the Project Manager's Questions tab and are answered in a tap or two, and the session carries on. (Questions did too until Oct 5; since then they stay in the app and the bell says a session waits on them: see the spec's status note.) A bell, and lock-screen notifications while Away is on, say when something needs the owner. Each session has a page with its lane, its posted shots and looping clips, every image it got back from its tools, the documents it wrote, its pull request and its artifacts. The commands Approve & continue, Show me, Merge, Compact (through the Claude app), Stop now and End work all work from the phone. The plan ends when the owner has run real work this way from the phone and approved the pull request.

## Notes

- **Gate tasks are ticked only once the owner has done their part,** so a task blocked by one needs no "(and the owner's OK)" of its own.
- **One task at a time, stopping only where the owner is needed.** The owner chose to stop only at the gates, which are tasks 1, 3, 9, 11, 14 and 19: approval, a few minutes of the owner's hands, a settings change or a check on the phone. After every other task, Claude reports it and carries on. After each task:
  - tick it here;
  - add a line to Progress;
  - tick each of the spec's user stories the build now fully delivers.
- **Every task ends** with:
  - the web tests and the typecheck passing (`npm run test:web` and `npm run typecheck:web`, or their names once the consolidation renames them);
  - a commit whose subject names "(PM task N)";
  - a push to pull request #36.
  Task 18 also runs the Godot suite if it changes anything under `game/`. Before each task, merge `origin/feature/godot-rebuild` in.
- **Task 2 ships early on its own.** It goes in a small pull request (a branch from `origin/feature/godot-rebuild`, into it) so that, once the owner approves and it merges, the live Project Manager follows this plan while the rest is built. Its tick lands here after it merges.
- **A preview from task 9 on.** With the owner's OK at that point, port 5197 runs this branch's server, from a preview loop like the one used for pull request #31. The owner then uses finished parts from the phone. After the merge, the usual `run.cmd` loop serves merged code again.
- **User settings change only with the owner's OK.** The hooks in `~/.claude/` change only at an install (task 9, and again whenever a later task changes them). Tests never touch `~/.claude/`: they use the `LANES_*` overrides and throwaway folders.
- **The round trip is the main test seam.** Task 6 builds the harness (the real server on a spare port, the real hooks, throwaway folders, a fixture repository); every later task adds its cases there. Dense rules get unit tests.
- **Media is never committed.** Renders may be made from paid assets. Media, notifications, push keys and subscriptions live in `~/.claude/lanes-board/`.
- **The consolidation** (pull request #34 and after) moves the Node tests to `node --test`, removes the web toolchain and renames npm scripts. Tasks use whatever the base has when they start. When godot-rebuild task 26.4 merges the rebuild into `master`, pull request #36 is retargeted to `master`.
- **Task 3's results** go under Decisions so far. A proof that fails switches to the spec's fallback before task 6 starts.

## Decisions so far

- [Spec](../specs/project-manager-remote.md) approved by the owner on Oct 4, 2026. The interview's answers are in its "Decisions in plain English".
- Plan choices (Oct 4):
  - the breakdown below as drafted;
  - task 2 as an early small pull request;
  - a preview of this branch on port 5197 from task 9;
  - stops only at the gates.
- Before this plan: Tailscale HTTPS certificates on, and `tailscale serve --bg 5197` set up (Oct 4).
- Out of this plan: launched sessions that waited for Enter on the PC, fixed separately in pull requests #39 and #43.
- **Spike results (task 3, Oct 4)**, from a throwaway session in auto mode whose project settings carried a logging test hook:
  - **Proven: answering a question.** AskUserQuestion fires a PermissionRequest hook; allow with `updatedInput` = the tool input plus `answers` (question text to label, several joined with ", ") reaches the session as its answer, and the app never shows the question.
  - **Proven: delivery before the next step.** `additionalContext` from a PreToolUse hook reaches the session with that tool call (it quoted the message).
  - **Proven: holding a turn end.** A Stop hook held one for 18 minutes with the session alive (the hook's timeout was 3600 s; the default is 600).
  - **Proven: the turn summary.** The app writes its turn summary (`postTurnSummary`: status category and detail) in the session record while the turn end is still held.
  - **Proven: the Remote Control link.** The session record's `bridgeSessionIds` give https://claude.ai/code/<id>, which opened the session in the Claude app on the owner's iPhone.
  - **Found: holds outlive deleted sessions.** The session was deleted mid-hold and its hook kept waiting, so a live hook process doesn't mean a live session. The Project Manager drops a held item when its session record or transcript is gone (task 6).
  - **Found: hooks load at session start.** A hook added to a running session's settings never runs, and the app ignores a launch link's folder (it uses the sidebar's folder group), so tests that need hooks start their session from the app on a folder that has them.
  - **Left to task 9's first real use** (the owner's call): a hold past 25 minutes (fallback: holds that end and re-arm), a free-form `response` answer, and Stop now.

## Progress

- Oct 4, 2026: spec approved; plan drafted.
- Oct 4, 2026: the owner approved this plan (task 1). Next: task 2 in its own small pull request, then the spike (task 3).
- Oct 4, 2026: task 2 done: pull request #37 merged (38f43fa) and the live Project Manager follows PM. Next: the spike (task 3), with task 4 alongside while its long holds run.
- Oct 4, 2026: task 3 done (the spike; findings under Decisions so far). Next: task 4.

## Build order

1. **Approval and groundwork:** 1, 2, 3, 4, 5
2. **Away and the Questions tab:** 6, 7, 8, 9
3. **Notifications:** 10, 11
4. **Sessions and commands:** 12, 13, 14
5. **Visuals and docs:** 15, 16, 17, 18
6. **The owner's check:** 19

## Tasks

### Phase A: approval and groundwork

- [x] **1. The owner's approval of this plan.** The owner reviews this plan, the spec being approved.
  - Delivers: the plan approved, and the spec's status line set to approved.
  - Check: the owner's OK recorded under Progress.
  - Blocked by: none
  - **Owner:** approves this plan. Nothing below starts until then.
  - Done Oct 4: the owner approved this plan, after approving the spec the same day.
- [x] **2. The board follows this plan.** The Project Manager shows plan "PM" on its Progress and Graph tabs, outside the roadmap's phases.
  - Delivers:
    - a PM entry in the board's plan list (flat kind, this plan's branch, into `feature/godot-rebuild`);
    - "(PM task N)" in a commit subject naming a lane's task;
    - launched PM lanes taking `lane/pm-<ids>` branches.
    It ships in its own small pull request, so that the live board follows this plan before the feature merges.
  - Done Oct 4: pull request #37 merged into `feature/godot-rebuild` (38f43fa) on the owner's approval; the live Project Manager restarted onto it and shows PM.
  - Check:
    - a board test parses this plan's tasks, build order and blockers;
    - a test board on a spare port shows PM on Progress and Graph in the Browser pane;
    - the small pull request merges on the owner's approval.
  - Blocked by: 1 · Stories: 86
- [x] **3. Spike: the hook paths on a live session.** Before anything is built on them, prove on the desktop app what the spec rests on but nobody has tried.
  - Delivers: findings under Decisions so far, from a throwaway session in a scratch folder. That folder's own project settings carry test hooks, so user settings stay untouched. The findings:
    - a PermissionRequest hook answers AskUserQuestion (`answers`, several labels, an "Other" text, and `response`);
    - a held question and a held turn end both outlast 25 minutes (hook timeout raised in the scratch settings);
    - a held turn end continues the session with a reply;
    - context added by a PreToolUse hook reaches the session before its next tool;
    - Stop now (deny, then end the turn) is followed by a held turn end;
    - where the app's session record keeps the Remote Control link once `/rc` is typed, and that the link opens the session on the iPhone;
    - when the app writes its turn summary.
    A proof that fails is replaced by the spec's fallback, written here before task 6.
  - Check: each item recorded as proven or replaced; the throwaway scripts stay in the scratchpad, never committed.
  - Blocked by: 1 · Stories: 12, 87
  - **Owner:** presses Enter to start the throwaway session in the app (a new session's first prompt never sends itself), types `/rc` in it, and opens its link on the phone.
  - Done Oct 4: findings under Decisions so far; the owner counted it done with three checks left to task 9.
- [x] **4. Room for the new parts.** The board's session and relay code gets a module of its own, and the two pages share their session and question rendering, with no change in behaviour.
  - Delivers:
    - the Sessions and relay routes and helpers moved out of the server into a module it mounts;
    - a page module, served like the existing UI and graph modules, holding the question, permission and session rendering both pages use.
  - Check: every board test passes unchanged; both pages behave as before in the Browser pane.
  - Blocked by: 1 · Stories: 83
  - Owner's answers (Oct 4, lane `lane/pm-4-5-6`, with tasks 5 and 6): the lane follows the side-lane rule, so it ticks its tasks and leaves Progress to this plan's own branch.
- [x] **5. Actions from the HTTPS address.** The Project Manager accepts its own pages' actions from `https://<pc>.<tailnet>.ts.net` through Tailscale Serve.
  - Delivers: the same-origin rule accepts an https origin whose host is one of the PC's tailnet names (requests through Serve arrive from loopback); everything else is refused as today.
  - Check:
    - access tests: the tailnet name over https is allowed; another https site, a plain form post and a wrong host are refused;
    - a harmless action (clearing a queued reply) succeeds through https://desktop-jk5bn8g.tailec6188.ts.net.
  - Blocked by: 1 · Stories: 41, 78, 79
  - Owner's answer (Oct 4): the HTTPS check is simulated now, on a test board sent the exact request Tailscale Serve sends (from loopback, the ts.net Host, an https Origin); the live check through the HTTPS address happens at task 9's preview.

### Phase B: Away and the Questions tab

- [x] **6. Away, and questions answered from the Questions tab.** The tracer bullet: with Away on, a session's AskUserQuestion waits in the Project Manager, and the owner's answer, from the phone or the PC, lets it carry on.
  - Delivers:
    - **The Away switch:** an Away file in the relay folder (on or off, since when, from which device), shown in both pages' headers with the number of items waiting. The per-session "Answer from Project Manager" switch is removed.
    - **The hook:** while Away is on, the relay hook holds AskUserQuestion and answers it in task 3's proven shape. With Away off, it records "asked in the app" and leaves the dialog to the app.
    - **Server routes** for Away, held items and answers. A late answer gets "already answered, handed back or timed out".
    - **A Questions tab** on both pages. Questions are grouped by session, with its task and waiting time: header chip, options and descriptions, previews in an escaped monospace block, multi-select, Other, a free-form reply, and one Send per call. The tab carries a count, and the Overview's "Waiting on you" links to it. Questions already showing in the app are listed read-only.
    - **The round-trip test harness:** the real server on a spare port, with throwaway state, relay, stop and projects folders and a fixture repository, driving the real hooks with fixture events.
  - Check:
    - round-trip tests: Away off leaves the dialog to the app and records the event; Away on holds; single, multi-select, Other and free-form answers reach the hook in the right shape; a late answer is refused;
    - unit tests of the answer rules;
    - both pages answer a fixture session by hand.
  - Blocked by: 3, 4 · Stories: 1, 2, 3, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 24, 25, 26, 27, 84
  - Owner's answers (Oct 4), taken before the spike had run:
    - built ahead of task 3 on the spec's shape (allow, with the input passed back plus an `answers` map), with the fallback (decline, carrying the answers as the reason) one switch away in the rule module; the spike decides which one ships before task 9 installs the hooks;
    - a free-form reply reaches the session as a decline carrying the owner's words ("The owner answered from the Project Manager: …"), which hooks already deliver, rather than the spec's `response`;
    - turn ends are held while Away is on from this task, as switched-on sessions' are today (20 minutes, a reply continues them); task 8 adds the inbox, release, the 24 hours and the Questions-tab cards.
  - After the spike: a held item whose session is deleted (its transcript gone, or its app record gone once seen) is dropped and its hook released, swept every 5 seconds; the spike found such holds otherwise wait on.
- [x] **7. Permission prompts and plan approvals.** With Away on, a session's permission prompts and plans wait in the Questions tab too.
  - Delivers: on both pages,
    - held permissions showing the command or edit, with Allow, Always allow (naming the rule it adds) and Deny with a reason;
    - held plans rendered as Markdown, with Approve, and Reject with a reason.
  - Check: round-trip cases for allow, always (the rule is passed back), deny with a reason, and plan approve and reject.
  - Blocked by: 6 · Stories: 21, 22
  - Owner's answers (Oct 4, lane `lane/pm-7-8-9-10`, with tasks 8, 9 and 10; side-lane rule as in task 4): a plan card offers the app's own choices, a plain Approve plus one button per mode the prompt suggests (such as "Approve, auto-accept edits"), read from the prompt's suggestions.
- [x] **8. Turn ends, replies and the inbox.** With Away on, a session that finishes its turn waits for the owner, and messages reach a session wherever it is.
  - Delivers:
    - **Held turn ends:** while Away is on, the relay hook holds each turn end with the session's last message, continued by a reply, Approve & continue or Show me. A reply already queued goes in at once. With Away off, it records "turn finished".
    - **The inbox:** a per-session inbox in the relay folder. The PreToolUse hook adds the oldest message as context before the session's next tool, and a turn end takes what's left. Replies to sessions no hook can reach are queued for their next turn end.
    - **Release:** Away off releases every held item (dialogs back to the app, held turns ending). Hand back to the app works on any item, and every hold gives up after 24 minutes (shortened in tests; 24 hours until the owner settled on 25 minutes after task 9).
    - **On both pages,** turn ends appear in the Questions tab with quick replies and a reply box.
  - Check: round-trip cases:
    - a held turn continued by a reply;
    - the Approve & continue and Show me texts;
    - a queued reply going in at the next turn end;
    - delivery before the next tool;
    - Away off releasing everything;
    - hand back;
    - the shortened time limit.
  - Blocked by: 3, 6 · Stories: 4, 5, 6, 7, 8, 9, 23
  - Owner's answers (Oct 4):
    - until task 15 brings `npm run post`, Show me asks the session to capture a shot or short clip of what it's working on and give its path with a one-line caption, or to say in one line that there's nothing to show yet; task 15 switches the text to `npm run post`;
    - a turn-end card shows the session's last message at once, and the app's turn summary once the app has written it.
- [x] **9. The hooks installed, and the first real Away.** The tracked hooks go live in user settings, and the owner uses Away from the phone.
  - Delivers:
    - with the owner's OK, the relay and stop hooks copied to `~/.claude/hooks/`, and the PermissionRequest and Stop timeouts in `~/.claude/settings.json` at least 25 minutes (24 hours until the owner, Oct 4, found 25 minutes enough; the hold gives up at 24);
    - the page saying when the installed copies differ from the tracked ones;
    - with the owner's OK, port 5197 served from this branch until the merge.
  - Check: a test of the installed-versus-tracked comparison; the owner switches Away on from the phone, answers a real session's question and replies to a finished turn, and both sessions carry on.
  - Blocked by: 7, 8 · Stories: 81, 82
  - **Owner:** OKs the user-settings change and the preview, then tries Away from the phone.
  - Owner's answers (Oct 4):
    - the preview serves this lane's branch (`lane/pm-7-8-9-10`) as soon as task 9's code is in, and moves to `tools/project-manager-remote` once the lane's pull request merges;
    - while the owner tries Away from the phone, task 10 is built; task 9 is ticked once the owner confirms it worked.
  - The owner OK'd both (Oct 4): the install in user settings (copying both hooks to `~/.claude/hooks/` and raising the relay hook's two timeouts, then planned at 24 hours, with `settings.json` backed up), and port 5197 serving this lane from `~/.claude/all-lanes-server/preview.cmd` in place of `run.cmd` until the merge.
  - The install (Oct 4): both hooks were copied to `~/.claude/hooks/` and the preview runs this lane on 5197. `~/.claude/settings.json` refuses every write on this PC, even from Notepad or an administrator's PowerShell, though its permissions are normal, so the relay hook's timeouts stay at 1500 s. The owner chose to try Away now, then settled on 25 minutes (pull request #50): the hook holds for 24 minutes and gives up a minute before Claude Code's 1500 s timeout, so the settings already in place count as current and nothing has to write that file.
  - Done Oct 4: the owner switched Away on from the phone, answered a real session's question and replied to a finished turn, and both sessions carried on.
  - The spike's checks left to this task's first real use, and where they stand:
    - a hold longer than 25 minutes: no longer needed, since the owner settled on 25-minute holds (#50);
    - a permission hook giving the dialog back to the app when it gives up: not yet seen on a live session; a question left unanswered for 24 minutes shows it;
    - a free-form `response` answer: not needed, since a free-form reply goes as a decline carrying the owner's words (task 6's answers), which the spike proved;
    - Stop now: built and checked with task 12.
  - Since this task, "Withdraw" (`/relay/unqueue`) clears everything waiting in a session's inbox, not just one queued reply, as the inbox can hold several messages.
  - Review fixes after the merge (Oct 4): the inbox is written whole (temp file, then rename) and never loses or reorders a message (`inbox.mjs`, installed beside both hooks); the stop hook lets a session go at once unless it has an inbox of its own; bell records from `events.jsonl` are named by their place in the file, which starts afresh once its oldest line is over 30 days old; the stop-hook tests use a throwaway relay folder; a failed `settings.json` write leaves no backup behind.

### Phase C: notifications

- [x] **10. The bell.** Every page has a bell listing what happened while the owner was elsewhere.
  - Delivers:
    - notification records from held questions, permissions and plans, questions asked in the app, and finished turns (tasks 13 and 15 add pull requests ready to merge and new visuals);
    - records kept in the state folder with a read flag shared by every device, and trimmed after 7 days;
    - on both pages, the bell with its unread count, the list newest first, and Mark all read. Tapping a record marks it read and opens its question or session.
  - Check: unit tests of the notification rules (events to records, the trim, read state); round trip: a held question makes one record, and marking it read from one client shows it read on the other.
  - Blocked by: 6, 8 · Stories: 28, 29, 30, 31, 32, 33
  - Owner's answers (Oct 4):
    - answering, handing back or a timeout marks a held item's record read, so the bell counts only what still needs the owner;
    - a session's newer finished-turn record replaces its older unread one, so each session shows at most one unread finished turn.
- [x] **11. Lock-screen notifications.** While Away is on, the iPhone shows each new notification on its lock screen.
  - Delivers:
    - **On the phone:** a service worker at the site root that shows a push and opens its target on tap, and the manifest set up as a standalone Home Screen app. "Turn on notifications" is offered only in the Home Screen app over HTTPS, with an explanation anywhere else.
    - **Keys and subscriptions:** a VAPID key pair and the subscriptions in the state folder, never committed. Subscriptions the push service reports gone are dropped.
    - **Payloads** encrypted for the phone (RFC 8291) and signed (RFC 8292) with `node:crypto`.
    - **Sending rules:** pushes go out only while Away is on, and are tagged so repeats replace each other.
  - Check:
    - the encryption reproduces RFC 8291's worked example;
    - round trip with a stand-in push service that decrypts the payload;
    - no push while Away is off;
    - the owner gets a lock-screen notification for a held question and taps through to it.
  - Blocked by: 5, 10 · Stories: 34, 35, 36, 38, 39, 40, 85
  - **Owner:** adds the Home Screen icon from https://desktop-jk5bn8g.tailec6188.ts.net, taps "Turn on notifications", allows them, and confirms one arrives.
  - Owner's answers (Oct 5, lane `lane/pm-11-12-13-14`, with tasks 12, 13 and 14; side-lane rule as in task 4):
    - the lane builds on `tools/project-manager-remote` after pull requests #45 and #50 merged;
    - a session's newest lock-screen notification replaces its older one (the tag is the session), since a tap opens the Questions tab or the session page, which list everything;
    - "Turn on notifications", or why it isn't possible here, sits at the top of the bell's list; once on, a short line says so, with Turn off;
    - once task 11 is pushed, the preview on port 5197 moves to `lane/pm-11-12-13-14`, and tasks 12 and 13 are built while the owner tries the notifications; task 11 is ticked once the owner confirms one arrived.
  - Built (Oct 5, 84664b7): `push.mjs` (RFC 8291 encryption, checked against its worked example; VAPID; the rules), `push-api.mjs` (keys and subscriptions in `~/.claude/lanes-board/push-keys.json` and `push-subscriptions.json`; the bell's new records pushed while Away is on), `/sw.js`. The preview on 5197 serves it, at https://desktop-jk5bn8g.tailec6188.ts.net too. Done Oct 5: the owner tried it from the phone and it worked.

### Phase D: sessions and commands

- [x] **12. The Sessions tab, the session page and its first commands.** Each session gets a page with its lane and conversation, and four commands.
  - Delivers:
    - **On the phone,** Sessions replaces Lanes: state, the app's turn summary and the context gauge, with worktrees that have no session under a Worktrees filter.
    - **A session page** with title, state, summary, gauge, branch, task and pull request, the conversation with tools folded, and a reply box. On the PC, the Sessions tab's detail gains the same header.
    - **A command bar:** Approve & continue, Show me, Stop now (stops before the next tool, then held while Away is on) and End work (for any session). Each command says whether it was delivered now, comes before the next step, or is queued.
  - Check: unit tests of the session-state rules; round-trip cases for each command's delivery; both pages by hand.
  - Blocked by: 4, 8 · Stories: 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 62
  - Owner's answer (Oct 5): Stop now refuses every tool call the session tries, telling it the owner pressed Stop now and to end its turn, until its turn ends; with Away on that turn end is then held like any other. A hard stop (as End work does) was turned down, since it leaves the session idle where only the Claude app can wake it.
  - After the gates (Oct 5, the owner's call): a held question, permission or plan answered in the app or over Remote Control is dropped and its hook released once its call has a result in the transcript, so the session no longer shows "waiting on you" for up to 24 minutes.
- [x] **13. Merge.** A session's pull request is merged from its page once it's ready.
  - Delivers:
    - **A readiness rule** over `gh pr view`'s fields (draft, mergeable, checks, behind its base), giving the reasons when the pull request isn't ready. Update branch is offered when it's behind.
    - **The merge:** a confirmation naming the pull request and its base, and the request must name the pull request the page showed. Then `gh pr merge --merge --delete-branch` runs against the repository on GitHub, never a local branch or worktree. The session is then told to update its local base and delete its local branch.
    - **A "ready to merge" notification** when a pull request turns ready.
    - **CLAUDE.md's line** that the owner's Merge in the Project Manager is the approval for that pull request.
  - Check:
    - readiness unit tests: ready, draft, failing or pending checks, conflicts, behind;
    - round trip against a stub `gh`: update, merge, and a mismatched pull request refused;
    - the tidy-up message reaches the session.
  - Blocked by: 10, 12 · Stories: 52, 53, 54, 55, 56, 57, 58
  - Owner's answers (Oct 5):
    - Merge is offered whatever the pull request's base, `master` included; the confirmation names the pull request and its base, and the tap is the approval;
    - ready needs every check on the pull request passed, skipped or neutral; a pending or failing check makes it not ready, named in the reasons.
- [x] **14. Compact and Open in the Claude app.** A session opens in the Claude app on the phone, where `/compact` and any message work.
  - Delivers:
    - the Remote Control link, read from the app's session record where task 3 found it;
    - Open in the Claude app on session pages and on questions asked in the app;
    - Compact as a sheet saying to type `/compact` there, then opening the link;
    - with no link, how to turn Remote Control on, and the Claude app's session list as the fallback.
  - Check: a unit test of reading the link from a record; the owner opens a session from the phone and compacts it.
  - Blocked by: 3, 12 · Stories: 10, 59, 60, 61
  - **Owner:** turns on "Connect new sessions to Remote Control" in the Claude app (Settings > Claude Code), and tries Compact from the phone.
  - Built (Oct 5): the link is the record's newest `bridgeSessionIds` entry at `https://claude.ai/code/<id>` (19 of the PC's 34 session records had one on Oct 5). Compact opens a panel saying to type `/compact` in the Claude app, with Copy /compact and Open in the Claude app; with no link, it says to turn on Remote Control (or type `/rc` once) and offers the app's session list. Questions asked in the app get Open in the Claude app too. Done Oct 5: the owner tried it from the phone and it worked.

### Phase E: visuals and docs

- [x] **15. Posted visuals.** Sessions publish shots and clips to their page, and the owner views them full screen.
  - Delivers:
    - **`npm run post -- <files> [--caption …] [--task …]`:** it finds the session from the shell's ids, or `--session`. Stills are copied; other video is converted to H.264 MP4 with ffmpeg, with a poster still.
    - **The media store and its index,** with a sweep that removes media older than 30 days, then the oldest beyond 5 GB.
    - **The session page's Visuals:** caption, task and time; a full-screen viewer with swipe and back; clips inline, looping and muted.
    - **"New visuals" notifications,** batched per session per minute.
  - Check:
    - post tests on fixture files (AVI conversion when ffmpeg is on the PATH, skipped otherwise);
    - retention unit tests;
    - round trip: a post shows on the session page and makes one notification;
    - the viewer checked by hand on the phone.
  - Blocked by: 10, 12 · Stories: 37, 63, 64, 65, 67, 68, 69, 70, 73
  - Owner's answers (Oct 5, lane `lane/pm-15-16-17-18`, with tasks 16, 17 and 18; side-lane rule as in task 4):
    - the lane merges `lane/pm-11-12-13-14` (pull request #57, task 12's session page) in at the start, so its pull request shows those commits too until #57 merges;
    - the checks "by hand on the phone" in tasks 15, 17 and 18 are skipped: each task is ticked once its automated checks pass;
    - a session page opens from its posted media alone (for a session older than the Sessions list's 3 days, or whose transcript was deleted), and the Sessions list gains an "Older" filter of sessions with media from the last 30 days;
    - the owner wants a session's page to show shots and media of the game or feature being worked on, as progress updates, and its documents and artifacts.
  - Built (Oct 5): `post.mjs` (`npm run post`) and `media.mjs` (the store in `~/.claude/lanes-board/media/<session>/` with its `index.json`, and the 30-day, 5 GB sweep, run at each post and hourly by the board); `media-api.mjs` serves `/media/<session>/<file>` (store files only, clips in byte ranges); the session page's Visuals and the full-screen viewer (`sessions-ui.mjs` `visualsHtml`, `mountViewer`) on both pages; the bell's "posted N visuals" record per session per minute, opening the page at its Visuals; Show me now asks for `npm run post`.
- [x] **16. Everything it looked at.** The images a session got back from its tools show on its page without it posting them.
  - Delivers: images found in the results of the session's tool calls (browser screenshots, images it opened, viewport shots), listed under Visuals and served by reference to their transcript line. Images the owner pasted are left out. The viewer is shared with task 15.
  - Check: unit tests on fixture transcript lines (an image read from a file, a browser screenshot, an MCP tool's image, a pasted image left out); the page shows them.
  - Blocked by: 15 · Stories: 66
  - Owner's answers (Oct 5): only images of the work are listed: images the session opened from its own worktree's `shots/` (renders of the game it made) and Godot or Blender viewport shots. Browser-pane screenshots, pasted images, images from outside its worktree and its subagents' images are left out.
  - Built (Oct 5): `work-images.mjs` finds them (a Read of a file under the folder the session was in when it made the call, plus `/shots/`; any tool of an MCP server named for Blender or Godot), indexing each transcript as it grows; the session page lists them as "Images of the work" under Visuals, in the same viewer, served from the transcript line at `/work/<session>/<line>-<n>`.
- [ ] **17. Docs, the pull request and artifacts.** A session's page lists what it wrote and what it published.
  - Delivers:
    - the Markdown files its Write and Edit calls name, newest first, read from the worktree or, once that's gone, from its branch in git, and rendered with the Markdown library the second brain vendors;
    - its pull request's description, checks and changed files, with a GitHub link, cached for a minute;
    - links to the artifacts it published.
    Paths are served only when the session's transcript names them and they lie inside the repo or one of its worktrees.
  - Check: unit tests of the extraction and of the path rule (a named file inside a worktree is served; an unnamed file or one outside is refused); checked by hand on the phone.
  - Blocked by: 12 · Stories: 74, 75, 76, 77, 80
  - Owner's answers (Oct 5):
    - the documents listed are the Markdown files it wrote (rendered), plus HTML pages and PDFs it wrote (opened as they are; HTML in a sandbox, so a page can't act as the Project Manager), all inside the repo or its worktrees;
    - a document whose worktree is gone is read from its branch (local, then remote), else from its merged pull request's head commit; only if all fail does it show "no longer available".
- [ ] **18. Clips, and sessions told to post.** Sessions can record a scene as a looping clip, and CLAUDE.md tells them when to post.
  - Delivers:
    - **`npm run clip -- <scene> [--seconds N] [scene args]`:** it records a scene the shots tool runs, with Godot's Movie Maker at 30 fps and 1280×720, as a looping MP4 (H.264, no audio, 6 seconds by default and 20 at most) plus a still, written into the worktree's `shots/`.
    - **CLAUDE.md:**
      - visual work posts a shot or clip with a caption at each finished step and on Show me;
      - media goes nowhere else and is never committed;
      - `post` and `clip` join Commands;
      - the Project Manager line names Away, the Questions tab and the bell.
  - Check: a clip of a shot scene plays in the phone's viewer; the Godot suite passes if the recorder changed anything under `game/`.
  - Blocked by: 15 · Stories: 71, 72
  - Owner's answer (Oct 5): `clip` only writes the MP4 and its still into `shots/`; the session posts them with `npm run post`, as any shot.

### Phase F: the owner's check

- [ ] **19. The owner's check from the phone.** The owner runs real work remotely, and the pull request is made ready.
  - Delivers: fixes from the owner's check; every task ticked here; the spec's stories ticked and its status set to built; the pull request marked ready.
  - Check: with Away on, from the phone:
    - a question answered;
    - a turn approved;
    - a lock-screen notification followed;
    - a clip watched;
    - a pull request merged;
    - a session compacted.
  - Blocked by: 9, 11, 13, 14, 16, 17, 18 · Stories: 1–87
  - **Owner:** runs the check and approves the pull request.
