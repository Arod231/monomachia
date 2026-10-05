---
tags: [project, tools]
---

# About this vault

`brain/` is an Obsidian vault of the project's knowledge. It works in the Obsidian app, and in the web viewer the board opens in a popup ([[Lanes and the board]]).

## Two kinds of note

- **Hand-written notes** (`brain/weapons`, `brain/combat`, `brain/game`, `brain/architecture`, `brain/project`, and [[Home]]) explain concepts and link them together. They're committed; edit them like any doc.
- **Generated notes** (`brain/generated/`) are built from the repo by `tools/second-brain/vault.mjs`: a note per [[Glossary]] term, per stage and task of each plan, per section of each doc, and per folder of the game code ([[Code map]]). They open with "Generated from…"; never edit them by hand. They're not committed, because lanes tick plan tasks all day: the board and the viewer build them on the fly, and `npm run brain` writes them to disk for Obsidian.

## Rules for hand-written notes

- Link with `[[Note name]]`; names are unique across the vault, and a test fails on any link that points nowhere or any two notes that share a name.
- Don't reuse a generated name: glossary terms (such as [[Posture]]), `Task 7.1`, `Stage 7 - …`, `game.sim`, or `<Doc> - <Section>`.
- Keep facts that change (task status, tuning numbers) in their source docs, and link to them; the generated notes keep up on their own.
- End with **Sources:** links to the doc sections a note rests on.
- The repo is public: nothing private goes in here.

## Running it

- `npm run brain`: write the generated notes, then open `brain/` as a vault in Obsidian.
- `npm run brain:serve`: the viewer on its own at http://localhost:5196.
- On the board: the **Second brain** button.

**Sources:** [[Spec - the second brain]] · [[Plan - the second brain]]
