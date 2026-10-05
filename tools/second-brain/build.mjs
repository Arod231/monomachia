#!/usr/bin/env node
// Writes the second brain's generated notes into brain/generated/ from the
// working tree, so the vault is whole when opened in Obsidian. The folder is
// git-ignored: lanes tick plan tasks all day, and the board and the viewer
// build these notes on the fly anyway.
//
// usage: npm run brain

import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { fsSource } from './sources.mjs';
import { GENERATED, buildVault, resolveLinks } from './vault.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');

const { notes } = buildVault(fsSource(ROOT));
rmSync(join(ROOT, GENERATED), { recursive: true, force: true });
const generated = notes.filter((n) => n.path.startsWith(`${GENERATED}/`));
for (const n of generated) {
  mkdirSync(dirname(join(ROOT, n.path)), { recursive: true });
  writeFileSync(join(ROOT, n.path), n.text);
}
const broken = resolveLinks(notes).filter((l) => !l.to);
console.log(`brain: ${generated.length} generated notes in ${GENERATED}/, ${notes.length - generated.length} hand-written`);
for (const l of broken) console.warn(`  broken link in "${l.from}": [[${l.target}]]`);
process.exitCode = broken.length ? 1 : 0;
