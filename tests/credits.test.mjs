// Every third-party work the game is built from is credited (plan task 25.4).
// CREDITS.md at the repo root is the short credits page the build ships as
// CREDITS.txt (game/tools/build_notices.gd); the per-file records it draws on
// are game/assets/CREDITS.md (the art), game/assets/audio/SOURCES.md (the
// sounds) and game/assets/kevin_iglesias/clip_manifest.json (the licensed
// clips, converted from the asset repository on the developer's PC).

import { describe, expect, it } from 'vitest';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative, resolve, sep } from 'node:path';

const ROOT = resolve(import.meta.dirname, '..');
const read = (path) => readFileSync(join(ROOT, path), 'utf8');
const CREDITS = read('CREDITS.md');
const ASSET_RECORD = read('game/assets/CREDITS.md');
const IGLESIAS_BEGIN = '<!-- packs: kevin_iglesias -->';
const IGLESIAS_END = '<!-- /packs -->';

/**
 * The packs named in the "Pack" column of the Markdown tables that list
 * files in the repo (those with a "Files" column too); the record's table of
 * packs kept out of the repo is the clip manifest's business.
 */
function tablePacks(markdown) {
  const packs = new Set();
  let column = -1;
  let header = true;
  for (const line of markdown.split(/\r?\n/)) {
    if (!line.startsWith('|')) {
      column = -1;
      header = true;
      continue;
    }
    const cells = line.split('|').slice(1, -1).map((c) => c.trim());
    if (header) {
      header = false;
      column = cells.includes('Files') ? cells.indexOf('Pack') : -1;
      continue;
    }
    if (column < 0) continue;
    const cell = cells[column];
    if (!cell || /^-+$/.test(cell)) continue;
    packs.add(cell.split(/,| \(/)[0].trim());
  }
  return packs;
}

/** The licence files under game/, outside the editor's cache. */
function licenceFiles(dir = join(ROOT, 'game')) {
  const out = [];
  for (const name of readdirSync(dir)) {
    if (name === '.godot') continue;
    const path = join(dir, name);
    if (statSync(path).isDirectory()) out.push(...licenceFiles(path));
    else if (/(^|[-_])(LICEN[CS]E|OFL|COPYING|NOTICE)([-_.]|$)/i.test(name)) out.push(relative(ROOT, path).split(sep).join('/'));
  }
  return out;
}

/** "ZenKakuGothicNew" -> "Zen Kaku Gothic New". */
const spaced = (camel) => camel.replace(/([a-z])([A-Z])/g, '$1 $2');

describe('CREDITS.md', () => {
  it('names every pack the art record lists', () => {
    const packs = tablePacks(ASSET_RECORD);
    expect(packs.size).toBeGreaterThanOrEqual(5);
    for (const pack of packs) expect(CREDITS, pack).toContain(pack);
  });

  it('names every Kevin Iglesias pack the clip manifest uses, inside the section a build without the clips leaves out', () => {
    const manifest = JSON.parse(read('game/assets/kevin_iglesias/clip_manifest.json'));
    const packs = new Set(Object.values(manifest.clips).map((c) => c.pack).filter(Boolean));
    expect([...packs].sort()).toEqual(['Human Basic Motions', 'Human Crafting Animations', 'Human Melee Animations']);
    const section = CREDITS.slice(CREDITS.indexOf(IGLESIAS_BEGIN), CREDITS.indexOf(IGLESIAS_END));
    expect(section).toContain('Kevin Iglesias');
    for (const pack of packs) expect(section, pack).toContain(pack);
    const outside = CREDITS.replace(section, '');
    expect(outside).not.toContain('Kevin Iglesias');
  });

  it('names the Sonniss bundle and every maker whose sounds were cut from it', () => {
    const sources = read('game/assets/audio/SOURCES.md');
    const makers = new Set([...sources.matchAll(/(?:\| |<br>)([^|<>`]+?) - [^|<>`]+?: `/g)].map((m) => m[1].trim()));
    expect(makers.size).toBeGreaterThanOrEqual(10);
    expect(CREDITS).toContain('Sonniss');
    for (const maker of makers) expect(CREDITS, maker).toContain(maker);
  });

  it('names the work behind every licence file in the game folder', () => {
    const files = licenceFiles();
    expect(files).toContain('game/ui/fonts/ZenAntique-OFL.txt');
    for (const file of files) {
      const addon = file.match(/^game\/addons\/([^/]+)\//);
      const work = addon ? addon[1].toUpperCase() : spaced(file.split('/').pop().split(/[-_]/)[0]);
      expect(CREDITS, file).toContain(work);
    }
  });

  it('carries the copyright line and points at the licence', () => {
    expect(CREDITS).toContain('© 2026 Andrew Rodriguez');
    expect(CREDITS).toContain('LICENSE');
  });
});

describe('game/assets/CREDITS.md', () => {
  it('names every folder in game/assets', () => {
    const folders = readdirSync(join(ROOT, 'game/assets')).filter((n) => statSync(join(ROOT, 'game/assets', n)).isDirectory());
    expect(folders.length).toBeGreaterThanOrEqual(5);
    for (const folder of folders) expect(ASSET_RECORD, folder).toContain(`\`${folder}/`);
  });
});
