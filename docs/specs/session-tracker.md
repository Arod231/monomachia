# Spec: session tracker, stage docs and feedback sidebar

Status: draft, written 2026-10-02. Branch `tools/session-tracker`, pull request into `feature/godot-rebuild`.

## Problem

The progress dashboard (http://localhost:5199) shows build-order progress by stage and by lane, but not by Claude Code session. To see what a session is doing, the owner has to open it and read its transcript. To steer it, the owner has to type into it. There is no view of the stage's documentation next to the progress, and no way to comment on that documentation.

The dashboard is also untracked: it lives in the main checkout's `.claude/progress-dashboard/`, which is listed in `.git/info/exclude`. So it has no history, no review and no tests, and worktree sessions can't edit it, because a hook blocks writes to the main checkout's `.claude/`.

## Goals

1. Make the dashboard a tracked project tool in `tools/progress-dashboard/`, with tests.
2. List every Claude Code session for Monomachia on the dashboard, with the live ones first.
3. Give each session its own page that shows:
   - the documentation for the stage it is working on;
   - each task in that stage as a tile: done tasks marked, the current task flashing green;
   - links from each tile to that task's section of the documentation.
4. An optional feedback sidebar on the session page. The owner highlights passages, attaches notes, writes an overall message and sends it. The feedback reaches that session's Claude at the end of its current turn, or with the owner's next prompt if the session is idle.

## Non-goals

- Starting, stopping or resuming sessions from the dashboard, or waking an idle session.
- A separate LLM that replies in the sidebar. The owner chose delivery into the working session only.
- Editing the plan or spec from the page. Feedback asks the session to make changes; the page doesn't write docs itself.
- Sessions of other projects.
- Showing transcript content (messages, tool calls). Only metadata is read.
- New features for the existing progress view (the estimates work is a separate change; see Risks).

## Decisions (from the brainstorm, 2026-10-02)

| Question | Answer |
|---|---|
| Where feedback goes | Into the session being viewed, through a hook. No API key, no separate reviewer. |
| Docs shown | Each task's block from the plan, plus the spec user stories its `Stories:` line names. Research notes are not shown. |
| How to annotate | Select text, then attach a note to it. Plus one overall message. Sent together. |
| Which sessions | All of them, newest first. Live ones pulse. Sessions inactive for over 24 h fold into a collapsed "Earlier (n)" group. |
| Colours | Working is now pulsing green. Next up moves from green to a teal outline. Done stays blue. |
| Tracked or local | Tracked and committed, with this spec and its plan. |
| Base branch | `feature/godot-rebuild`, like the other lanes. The dashboard reads that branch's plan and lane branches, and `docs/specs` and `docs/plans` only exist there. It reaches `master` with the rebuild. |
| Where it lives | `tools/progress-dashboard/`. A normal folder that any checkout can edit and test. |
| Code layout | The sessions feature goes in its own modules. The existing server and page only gain small additions (routes, a Sessions section). |
| Hook registration | An install script copies the hook into `~/.claude/hooks/session-feedback/` and adds two entries to the user settings, `~/.claude/settings.json` (Stop and UserPromptSubmit). This is a persistent change the owner approved on 2026-10-02. |

## Layout

```
tools/progress-dashboard/
  server.mjs          existing server: progress data (/data) and static pages, plus the new routes
  index.html          existing dashboard page, plus a Sessions section
  repo.mjs            finds the main checkout (REPO)
  sessions.mjs        reads the Claude Code transcripts into session records
  stage.mjs           works out a session's stage and current task from the lane data
  docs.mjs            cuts task blocks and stories out of the plan and spec
  markdown.mjs        a small, safe Markdown renderer (server tests and page)
  feedback.mjs        the feedback queue (append, read, mark delivered, lock)
  feedback-hook.mjs   the Stop / UserPromptSubmit hook
  install-hook.mjs    copies the hook to ~/.claude/hooks/ and registers it; --uninstall removes it
  routes.mjs          the /api/* and /session/* routes
  session.html        the session page
  tests/              node --test tests and fixtures
```

`package.json` gains:
- `"dashboard": "node tools/progress-dashboard/server.mjs"`;
- `"test:dashboard": "node --test tools/progress-dashboard/tests/"`;
- `test:dashboard` appended to `test`, so `npm test` runs it.

CLAUDE.md's Commands section gets a line for `npm run dashboard`. The files are plain ES modules with no dependencies. They aren't in `tsconfig.json`'s `include`, so `npm run typecheck` doesn't cover them.

## Finding the main checkout (`repo.mjs`)

- **Default:** `REPO` is the first worktree in `git worktree list --porcelain`, which is always the main checkout, run from the dashboard's own folder. So the dashboard shows the same data whether it runs from the main checkout or from a lane's worktree.
- **Override:** the `REPO` environment variable, if set.
- **Port:** `PORT` (default 5199) still chooses the port. A second copy for testing runs on 5198.

## Data sources

### Sessions (`sessions.mjs`)

- **Where:** every `*.jsonl` directly inside `~/.claude/projects/<dir>/`, for each `<dir>` whose name starts with REPO's project prefix. Claude Code makes that prefix from the path by turning every character other than a letter or digit into `-` (for this repo, `C--Users-Win11-Desktop-Monomachia`). This takes in the main checkout, `.claude/worktrees/*` and the sibling `Monomachia-*` folders.
- **What each session gives:**
  - `id`: the file name without `.jsonl`;
  - `title`: the last `custom-title` record's `customTitle`. If there is none, the first user prompt cut to 80 characters. If there is neither, the short id.
  - `cwd` and `branch`: from the last record that has `cwd` / `gitBranch`;
  - `lastActive`: the file's modified time;
  - `live`: true if `lastActive` is within 3 minutes.
- **Reading:** transcripts can be tens of MB, so only the first 64 KB and the last 256 KB are read. If the last 256 KB has no title, cwd or branch, the reader steps back 256 KB at a time, up to 4 MB, before giving up and using what the head held.
- **Cache:** results are cached per file by size and modified time, so a refresh rereads only the files that changed.
- **Malformed lines:** a line that isn't valid JSON (for example a partial line at a chunk edge) is skipped.

### A session's stage and current task (`stage.mjs`)

Reuse the dashboard's existing lane model (`collect()` in `server.mjs`):

1. **A lane branch:**
   - `godot/stage-N-*` gives stage N.
   - Any other `godot/*` branch (off-plan work) gives no stage.
2. **The title, for any other branch:**
   - "Stage N" gives stage N.
   - Otherwise, the first task id in the title (for example "tasks 14.3–14.9" gives 14.3) gives the stage holding that id.
3. **The main lane:** on `feature/godot-rebuild`, a title naming no stage gives the stage of the main lane's current task (that lane's `task` in the existing lane data). The title goes first because the main checkout holds sessions from every past stage: "Stage 3 completion" is stage 3, not today's.
4. **Otherwise:** no stage. A stage number that isn't in the build order also counts as no stage.

- **Current task:** each lane's `task` and `state` go to one session only, the newest that matches it:
  - first, the newest session whose `cwd` is the lane's worktree;
  - otherwise, the newest session on the lane's stage that has no lane yet.

  Older sessions in the same folder or stage get no current task, so a finished session never pulses as working. Off-plan lanes are matched by folder only. The session record carries the lane's `state` (working, next, blocked, finished, idle, offplan), so the page needs no state rules of its own.
- **Task states in a stage:** a task is one of:
  - done, if it is in the existing `done` set;
  - working, if it is in the existing `working` set (any lane);
  - next, if it is in the existing `next` set;
  - blocked, if it isn't done and one of its blockers isn't done;
  - not started, otherwise.

### Docs (`docs.mjs`)

- **Source:** the plan (`docs/plans/godot-rebuild.md`) and the spec (`docs/specs/godot-rebuild.md`), read from REPO's working tree. This is the same plan text the dashboard already parses.
- **Task block:** the task's line `- [ ] **ID Title**` plus every following line indented deeper than it, up to the next line at the same or a shallower indent. The block is stripped of its leading indent.
- **Stories:** the ids after `Stories:` in the block's `Blocked by:` line, for example `Stories: 21, 59`. Each id N is found as the spec line `N. [ ] …` or `N. [x] …`, and the story's ticked state is kept.
- **Parent task text:** the stage page also shows, above its subtasks, the parent task each group belongs to. That is the `- [ ] **N.** …` style parent line and its Delivers/Check lines, so 7.x tasks show task 7's overall goal once. If a parent can't be found, it is left out.
- **Result** (`/api/stage/:n`):

  ```json
  { "n": 7, "name": "...", "full": "...",
    "parents": [{ "id": "7", "markdown": "..." }],
    "tasks": [{ "id": "7.13", "title": "...", "state": "next", "blockedBy": [],
                "markdown": "...", "stories": [{ "n": 21, "done": false, "text": "..." }] }] }
  ```

## Server routes (`routes.mjs`)

| Route | Gives |
|---|---|
| `GET /api/sessions` | `[{ id, title, cwd, folder, branch, lastActive, live, stage, task, taskTitle, laneState }]`, newest first |
| `GET /api/session/:id` | one session record, or 404 |
| `GET /api/stage/:n` | the stage docs and task states above |
| `GET /api/feedback/:id` | that session's feedback items, newest first |
| `POST /api/feedback/:id` | queues one item and returns it. Refused with 403 unless the `Origin` (or `Referer` when Origin is missing) is `http://localhost:<port>` or `http://127.0.0.1:<port>`. Refused with 400 if the body is over 64 KB, isn't JSON, or has neither notes nor a message. Refused with 404 if the session id isn't a known session. |
| `GET /session/:id` | `session.html` |
| `GET /markdown.mjs` | the renderer, for the page |

The existing `/data` route and the dashboard page stay as they are. The server keeps listening on 127.0.0.1 only.

## Pages

### Dashboard (`index.html`): new Sessions section above Lanes

- **Each session is a row with:**
  - a live dot, which pulses for sessions active in the last 3 minutes;
  - the title;
  - a stage chip ("Stage 7"), or nothing;
  - its current task ("7.13 Reach and arc…"), coloured by lane state;
  - the branch;
  - when it was last active ("4 min ago").
- **Order:** newest first.
- **Older sessions:** sessions over 24 h old sit in a collapsed `<details>` "Earlier (n)". Whether it is open is remembered in localStorage.
- **Clicking:** a row is a link to `/session/<id>`.
- **Refresh:** the Sessions section loads from `/api/sessions` on the same 10 s refresh as the rest of the page.
- **Colours:** the existing "Next up" swatch and bar segments change from green to teal, to match the session page.

### Session page (`session.html`)

- **Header:**
  - the title;
  - the branch and folder;
  - "live" or "last active 12 min ago";
  - a link back to the dashboard;
  - a stage picker (a `<select>` of all stages). It defaults to the session's stage. A session with no stage shows "No stage — pick one" and an empty docs column until one is picked. The picked stage is kept in the URL (`?stage=8`).
- **Task strip:** one tile per task in the stage, in build order, wrapping onto more rows as needed. A tile shows the id and the title cut to fit, with the full title in a tooltip. States:
  - **done:** filled blue, with a tick;
  - **working:** green, with a pulsing glow (box-shadow and brightness, 1.2 s, ease-in-out, infinite). It respects `prefers-reduced-motion` by showing a steady green ring instead.
  - **next:** a teal outline;
  - **blocked:** grey, with the unmet blockers in its tooltip;
  - **not started:** plain.
- **Tile links:** each tile is an `<a href="#task-7.13">`. Following one scrolls the docs to that section and highlights it for 1.5 s. Loading a URL with the hash does the same.
- **Docs column:**
  - the stage's parent task text, shown once at the top;
  - then one section per task, `id="task-<id>"`: a heading with the id, the title and a state badge, the task block rendered, then a "Stories" sub-block listing each story with its number, ticked state and text.
- **Markdown:** rendered by `markdown.mjs`, a small built-in renderer covering paragraphs, nested `-` lists, `**bold**`, `*italic*`, `` `code` ``, `[text](url)` and checkboxes. All text is HTML-escaped first, and link URLs are allowed only as `http(s):`, `#` or relative. The page needs no internet connection.
- **Refresh:** every 10 s. A refresh updates only tile states, badges and the header's live/last active. The docs' Markdown is rebuilt only if its text changed, and when it is, scroll position and highlights are kept by reapplying them.
- **Layout:** the docs and sidebar sit side by side from 900 px up. Narrower, the sidebar drops below the docs. No horizontal scroll at 375 px.
- **Theme:** the same colour tokens as the dashboard, in light and dark.

### Feedback sidebar (on the session page, optional to use)

- **Collapsed by default:** a "Feedback" toggle shows how many notes are drafted. Whether it is open is remembered in localStorage.
- **Adding a note:**
  - Selecting text inside one task section shows a floating "Add note" button by the selection.
  - Clicking it wraps the selection in `<mark data-note="<id>">` and adds a note card to the sidebar with the task id, the quoted text (cut to 300 characters) and an empty note box, which gets focus.
  - A selection that spans two task sections, or lies outside the docs, shows no button.
- **Note cards:** clicking a card scrolls to its highlight. Removing a card removes its highlight.
- **Overall message:** a textarea.
- **Drafts:** notes (task id, quote, the quote's text offset within its section, the note) and the message are kept in localStorage under the session id. They survive refreshes and docs rebuilds. A highlight is reapplied by finding its quote again in its task section (the first match at or after the saved offset, else the first match anywhere). If the quote is gone, the card shows "passage changed" and still sends.
- **Send:**
  - Enabled when there is at least one note with text, or a message.
  - It POSTs `{ stage, notes: [{ task, quote, note }], message }`.
  - On success it clears the draft and highlights and shows the item in "Sent". On failure the draft is kept and the error shown.
- **Sent list:** the session's items from `/api/feedback/:id`, newest first, each with:
  - the time;
  - the status: "Queued" or "Delivered (end of turn)" / "Delivered (with your prompt)" plus the time it arrived;
  - a short preview.

  When the session isn't live and an item is queued, the list says: "This session is idle. It gets this with your next message to it."
- **Hook not installed:** if the hook isn't installed (no `~/.claude/hooks/session-feedback/feedback-hook.mjs`), the sidebar shows a one-line warning with the install command, and Send still queues.

## Feedback queue (`feedback.mjs`)

- **Where:** outside every checkout, at `~/.claude/session-feedback/<sessionId>.jsonl`. So the server (from any checkout) and the installed hook always agree, and nothing lands in the repo.
- **File format:** one JSON item per line:

  ```json
  { "id": "<time>-<random>", "created": "<ISO>", "stage": 7, "stageName": "Swing foundations",
    "notes": [{ "task": "7.13", "quote": "...", "note": "..." }], "message": "...",
    "status": "queued", "delivered": null, "via": null }
  ```

- **Writing:** the server appends new items. The hook rewrites the file to mark items delivered.
- **Concurrency:** both writers take a lock file (`<sessionId>.lock`, created with the `wx` flag). They retry for up to 2 s, and a lock older than 10 s is treated as stale and removed.
- **Session ids:** only ids matching `^[0-9a-f-]{36}$` are accepted, so a session id can't reach outside the folder.
- **Test override:** the folder can be changed with `SESSION_FEEDBACK_DIR`, so tests use a temporary one.

## Delivery hook (`feedback-hook.mjs`, `install-hook.mjs`)

### Install

`node tools/progress-dashboard/install-hook.mjs`:
- copies `feedback-hook.mjs` and `feedback.mjs` into `~/.claude/hooks/session-feedback/`;
- adds the Stop and UserPromptSubmit entries to `~/.claude/settings.json`, running `node "<home>/.claude/hooks/session-feedback/feedback-hook.mjs"`.

Details:
- **Idempotent:** it leaves every other setting and hook as it is, and running it twice adds nothing.
- **Backup:** before writing, it saves a backup next to the settings file (`settings.json.bak-session-feedback`).
- **Uninstall:** `--uninstall` removes only its own entries and the copied files.
- **Updates:** rerun it after changing the hook.

Because the installed hook is a copy, it keeps working whichever checkout or branch is current.

### Running

- **Input:** the hook reads the JSON Claude Code sends on stdin and uses `session_id` and `hook_event_name`.
- **Nothing queued:** if there's no queue file for the session, or nothing in it is queued, the hook exits 0 with no output, so other sessions pay only node's start-up time.
- **Something queued:** the hook formats all queued items into one text, marks them `delivered` (with the time and `via`: `stop` or `prompt`), then:
  - on **Stop**, it prints `{"decision":"block","reason":"<text>"}` and the session keeps going with the feedback. Items are marked delivered before printing, so a second Stop in the same turn finds nothing and can't loop.
  - on **UserPromptSubmit**, it prints `{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"<text>"}}`.
- **Text Claude receives:**

  ```
  Feedback from the owner, sent from the progress dashboard while viewing Stage 7 (Swing foundations):

  Notes on the docs:
  - [7.13] "first_contact() gives the first-touch frame" -> Also report the depth at the defender's axis.
  - [7.14] "lights at the duelling distance" -> Should sprint attacks be tested farther out?

  Message:
  Please answer the two questions before starting 7.13.
  ```

- **Errors:** any error (an unreadable queue, bad JSON on stdin) is appended to `~/.claude/session-feedback/hook-errors.log`, and the hook exits 0 with no output. A broken hook must never block a session.

## Moving the dashboard in

- **First implementation task:** the main checkout's current `.claude/progress-dashboard/server.mjs` and `index.html` are copied unchanged into `tools/progress-dashboard/`. The only edit is REPO detection (`repo.mjs`), because `path.resolve(HERE, '..', '..')` no longer points at the repo root. The old untracked copy keeps running until the switch-over.
- **After the pull request merges** (with the owner's OK for each step):
  - the main checkout's `.claude/launch.json` "progress" entry points at `tools/progress-dashboard/server.mjs`;
  - the `.claude/progress-dashboard/` line comes out of `.git/info/exclude`;
  - the old untracked copy is deleted;
  - the progress-dashboard memory is updated.

## Testing

- **Unit tests:** `npm run test:dashboard`, part of `npm test`, with no dependencies. They use fixture transcripts, fixture plan and spec excerpts, and a temporary feedback folder and home. They cover:
  - **repo:** the main checkout found from a worktree; the `REPO` override;
  - **sessions:** the title fallback order; cwd and branch from the tail; partial lines skipped; the step-back read when the tail lacks a title; live and Earlier by time; the folder prefix from REPO;
  - **stage:** stage from the branch, from the title's "Stage N", from a task id in the title, and none; current task from the matching lane by cwd, then by stage;
  - **docs:** block cutting (nested lists, stopping at the next task at the same indent), stories looked up with their ticked state, a missing story skipped, the parent task found;
  - **markdown:** escaping, unsafe links dropped, nested lists, inline code holding `*`;
  - **feedback:** append and read, a bad session id refused, the lock under two writers, a stale lock removed;
  - **hook:** no output when nothing is queued; the Stop output format and the item marked delivered; a second Stop prints nothing; the UserPromptSubmit output format; bad stdin logged with no output;
  - **install:** adds both entries; a second run adds nothing; other hooks and settings kept; uninstall removes only its own; a backup is written;
  - **routes:** the Origin check (missing or foreign origin gets 403, localhost gets 200), the size limit, an unknown session getting 404.
- **Live check** in the Browser pane on port 5198 against the main checkout:
  - the Sessions list shows the real sessions;
  - the stage 7 session's page shows tiles and docs;
  - the hash links work;
  - the current tile pulses green.
- **End-to-end:** queue a note for this session from its page, finish a turn, and see the hook deliver it and the sidebar flip to Delivered.
- **Visual:** shots at 1280 px and 375 px, in light and dark.

## Differences from the design docs

None. `docs/design.md`, `docs/mvp-spec.md` and `docs/specs/godot-rebuild.md` cover the game, not this tooling. This feature only reads the rebuild's plan and spec, and changes neither.

## Risks

- **Transcript format:** Claude Code's `.jsonl` format isn't a public contract. If `custom-title`, `cwd` or `gitBranch` disappear, the list falls back to short ids and no stage rather than breaking.
- **The hook runs in every session on this PC.** It costs node's start-up time (about 50–100 ms) per prompt and per turn end, and it does nothing when the session has no queue file.
- **A blocking Stop hook makes a session take another turn.** That's intended: it's how feedback reaches a session mid-work.
- **The estimates draft** (in the `estimated-time-by-stage` worktree's untracked `.claude/progress-dashboard/`) changes `server.mjs` and `index.html` and was never copied over. Once this branch tracks the dashboard, those changes have to be brought into `tools/progress-dashboard/` as their own change. Keeping this feature's edits to those two files small keeps that easy.
- **Other lanes merging into `feature/godot-rebuild`** don't touch `tools/`. The only shared files are `package.json` (scripts) and CLAUDE.md's Commands section.
