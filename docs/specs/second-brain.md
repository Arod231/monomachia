# Spec: the second brain

## Problem Statement

The project's knowledge is spread over a dozen long documents: the design doc, the MVP spec, the rebuild spec, a 2,400-line plan with its notes, the glossary, research reports, and almost 300 Godot scripts. Finding how a concept (posture, a weapon, a string) connects to the decisions, the plan tasks and the code that implement it means reading several files end to end. The owner watches the project from the all-lanes board at http://localhost:5197 and wants that knowledge one click away.

## Solution

An Obsidian vault, `brain/`, holds the project's knowledge as small linked notes. Hand-written concept notes tie it together; generated notes cover the glossary, every plan stage and task, every section of the docs, and a map of the code. A "Second brain" button on the board opens the vault in a popup window: a web viewer with search, wikilinks, backlinks and a graph. Obsidian isn't needed, but the vault opens in it unchanged if it's installed later.

## User Stories

1. As the owner, I want a "Second brain" button on the board, so that the project's knowledge is one click away.
2. As the owner, I want the button to open a popup window rather than replace the board, so that I can keep watching the lanes.
3. As the owner, I want clicking the button again to bring back the same popup, so that I don't collect windows.
4. As the owner, I want a home note that maps the whole vault, so that I know where to start.
5. As the owner, I want a note per weapon (built and planned), per system (posture, parry, clash, disarm, strings, ultimates), and on fighters, arenas, modes and the architecture, so that each concept is explained in one place.
6. As the owner, I want concept notes to link to the doc sections, glossary terms, plan tasks and code they rest on, so that I can go from an idea to its source.
7. As the owner, I want a note per glossary term, so that every word the docs use has a definition I can link to.
8. As the owner, I want a note per plan stage and per task, showing whether it's done, what blocks it and what it blocks, so that the plan is browsable as a graph.
9. As the owner, I want each section of the design doc, the MVP spec, the rebuild spec, the plan notes and the research reports as its own note, so that search finds the paragraph I need.
10. As the owner, I want a note per code folder in `game/` listing its scripts with their one-line purpose, so that I can see what the code does without opening it.
11. As the owner, I want each code note to link the tasks that changed it and the glossary terms it uses, so that I can trace code back to the plan and the concepts.
12. As the owner, I want the popup to show current plan ticks without anyone regenerating the vault, so that it never goes stale.
13. As the owner, I want full-text search across every note, so that I can find anything by a word.
14. As the owner, I want `[[wikilinks]]` to work as they do in Obsidian, so that the vault behaves the same in both.
15. As the owner, I want each note to list the notes that link to it, so that I can walk the graph backwards.
16. As the owner, I want a graph of the current note's neighbours and of the whole vault, so that I can see how things connect.
17. As the owner, I want an "Open in Obsidian" link, so that I can switch to the app if I install it.
18. As a developer without the board, I want to run the viewer on its own, so that the vault is useful from a fresh clone.
19. As a developer, I want one command that writes the generated notes to disk, so that Obsidian sees the whole vault.
20. As a developer, I want generated notes kept out of git, so that lanes ticking tasks never conflict over them.
21. As a developer, I want tests that fail when a link in the vault points nowhere, so that the vault stays whole.

## Implementation Decisions

### Decisions in plain English

| Question | Answer |
|---|---|
| Obsidian app or web viewer? | A web viewer in a popup, over a real Obsidian vault. Obsidian isn't installed; the vault works in it later unchanged. |
| Where does the vault live? | `brain/` at the repo root, on branch `tools/second-brain`, merged into `feature/godot-rebuild` through a PR. |
| Hand-written or generated? | Both. About 35 hand-written concept notes are committed; everything else is generated. |
| Are generated notes committed? | No. They're built on the fly when the popup opens, and `npm run brain` writes them to `brain/generated/` (git-ignored) for Obsidian. Lanes tick plan tasks all day, so committed copies would go stale and conflict. |
| How deep? | Docs plus a code map: one note per `game/` folder, not per script. |
| What isn't in it? | Memory files (the repo is public), the authored-animation and session-tracker plans until they merge into the rebuild branch, and editing notes in the viewer. |

### Architecture

- **`tools/second-brain/vault.mjs`**: a pure module. `buildVault(source)` takes a source with `list()` (repo paths), `read(path)` (text) and `subjects()` (commit subjects with the files each touched) and returns `{ notes: [{ path, title, text }] }`: the hand-written notes under `brain/` plus the generated ones under `brain/generated/`. No I/O, no dependencies, deterministic output (sorted, no timestamps). It also exports the helpers the tests and viewer need: `parseGlossary`, `parsePlan`, `splitSections`, `parseScriptSummary`, `taskIdsInSubject`, `resolveLinks`.
- **`tools/second-brain/sources.mjs`**: two sources. `gitSource(repo, ref)` reads a ref through `git --no-optional-locks` (`ls-tree`, `cat-file --batch`, `log --name-only`) and never touches a working tree; `fsSource(dir)` reads the working tree.
- **`tools/second-brain/build.mjs`**: `npm run brain` writes the generated notes into `brain/generated/` from the working tree.
- **`tools/second-brain/serve.mjs`**: a standalone server on http://localhost:5196 for the viewer and `notes.json`, from the working tree. It exports `brainHandler({ source })` so another server can mount the same routes.
- **`tools/second-brain/viewer.html`** with a vendored `marked.min.js` (MIT): the popup page. It fetches `notes.json` once and does the rest in the browser.
- **The board (untracked)**: a "Second brain" header button opens a popup window named `second-brain` (1200 × 820) at `/brain/`, and a second click brings the same window back instead of reloading it. Its server answers `/brain/*` by copying `tools/second-brain/` out of git into a cache folder keyed by commit, importing it, and serving `brainHandler` over `gitSource`. The tool and the hand-written notes come from the newest of `origin/feature/godot-rebuild`, `feature/godot-rebuild`, `origin/tools/second-brain` and `tools/second-brain` that contains `brain/Home.md`; the plans, docs and code come from the newest rebuild-branch tip, so plan ticks show even before this branch merges. The board belongs to another worktree, so its own session applies these changes (drafted in `docs/plans/second-brain-board-patch.md`).

### Generated notes

Folder `brain/generated/`, each note opening with a line saying it's generated and from which file:

- `glossary/<Term>.md` from `GLOSSARY.md`: definition, "Avoid" words, its section.
- `plan/<Stage N - Name>.md` from the plan's "Build order": the stage's tasks in order with done marks.
- `plan/tasks/<id> <title>.md` from each `- [x] **ID Title**` line and its sub-bullets: status, the task's text, "Blocked by" ids as links, "Blocks" (the reverse), its stage, the code folders whose commits name it.
- `docs/<doc>/<section>.md`: one note per `##` section of `docs/design.md`, `docs/mvp-spec.md`, `docs/specs/*.md`, `docs/plans/godot-rebuild-notes/*.md` and `docs/research/**/*.md`, with a note per doc listing its sections.
- `code/<folder>.md` for each folder under `game/` holding `.gd` files (tests, tools, addons and assets folded into one note each or left out as listed in the plan): each script's first `##` doc line, the glossary terms its doc comments mention, the tasks whose commits touched it, links to parent and child folders.

Note names are unique across the vault so `[[Name]]` resolves the way Obsidian's shortest-path links do. Characters Obsidian forbids in names (`\ / : * ? " < > | # ^ [ ]`) are replaced.

### Viewer

Left: folder tree and a search box (full text, case-insensitive, ranked by title match first). Centre: the note, rendered with `marked`; `[[Name]]`, `[[Name|label]]` and `[[Name#Heading]]` become in-page links, unresolved ones are shown struck through; a "Linked from" list closes the note. Right (toggle): a canvas force-directed graph of the note's neighbours, or of the whole vault; clicking a node opens it. The URL hash holds the open note so back and forward work. A header link opens the note in Obsidian (`obsidian://open?vault=brain&file=…`). Colours follow the board's dark theme.

## Testing Decisions

- Vitest tests in `tests/second-brain.test.mjs` drive `vault.mjs` through fixture text and an in-memory source: glossary parsing, plan tasks with done marks, blockers and the reverse "Blocks", section splitting, script summaries, task ids in commit subjects (`(task 7.1)`, `(godot-rebuild 22.6, 22.8-22.10, first step)`), safe note names, and link resolution.
- A test builds the vault from the real working tree and fails if any wikilink, generated or hand-written, resolves to no note, or two notes share a name.
- The viewer and the board button are checked by hand in the Browser pane: the popup opens, links and back work, search finds a term, the graph draws.
- `npm test` and `npm run typecheck` pass before every commit.

## Out of Scope

- Installing Obsidian or configuring its plugins.
- Editing notes in the viewer.
- Plans that live only on other branches (authored-animation, session-tracker) until they merge.
- Memory files and anything outside the repo.
- A note per script (the code map stops at folders).

## Further Notes

- This is tooling, not gameplay, so `docs/design.md` and `docs/mvp-spec.md` are unchanged; nothing here contradicts them.
- The board stays untracked (`tools/session-tracker`, PR #7, will move the dashboards into `tools/`); its button and routes are local edits. When the board becomes tracked, its `/brain/` routes should import `tools/second-brain/serve.mjs` directly.
