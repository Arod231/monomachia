---
tags: [project, process, tools]
---

# Lanes and the board

Work on the rebuild runs in parallel **lanes**: each is a git worktree on its own branch, taking one task at a time from a plan, merging back through a pull request. Lane branches are named for their plan and tasks (for example `godot/stage-7-swings` or `godot/menus-22.6-22.10`), and commit subjects name the tasks they finish, such as "(task 7.15)" or "(godot-rebuild 22.6, 22.8)". This vault reads those tags to link each code folder to the tasks that changed it ([[Code map]]).

A task names what blocks it ("Blocked by"), and some wait on the owner's OK, such as the animation review that gates the other weapons' swings. Each task note in this vault shows both directions: what it's blocked by, and what it blocks.

## The board

A local dashboard at http://localhost:5197 charts every plan and every worktree live: which lane works on which task, what's ready, what's blocked, and what waits on the owner. It reads git without fetching, so it never collides with the lanes. Its **Second brain** button opens this vault in a popup window. The **Graph** tab draws a plan's tasks as nodes joined by their blockers, a band per stage; picking one lights everything it waits on and everything waiting on it, and tasks can be queued, launched or ended from there. A launched task starts with nobody at the PC: the board opens a new session in the Claude app and presses Send for it through Windows UI Automation, confirming the app's "Trust this workspace?" for the repository. A launch made while the PC is locked starts once it's unlocked, and one that couldn't start shows why, with Try again. The **Sessions** tab lists every Claude session of the last three days with its transcript; a session switched to "Answer from board" sends its permission prompts, its questions and the end of each turn there, so the owner can approve, answer and reply from the board (or a phone) instead of the app. It also answers on the PC's Tailscale address, so the owner can follow the lanes from a phone, which gets a mobile page of its own.

Related: [[Rebuild plan]] (the stages and tasks) · [[Workflow]] · [[About this vault]]
