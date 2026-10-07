import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DEMO_KANJI, EXTRA, FONTS, charset, gameCharacters } from '../scripts/fonts.mjs';

function game(files) {
  const dir = mkdtempSync(join(tmpdir(), 'fonts-'));
  for (const [path, text] of Object.entries(files)) {
    mkdirSync(join(dir, path, '..'), { recursive: true });
    writeFileSync(join(dir, path), text);
  }
  return dir;
}

test('the game characters are the non-ASCII ones in scripts, scenes and resources', () => {
  const dir = game({
    'ui/hud.gd': 'announce("始め", "Fight")',
    'ui/menu.tscn': 'text = "決闘 · Duel"',
    'ui/theme.tres': '"→"',
    'ui/notes.md': '"無"',
  });
  try {
    assert.deepEqual([...gameCharacters(dir)].sort(), ['·', '→', '始', '決', '闘', 'め'].sort());
  } finally {
    rmSync(dir, { recursive: true });
  }
});

test('addons, tests and the import cache hold no UI text', () => {
  const dir = game({
    'addons/gut/gui.gd': '"無"',
    'tests/view/test_x.gd': '"無"',
    '.godot/x.tres': '"無"',
    'ui/tests/y.gd': '"有"',
  });
  try {
    assert.deepEqual([...gameCharacters(dir)], ['有'], 'only the top folders are skipped');
  } finally {
    rmSync(dir, { recursive: true });
  }
});

test('the charset keeps ASCII, the demo kanji, later kanji and the game characters, without control characters', () => {
  const chars = charset(new Set(['刀', '﻿', '\t']));
  for (const c of 'Az09 ~!' + DEMO_KANJI + EXTRA + '刀') assert.ok(chars.includes(c), c);
  assert.ok(!chars.includes('﻿') && !chars.includes('\t'));
  assert.equal(new Set(chars).size, [...chars].length, 'each once');
  assert.ok(EXTRA.includes('討') && EXTRA.includes('死'), 'Warrior Slain, 討死 (task 72)');
});

test('every font is pinned to a google/fonts commit and a checksum, with its licence', () => {
  for (const f of FONTS) {
    assert.match(f.url, /^https:\/\/raw\.githubusercontent\.com\/google\/fonts\/[0-9a-f]{40}\/ofl\//);
    assert.match(f.sha256, /^[0-9a-f]{64}$/);
    assert.match(f.licence.file, /-OFL\.txt$/);
  }
});
