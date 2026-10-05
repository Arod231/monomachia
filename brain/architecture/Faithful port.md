---
tags: [architecture, history]
---

# Faithful port

The rebuild's safety net. Before changing any rule, the TypeScript rules were ported to GDScript module by module, with the same names and numbers and even the known quirks (update order, last-write-wins hit-stop, JavaScript rounding and the Mulberry32 generator), and proven identical.

How it was proven:

- the 47 existing rule tests, rewritten for GUT;
- **golden replays:** a Node script ran the TypeScript rules on 29 scripted duels and 6 computer-vs-computer matches, recording every event and each fighter's state per frame. A GUT test fed the same inputs to the Godot rules and compared them, within 1e-6 on positions and exactly on events;
- the Godot computer opponent reproducing the recorded inputs, and the 40-match soak and the counterlab printing the same numbers as their TypeScript versions.

Two details made whole runs match bit for bit, and both stay: the rules' own 64-bit vectors, and `js_math.gd` computing trig exactly as V8 does. See [[Rules layer]].

Commit 4222167 is the last one proven bit for bit. [[Task 8]] then retired the goldens before the first deliberate rule change, and the rules are now guarded by tests of their behaviour.

Plan: [[Task 2]], [[Task 3]], [[Task 4]], [[Task 5]] (phase A of the [[Rebuild plan]]).

**Sources:** [[Rebuild spec - Implementation Decisions]] · see [[Godot rebuild]]
