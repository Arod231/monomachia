# Spec: remote session control in the Project Manager

Status: built, after the owner's check from the phone on Oct 5, 2026 (approved Oct 4, with its plan, `docs/plans/project-manager-remote.md`).

Changed Oct 6, 2026 (the owner's call): the Project Manager no longer answers anything or merges. Every permission prompt, plan and question is answered in the Claude app, Away or not; the relay hook holds nothing and only notes questions asked in the app and finished turns for the bell (its timeouts are back to 10 seconds). The Questions tab, the held items' cards, Approve & continue and the Merge panel are gone; merges are done on GitHub, or by a session the owner tells to merge or approves a merge for. The Away switch now only sends the bell's news to the phone's lock screen, and the bell's "ready to merge" says the pull request is ready to merge on GitHub. Where this spec says otherwise, this note wins.

Changed Oct 5, 2026 (the owner's call): questions (AskUserQuestion) are no longer sent to the Project Manager. They always stay in the app's own dialog, Away or not, and the relay hook only notes them, so the bell (and a push, once push lands) says "<session> is waiting on you to answer questions in the app" and the Questions tab lists them under "Asked in the app". Permission prompts, plans and turn ends still wait in the Project Manager while Away is on. Where this spec says questions wait in or are answered from the Project Manager, this note wins.

## Problem Statement

The owner runs several Claude sessions at once on the desktop PC, one per lane, and follows them from the Project Manager (`npm run board`, http://localhost:5197) on the PC and, through Tailscale, as a Home Screen web app on an iPhone. Away from the PC, three things stall:

- **Questions wait unanswered.** A session that asks something (wayfinder's questions, a permission prompt, a plan to approve, "task done, shall I go on?") stops until someone answers it in the Claude app on the PC. The phone page only shows "Open on PC". The PC page can answer a session, but only one switched on by hand beforehand, and that relay has never run on this PC.
- **Visual work can't be seen.** Godot doesn't run on the phone, so new looks, animations, arenas and effects can't be judged until the owner is back. Sessions already take shots and record video into their worktree's `shots/` folder, but nothing sends them anywhere, and the folder disappears with its worktree. The milestone-1 plan's "sheets and shots the owner looks at" have no way to reach the owner.
- **Nothing can be steered.** A finished pull request can't be merged, a full context can't be compacted, a session going the wrong way can't be stopped, and nothing alerts the owner that a session needs them.

## Solution

The Project Manager becomes the place to run sessions from the phone:

- **An Away switch.** While it's on, every session's permission prompts, plan approvals and turn ends wait in the Project Manager instead of the app's dialogs (questions stay in the app since Oct 5; the bell says when one waits). A session that finishes its turn waits there too, so a reply or command sent hours later still reaches it. Switching Away off hands everything back to the app.
- **A Questions tab** lists everything waiting, from every session, answerable in a tap or two, with the same options, descriptions and previews the app shows. The session carries on as if the owner had answered in the app.
- **A bell** on every page lists questions, finished turns, pull requests ready to merge and new visuals. While Away is on, the same events arrive as iPhone lock-screen notifications, end-to-end encrypted.
- **A page per session** shows its state, its lane, the shots and looping clips it posted, every image it got back from its tools, the Markdown documents it wrote, its pull request and the artifacts it published, plus its conversation and a reply box.
- **Commands per session:** Approve & continue, Show me (capture and post a fresh shot or clip), Merge (the Project Manager merges the pull request after checks), Compact (opens the session in the Claude app over Remote Control, where `/compact` works), Stop now, End work, and Open in the Claude app.
- **Two small tools for sessions:** `npm run post` publishes shots and clips to the session's page, and `npm run clip` records a scene as a looping MP4 with a still. CLAUDE.md tells visual work to post at each finished step.

## User Stories

### Away and routing

1. [x] As the owner, I want one Away switch on the phone and PC pages, so that I can send every session's questions to the Project Manager before I leave the PC.
2. [x] As the owner, I want to switch Away on from my phone as well, so that I can start managing sessions remotely after I've already left.
3. [x] As the owner, I want the Away switch to show how many items are waiting for me, so that I know at a glance whether anything is stuck.
4. [x] As the owner, I want switching Away off to hand every held question back to the app's own dialogs, so that I answer at the PC as usual when I'm back.
5. [x] As the owner, I want sessions that finish their turn while I'm away to wait for my reply instead of going idle, so that a reply or command I send hours later still reaches them.
6. [x] As the owner, I want a held item to give up after 24 minutes, so that a forgotten session doesn't wait forever.
7. [x] As the owner, I want "Hand back to the app" on any held item, so that I can leave one item for the PC.
8. [x] As the owner, I want a reply to a session in the middle of a turn to reach it before its next step, so that I can steer it without waiting for the turn to end.
9. [x] As the owner, I want a reply to a session the Project Manager can't reach right now to be queued for its next turn end, so that nothing I send is lost.
10. [x] As the owner, I want questions already showing in the app when I switch Away on to appear in the Questions tab, read-only, with "Open in the Claude app", so that I can still answer them remotely.
11. [x] As the owner, I want the per-session "Answer from Project Manager" switch replaced by Away, so that there's nothing per session to remember.
12. [x] As a session, I want to carry on exactly as if the owner had answered in the app, so that the Project Manager changes nothing about how I work.

### The Questions tab

13. [x] As the owner, I want a Questions tab listing every question, permission prompt, plan approval and finished turn waiting on me, across all sessions, so that I can clear them in one place.
14. [x] As the owner, I want items grouped by session, with the session's name, its task and how long it has waited, so that I know the context before answering.
15. [x] As the owner, I want each question's header, text, options and option descriptions shown, so that I can answer as well as I could in the app.
16. [x] As the owner, I want option previews (mockups) shown in a readable monospace block, so that layout questions make sense on the phone.
17. [x] As the owner, I want to pick several options on a multi-select question, so that I can answer it fully.
18. [x] As the owner, I want an "Other" box under each question, so that I can give my own answer.
19. [x] As the owner, I want one Send for all the questions a session asked together, so that it gets a complete set of answers.
20. [x] As the owner, I want to reply in free text instead of picking options, so that I can redirect a session that asked the wrong question.
21. [x] As the owner, I want a permission prompt to show what the session wants to run, with Allow, Always allow (naming the rule it adds) and Deny with a reason, so that I can approve commands remotely.
22. [x] As the owner, I want a plan approval to show the plan rendered, with Approve and Reject with a reason, so that I can approve plans from my phone.
23. [x] As the owner, I want a finished turn to show the app's turn summary and the session's last message, with Approve & continue, Show me and a reply box, so that I can keep a session moving in one tap.
24. [x] As the owner, I want an answered item to leave the list at once while the session carries on, so that I can see my answer went through.
25. [x] As the owner, I want to be told when an item was already answered, handed back or timed out, so that I don't answer twice.
26. [x] As the owner, I want the Questions tab to show a count of what's waiting, so that I notice it from any tab.
27. [x] As the owner, I want the PC page to have the same Questions tab, so that I can answer from the PC's browser too.

### Notifications

28. [x] As the owner, I want a bell with an unread count at the top of every page, so that I see new events wherever I am in the Project Manager.
29. [x] As the owner, I want the bell to list questions and approvals, finished turns, pull requests ready to merge and new visuals, newest first, so that I can catch up after being away.
30. [x] As the owner, I want tapping a notification to open the exact question, session page or merge it's about, so that I get there in one tap.
31. [x] As the owner, I want read state shared between my phone and the PC, so that I don't clear the same notifications twice.
32. [x] As the owner, I want "Mark all read", so that I can clear the bell in one go.
33. [x] As the owner, I want notifications kept for 7 days, so that the list stays short.
34. [x] As the owner, I want lock-screen notifications on my iPhone while Away is on, so that I learn a session needs me without the page open.
35. [x] As the owner, I want no lock-screen notifications while Away is off, so that my phone stays quiet while I'm at the PC.
36. [x] As the owner, I want each lock-screen notification to say which session and what it needs in one line, so that I can decide whether to act now.
37. [x] As the owner, I want several visuals posted by one session within a minute to arrive as one notification, so that a busy session doesn't flood my phone.
38. [x] As the owner, I want notification content encrypted end to end with my phone's key, so that Apple's push service can't read what my sessions are doing.
39. [x] As the owner, I want a "Turn on notifications" button in the Home Screen app, so that I can grant permission the way iOS requires.
40. [x] As the owner, I want the page to tell me when lock-screen notifications aren't possible (opened in a Safari tab, or from the plain-HTTP address), so that I know how to fix it.
41. [x] As the owner, I want the Project Manager to accept my actions from its HTTPS address, so that a Home Screen app made from that address works fully.

### Sessions and the session page

42. [x] As the owner, I want the phone's Lanes tab replaced by a Sessions tab, so that each session is one place with its lane, visuals, docs and commands.
43. [x] As the owner, I want worktrees with no session listed under a Worktrees filter, so that I don't lose sight of parked lanes.
44. [x] As the owner, I want each session's card to show its state (at work, waiting on you, asked in the app, idle, ended) and the app's turn summary, so that I can scan all sessions quickly.
45. [x] As the owner, I want the session page to open with its title, state, context gauge, branch, task and pull request, so that I know where it stands.
46. [x] As the owner, I want the session's recent conversation with tool calls folded away, and a reply box, so that I can follow and steer it.
47. [x] As the owner, I want the PC page's Sessions tab to gain the same visuals, docs and commands, so that both pages work the same way.

### Commands

48. [x] As the owner, I want Approve & continue, so that I can pass a session's after-task approval in one tap.
49. [x] As the owner, I want Show me, so that a session captures and posts a fresh shot or clip of what it's working on.
50. [x] As the owner, I want Stop now, so that I can halt a session at its next step when it's going wrong and, with Away on, have it wait for my next instruction.
51. [x] As the owner, I want End work for any session, so that I can stop a session for good and leave its branch and pull request as they are.
52. [x] As the owner, I want Merge on a session whose branch has an open pull request, so that I can merge finished work from my phone.
53. [x] As the owner, I want Merge to show whether the pull request is ready (out of draft, checks passed, no conflicts, up to date with its base) and, if not, why, so that I don't merge broken work.
54. [x] As the owner, I want "Update branch" when the pull request is behind its base, so that it takes in the base's changes and its checks run again before I merge.
55. [x] As the owner, I want a confirmation naming the pull request and its base before the merge, so that I never merge by accident.
56. [x] As the owner, I want the merge to use a merge commit and delete the remote branch, so that history stays the way CLAUDE.md keeps it.
57. [x] As the owner, I want the session told its pull request was merged and asked to tidy up its local branch, so that its worktree doesn't drift.
58. [x] As the owner, I want my Merge tap to count as the approval CLAUDE.md asks for, so that no session waits for a second approval.
59. [x] As the owner, I want Compact to open the session in the Claude app, where `/compact` works, so that I can compact a session remotely.
60. [x] As the owner, I want "Open in the Claude app" on every session that has Remote Control, so that I can message a session the Project Manager can't reach.
61. [x] As the owner, I want to be told how to turn on Remote Control when a session has no link, so that I can fix it.
62. [x] As the owner, I want every command to say whether it was delivered now, will arrive before the session's next step, or is queued for its next turn end, so that I know what happens next.

### Visuals

63. [x] As the owner, I want each session's posted shots and clips on its page, with caption, time and task, so that I see visual progress without opening Godot.
64. [x] As the owner, I want to tap a shot or clip to see it full screen, swipe between them and go back to the session, so that I can review them comfortably on the phone.
65. [x] As the owner, I want clips to play inline, looping and silent like GIFs, so that animations are easy to judge.
66. [x] As the owner, I want every image the session got back from its tools (screenshots, images it opened) under "Everything it looked at", so that I see what it saw even when it didn't post.
67. [x] As the owner, I want media kept on the PC for 30 days with a 5 GB cap, oldest deleted first, so that it never fills the disk.
68. [x] As the owner, I want media kept after a lane's worktree is removed, so that I can look back at finished work.
69. [x] As the owner, I want media never committed, so that renders made from paid assets never reach the public repo.
70. [x] As a session, I want `npm run post -- <files> --caption "…"` to publish shots and clips to my page, so that the owner sees my visual work.
71. [x] As a session, I want `npm run clip -- <scene> --seconds N` to record a scene as a looping MP4 with a still, so that I can show animations.
72. [x] As a session, I want CLAUDE.md to tell me when to post (each finished visual step, and on Show me), so that the owner gets visuals without asking.
73. [x] As a session, I want `post` to convert AVI and other video to MP4 for me, so that the existing video tools' output plays on the phone.

### Docs

74. [x] As the owner, I want each Markdown file a session created or changed, rendered for the phone, so that I can read its specs, plans and reviews remotely.
75. [x] As the owner, I want a document to still open after its worktree is gone (read from the branch in git), so that finished lanes stay readable.
76. [x] As the owner, I want the session's pull request with its description, checks and changed files, so that I can review it before merging.
77. [x] As the owner, I want the claude.ai artifacts a session published, as links, so that I can open its reports and guides.

### Setup and safety

78. [x] As the owner, I want the Project Manager reachable only from my tailnet, as now, so that nobody else can answer my sessions or merge.
79. [x] As the owner, I want actions accepted only from the Project Manager's own pages, so that no other site can trigger them.
80. [x] As the owner, I want the Project Manager to serve only media from its own store and Markdown files a session wrote inside its repo or worktree, so that it can't be used to read other files.
81. [x] As the owner, I want the page to tell me when the installed hooks are older than the ones in the repo, so that I know to reinstall them.
82. [x] As the owner, I want to be asked before the hooks in my user settings change, so that I stay in control of what runs in every session.

### Developer

83. [x] As a developer, I want the relay's rules (what a hook holds, when it lets go, how an answer is shaped) in pure modules with unit tests, so that they're easy to change safely.
84. [x] As a developer, I want round-trip tests that run the real hooks against a real Project Manager server with throwaway folders, so that the whole path from a session to the phone and back is covered.
85. [x] As a developer, I want the push encryption tested against the RFC's published example, so that pushes decrypt on the phone.
86. [x] As a developer, I want this feature's plan followed on the Project Manager as "PM", so that its tasks can be watched and launched like any other plan's.
87. [x] As a developer, I want a spike on a live session before the rest is built, so that the undocumented parts are proven first.

## Implementation Decisions

### Decisions in plain English

The owner's answers from the Oct 4 interview.

| Question | Answer |
|---|---|
| One spec or several, and in what order? | One spec and one plan. Questions first: the Questions tab and routing, then notifications, then commands, then the session page's visuals and docs. |
| When do sessions send their questions to the Project Manager? | While the Away switch is on. It's flipped by hand on the phone or the PC (no automatic Away), and it replaces the per-session switch. |
| What does Away hold? | Questions, permission prompts (plan approvals included) and turn ends, until answered, handed back, Away goes off, or 24 minutes pass (the owner, Oct 4: 25 minutes is enough). |
| How do notifications reach the owner? | A bell on every page, always; iPhone lock-screen notifications only while Away is on, through Web Push to a Home Screen app made from the HTTPS address. |
| Which events notify? | Questions and approvals, finished turns, pull requests ready to merge, new visuals. |
| How do visuals reach a session's page? | Posted by the session with a caption (`npm run post`), plus every image it got back from its tools, listed apart. |
| Clip format? | Looping MP4 (H.264) with a still. No GIF. |
| Who merges? | The Project Manager, with `gh`, after its checks and the owner's confirmation; the session tidies up afterwards. |
| Which commands? | Approve & continue, Show me, Merge, Compact, Stop now, End work, Open in the Claude app. |
| How does Compact work? | It opens the session in the Claude app over Remote Control, where the owner types `/compact`. The owner turns on "Connect new sessions to Remote Control". |
| Which documents does a session page list? | Markdown files it created or changed, its pull request, artifacts it published. Not its commits. |
| Phone tabs? | Overview, Sessions, Questions, Plans, Launch, with the bell top right. Sessions replaces Lanes. |
| How long is media kept? | 30 days with a 5 GB cap, oldest deleted first, outside the repo. |
| How is it tested? | Round-trip tests (real hooks, real server, throwaway folders) and rule unit tests; the owner checks the phone pages; a live spike comes first. |
| Is the plan on the board? | Yes, as plan "PM", outside the roadmap's game phases. |
| Launched sessions that wait for Enter on the PC? | Out of scope: a separate follow-up, since done (pull requests #39 and #43: the board presses Send through Windows UI Automation). |
| Where does the work go? | Branch `tools/project-manager-remote` from `feature/godot-rebuild`, with a pull request into it (retargeted to `master` if the consolidation merges the rebuild first). |

### What exists today

- **The relay hook** (`relay-hook.mjs`, installed as a PermissionRequest and a Stop hook in user settings) hands a session's permission prompts, questions and turn ends to the PC page for sessions switched on in `~/.claude/lanes-relay/on.json`, waiting 20 minutes each. Its answer to a question has only been tried with the hook script, never on a live session. The relay folder doesn't exist on this PC yet.
- **The stop hook** (`stop-hook.mjs`, PreToolUse and Stop) ends a launched lane's session from "End work".
- **The PC page's Sessions tab** shows every session of the last three days with its context gauge and, for switched-on sessions, answers them. The phone page lists sessions read-only.
- **Tailscale Serve** has served the Project Manager at https://desktop-jk5bn8g.tailec6188.ts.net (tailnet only) since Oct 4, but the Project Manager refuses actions from that origin.
- **Facts the design rests on** (found Oct 4): no Claude app link or local interface can type into an existing session or run a slash command in it; Remote Control can, from the Claude phone app or claude.ai/code. The app never submits a new session's first prompt on its own. A session's shell carries its own ids (`CLAUDE_CODE_SESSION_ID`, and `CLAUDE_CODE_HOST_SESSION_ID` for the app's `local_…` id). Images a session gets back from its tools are stored inside its transcript. The app writes a short summary when each turn ends (status completed, review ready, blocked, needs input or failed) into its session record. ffmpeg 9 is installed and on the PATH.

### The Away switch and the relay

- **One switch, in a file.** The relay folder (`~/.claude/lanes-relay`, `LANES_RELAY` overrides it) gets an Away file (on or off, since when, from which device) in place of the per-session list. Both pages show the switch in their header with the number of items waiting.
- **The relay hook decides per event:**
  - *PermissionRequest, Away on:* (since Oct 5, AskUserQuestion is never held: Away on or off, it is noted as asked in the app and left to the app's dialog.) It writes a held item (a question for AskUserQuestion, a plan for ExitPlanMode, a permission for anything else) and waits for an answer, a hand-back, Away going off, or 24 minutes. A question is answered as Claude Code's own hosts answer it: allow, with the tool's input passed back plus an `answers` map (question text to the chosen label, several labels joined with ", ", free text for "Other"), or a `response` for a free-form reply. A permission is allowed (optionally with the suggested rule), or denied with the owner's reason; a plan is approved, or rejected with the reason.
  - *Stop, Away on:* a reply already queued for the session goes in at once. Otherwise it holds the turn end, with the session's last message, and waits the same way. The owner's reply, or a command's message, continues the session ("The owner replied from the Project Manager: …").
  - *Either event, Away off:* it records an event for the bell (asked in the app, turn finished) and exits at once, so the session runs as it does today. With no relay folder at all, it exits before reading anything, as now.
- **Messages to a working session** (a reply, Approve & continue, Show me, the merge tidy-up) wait in a per-session inbox in the relay folder. The PreToolUse hook, which already runs before every tool call, adds the oldest as context before the next tool runs. No extra process per tool call. A turn end takes what's left.
- **Sessions the hooks can't reach** (idle since before Away went on, or with Away off): commands queue in the inbox for the session's next turn end, and the page offers Open in the Claude app.
- **Going off.** Switching Away off releases every held item: questions and permissions go back to the app's dialogs, held turn ends simply end.
- **The 24-minute limit** is the hook's own (`LANES_RELAY_WAIT_MS` overrides it for tests). The installed hooks' timeouts are 25 minutes, a minute longer, so the hook always gives up and clears its card before Claude Code ends it. It was 24 hours until the owner settled on 25 minutes (Oct 4), the timeout `~/.claude/settings.json` already had.
- **Stop now** stops the session before its next tool call and ends its turn; with Away on, that turn end is held like any other, so the session waits for the owner. **End work** keeps today's behaviour (the lane is ended and takes no task), for any session, launched or not.
- **The fallback**, if the spike shows a hook can't answer AskUserQuestion: the hook declines the question with the owner's answers as the reason, which Claude reads and follows.

### The Questions tab

- **One list** made from the held items, oldest first, grouped by session (title, plan task, waiting time). Questions already showing in the app (found in transcripts, as the PC page does now) appear read-only with Open in the Claude app.
- **Item kinds:**
  - Questions: header chip, text, options with descriptions, previews in a monospace block (escaped, never run as HTML), multi-select, "Other", a free-form reply, and one Send per call.
  - Permissions: the command or edit, with Allow, Always allow (naming the rule), and Deny with a reason.
  - Plans: rendered Markdown, with Approve, and Reject with a reason.
  - Turn ends: the app's turn summary (it is written while the turn end is held, as the spike showed) and the session's last message, with Approve & continue, Show me, and a reply box.
- **Every answer** checks that the item is still held. Late answers get "already answered, handed back or timed out". A count badge sits on the tab, and the Overview's "Waiting on you" links here.

### Notifications and lock-screen push

- **Events** become notification records: a held question, permission or plan (or one asked in the app); a finished turn; a pull request that turns ready to merge; posted visuals, batched per session per minute. Records live in `~/.claude/lanes-board/notifications.json` with a shared read flag, trimmed after 7 days. Each record names its target (question, session page, merge sheet).
- **The bell** shows the unread count on every page and opens the list; tapping a record marks it read and goes to its target.
- **Lock-screen push** goes out only while Away is on, for the same events. Rules:
  - It needs a secure page. The Project Manager accepts actions from its HTTPS origin (`https://<pc>.<tailnet>.ts.net`, through Tailscale Serve) as well as today's addresses.
  - A service worker at the site root shows each push and opens its target on tap. The manifest makes the page a standalone Home Screen app.
  - The page offers "Turn on notifications" only inside the Home Screen app over HTTPS, and explains why otherwise.
  - Subscriptions and the VAPID key pair live in `~/.claude/lanes-board/` and are never committed. A subscription the push service rejects as gone is dropped.
  - The payload (title, one line, target, a tag so repeats replace each other) is encrypted for the phone (RFC 8291, aes128gcm) and signed with VAPID (RFC 8292), built with `node:crypto` (no new dependency).

### The session page and commands

- **The phone's Sessions tab** (replacing Lanes) lists sessions with state, the app's turn summary and context gauge. Worktrees with no session sit under a Worktrees filter, and each lane's git facts move onto its session page.
- **A session page:**
  - At the top: title, state, turn summary, context gauge, branch, task and pull request.
  - A command bar: Approve & continue, Show me, Merge, Compact, Stop now, End work, Open in the Claude app.
  - Then Visuals, Docs, and the Conversation with a reply box.
  - The PC page's Sessions tab gains the same parts, and its per-session switch goes.
- **Approve & continue** sends "Approved from the Project Manager: go on with the next task." **Show me** asks the session to capture a shot or short clip of what it's working on and post it with a one-line caption, or to say in one line that there's nothing to show yet. Both go through the inbox, and each command's reply says whether it was delivered, comes before the next step, or is queued.
- **Merge** appears when the session's branch has an open pull request:
  - Ready means out of draft, mergeable, every check passed, and not behind its base. A pure rule turns `gh pr view`'s fields into "ready", or the reasons it isn't.
  - Behind its base: "Update branch" asks GitHub to merge the base in (`gh pr update-branch`), and the checks run again.
  - Ready: a confirmation names the pull request and its base, then `gh pr merge --merge --delete-branch` runs against the repository on GitHub, never touching a local branch or worktree. The session is then told its pull request merged and asked to update its local base and delete its local branch.
  - CLAUDE.md gains a line: the owner's Merge in the Project Manager is the approval for that pull request.
- **Compact and Open in the Claude app** open the session's Remote Control address (built from the bridge session id in the app's session record), where `/compact` and any message work. With no Remote Control link, the sheet says to turn on "Connect new sessions to Remote Control" or type `/rc` in the session once. The spike confirms where the link comes from; the fallback opens the Claude app's session list.

### Visuals and documents

- **`npm run post -- <files> [--caption "…"] [--task <ref>]`**:
  - It copies stills (PNG, JPEG, WebP, GIF) and clips into `~/.claude/lanes-board/media/<session>/`, with an index entry: caption, task, time, source path, size, kind.
  - It finds the session from the shell's own ids, or `--session` when run by hand.
  - It converts other video (AVI from the Movie Maker tools, MOV, WebM) to H.264 MP4 with ffmpeg and makes a poster still.
  - The Project Manager notices new entries on its next pass; no network call is needed.
- **`npm run clip -- <scene> [--seconds N] [scene args]`** records a scene the shots tool can run, with Godot's Movie Maker at a fixed 30 fps and 1280×720. It writes a looping MP4 (H.264, `yuv420p`, `+faststart`, no audio; 6 seconds by default, 20 at most) and a still into the worktree's `shots/`. If the shot scene runner needs a recording flag, that change is in `game/tools/`.
- **Everything it looked at:** images found in the session's transcript, in the results of its tools (browser screenshots, images it opened, Blender viewport shots), served by reference to the transcript line. Images the owner pasted are left out.
- **Retention:** a sweep removes media older than 30 days, then the oldest beyond 5 GB in total.
- **Docs:**
  - The Markdown files named by the session's Write and Edit calls, newest first, read from the worktree, or from the session's branch in git once the worktree is gone. They're rendered with the Markdown library the second brain already vendors.
  - Its pull request: description, checks, changed files and a GitHub link, cached for a minute.
  - Artifacts it published: links found in its Artifact tool results.
- **CLAUDE.md** tells sessions:
  - Visual work posts a shot or clip, with a caption, at each finished step and whenever the owner asks to be shown.
  - `post` and `clip` join the Commands list.
  - Media goes nowhere else and is never committed.

### Hooks to install

The tracked hooks stay dependency-free and exit at once when nothing concerns the session.

- The relay hook gains Away, the event records and the 24-minute holds.
- The stop hook gains inbox delivery and Stop now.
- The install (copying them to `~/.claude/hooks/` and raising the PermissionRequest and Stop timeouts to 25 minutes in `~/.claude/settings.json`) waits for the owner's OK, as before.
- The page compares the installed copies with the tracked ones and says when they're out of date.

### Security

- The same locks as today: binds on loopback and the PC's Tailscale addresses only, requests only from loopback or the tailnet with a known Host, and actions only as JSON from the Project Manager's own origin. HTTPS through Serve is added to that origin list; requests through Serve arrive from loopback.
- Media is served only from the media store or a transcript reference. Documents are served only for paths the session's transcript names, and only inside the repo or one of its worktrees.
- Merge and End work ask for confirmation. The merge request must name the pull request the page showed.

### The plan on the board

The Project Manager follows `docs/plans/project-manager-remote.md` as plan "PM" (flat kind, branch `tools/project-manager-remote`, into `master` since the Godot rebuild branch merged there on Oct 5) on the Progress and Graph tabs, outside the roadmap's phases. Launch branches are `lane/pm-<ids>`, and commit subjects name tasks as "(PM task N)".

## Testing Decisions

- **What a good test checks:** behaviour seen from outside, meaning what a session receives back from its hook, what the web API returns, and what lands in the state folders. It doesn't check how a module gets there.
- **The round trip** (the main seam):
  - Tests start the real Project Manager server on a spare port. `LANES_LOCAL_ONLY`, and `LANES_STATE`, `LANES_RELAY`, `LANES_STOP_FILE` and `LANES_PROJECTS` pointed at throwaway folders, plus a tiny fixture repository for `REPO`.
  - They spawn the real hooks with fixture events and drive the API as the phone does.
  - Cases: Away on and off; a question answered (single, multi and Other); a free-form reply; permission allow, always and deny; plan approve and reject; a held turn answered by a reply and by Approve & continue; inbox delivery before the next tool; Away off releasing held items; the hold limit (shortened); a late answer; Stop now and End work.
  - Also: a posted still and clip appearing on the session page with a notification; merge readiness and merge against a stub `gh`; a push delivered to a local stand-in push service.
- **Rule tests** (pure modules):
  - Transcript extraction: images from tool results, Markdown files written, artifact links.
  - Merge readiness from `gh` fields.
  - Notification rules: which events, batching visuals per minute, read state, the 7-day trim, push only while Away is on.
  - The relay's hold and answer rules.
  - Media retention (age, then size).
  - Push: RFC 8291 encryption checked against the RFC's worked example, and the VAPID token's shape.
- **Prior art:** `tests/lanes-board-sessions.test.mjs` already spawns the relay hook against a temporary relay folder, and `tests/lanes-board*.test.mjs` test the board's pure modules. The tests use whichever runner the base branch has when the task starts: Vitest today; `node --test` once the consolidation's task 26.1 (PR #34) merges.
- **The spike first:** on a throwaway live session, prove each of these on the desktop app:
  - a question answered through the hook;
  - a held prompt and a held turn end lasting longer than today's 25-minute hook timeout;
  - delivery before the next tool;
  - where the Remote Control link comes from.
  The results are recorded in the plan; anything that fails switches to its fallback before the rest is built.
- **By hand:**
  - The owner checks the phone pages on the iPhone: the Home Screen app over HTTPS, a lock-screen notification arriving and opening its target, and a clip playing inline.
  - The PC page is checked in the Browser pane.
- **Before each commit:** the web test and typecheck commands (`npm run test:web` and `npm run typecheck:web` today, or what the consolidation renames them to). The Godot suite runs only for a commit that touches `game/`, which the clip recorder may.

## Out of Scope

- Starting a launched session without someone pressing Enter on the PC: done separately (pull requests #39 and #43). The same work found that the app turns a leading "/" in a link's prompt into "／", so no link can run a slash command, which backs Compact handing off to the Claude app.
- Running `/compact` or any other slash command from the Project Manager itself; Compact hands off to the Claude app.
- Waking a session that isn't waiting in a hook; Remote Control does that.
- Changing the Claude app's settings (such as the Remote Control default) from the Project Manager.
- Turning Away on automatically (by PC idle time or lock).
- Push through third-party services (ntfy, Pushover, email), and testing on Android.
- Reaching the Project Manager from outside the tailnet (no Tailscale Funnel).
- GIF output, and committing any media.
- A session's commit list on its page.
- Editing files or reviewing diffs line by line from the phone.

## Further Notes

- **Doc check.** This is tooling, not gameplay: `docs/design.md` and `docs/mvp-spec.md` are unchanged and nothing here contradicts them. CLAUDE.md changes as listed above (posting visuals, the two new commands, Merge from the Project Manager as approval), and its Project Manager line gains the Questions tab, Away and the bell.
- **The owner's setup:**
  1. HTTPS certificates on in the Tailscale admin console (done Oct 4).
  2. Tailscale Serve for port 5197 (done Oct 4; `tailscale serve --https=443 off` undoes it).
  3. "Connect new sessions to Remote Control" on in the Claude app (Settings > Claude Code), and `/rc` once in sessions started before that.
  4. After the push task lands: add the Home Screen icon again from https://desktop-jk5bn8g.tailec6188.ts.net and tap "Turn on notifications"; the old icon can go.
  5. An OK for the hook install.
- **Risks the spike settles:**
  - The hook answer to AskUserQuestion is documented for SDK hosts (`canUseTool`), not for hooks.
  - Long hook timeouts in the desktop app are untried.
  - The Remote Control link's source in the app's session record is unconfirmed.
  - Lock-screen push to a Home Screen app on a `ts.net` name is untried on this phone.
- **The consolidation** (PR #34 and on) moves the Node tests to `node --test`, removes the web toolchain and renames npm scripts; this work follows whatever the base has when each task starts. When task 26.4 merges the rebuild into `master`, this branch's pull request is retargeted to `master`.
