// Cuts the UI theme's two mood-board fonts (milestone-1 task 53) down to the
// characters the game shows, so they fit the art budget: Shippori Mincho B1
// (titles and Latin, Medium and Bold, about 15 MB each whole) and Yuji Boku
// (brushed kanji, about 8.5 MB whole). Both come from google/fonts at a
// pinned commit under the SIL Open Font License (neither has a Reserved Font
// Name, so a cut keeps its name), are kept whole in a gitignored
// .font-cache/, and are cut by fontTools (`python -m pip install --user
// fonttools`) into game/ui/fonts/.
//
// The characters: printable ASCII, a few marks the text uses, the demo's
// kanji (DEMO_KANJI, as test_ui_theme.gd lists them), kanji a later task
// will show (EXTRA), and every non-ASCII character in the game's own
// scripts, scenes and resources (outside addons and tests). Run it again
// when new text brings a character the fonts lack: test_ui_theme.gd fails
// and names it.
//
// usage: node scripts/fonts.mjs   (or: npm run fonts)
// It prints the characters a font lacks whole (the theme's fallback font
// draws those).

import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const GAME = join(ROOT, 'game');
const CACHE = join(ROOT, '.font-cache');
const OUT = join(GAME, 'ui', 'fonts');

// google/fonts at the commit the cuts were made from.
const COMMIT = '2c605eeda2de57af2b34822b79986f5140299862';
const RAW = `https://raw.githubusercontent.com/google/fonts/${COMMIT}/ofl`;

// Each font: where it comes from, its SHA-256 whole, and the cut's name.
export const FONTS = [
  {
    file: 'ShipporiMinchoB1-Medium.ttf',
    url: `${RAW}/shipporiminchob1/ShipporiMinchoB1-Medium.ttf`,
    sha256: '0712348124729e30507a9ed9d7c8939125f13605954596acfe0ec4a6341e3b9d',
    licence: { url: `${RAW}/shipporiminchob1/OFL.txt`, file: 'ShipporiMinchoB1-OFL.txt' },
  },
  {
    file: 'ShipporiMinchoB1-Bold.ttf',
    url: `${RAW}/shipporiminchob1/ShipporiMinchoB1-Bold.ttf`,
    sha256: 'd20f3981afb8bceda5fdf8f0fb29ba51eb21518644612ccd8a183e5bd433e25a',
    licence: { url: `${RAW}/shipporiminchob1/OFL.txt`, file: 'ShipporiMinchoB1-OFL.txt' },
  },
  {
    file: 'YujiBoku-Regular.ttf',
    url: `${RAW}/yujiboku/YujiBoku-Regular.ttf`,
    sha256: '94fda16384f3bdac24376a000c57e99abfa314961bd89ef27badfb7410322003',
    licence: { url: `${RAW}/yujiboku/OFL.txt`, file: 'YujiBoku-OFL.txt' },
  },
];

// The demo's kanji (test_ui_theme.gd's DEMO_KANJI).
export const DEMO_KANJI = '一騎討ち赤青奥義第二三四五六七八九戦始め武器喪失相打本勝敗利北決着休止危刀双短大剣';
// Kanji later tasks show: Warrior Slain (task 72).
export const EXTRA = '討死';
// Marks the text uses beyond ASCII, and the controller buttons' names.
export const MARKS = '·—–…‘’“”×÷°±←↑→↓○□△';

const SKIP = new Set(['addons', 'tests', '.godot']);
const TEXT_EXTENSIONS = ['.gd', '.tscn', '.tres'];

// Every non-ASCII character in the game's scripts, scenes and resources
// under dir, skipping addons, tests and the import cache.
export function gameCharacters(dir = GAME) {
  const found = new Set();
  const walk = (d, top) => {
    for (const name of readdirSync(d)) {
      const p = join(d, name);
      if (statSync(p).isDirectory()) {
        if (!(top && SKIP.has(name))) walk(p, false);
      } else if (TEXT_EXTENSIONS.some((e) => name.endsWith(e))) {
        for (const c of readFileSync(p, 'utf8')) {
          if (c.codePointAt(0) > 0x7e) found.add(c);
        }
      }
    }
  };
  walk(dir, true);
  return found;
}

// The characters the cut fonts keep, as one sorted string.
export function charset(game = gameCharacters()) {
  const chars = new Set();
  for (let c = 0x20; c <= 0x7e; c++) chars.add(String.fromCodePoint(c));
  for (const s of [DEMO_KANJI, EXTRA, MARKS]) for (const c of s) chars.add(c);
  for (const c of game) {
    // control and format characters (byte-order marks, tabs) have no glyph
    if (!/[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]/u.test(c)) chars.add(c);
  }
  return [...chars].sort().join('');
}

function sha256(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}

async function fetchTo(url, path) {
  if (existsSync(path)) return;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url}: ${res.status}`);
  writeFileSync(path, Buffer.from(await res.arrayBuffer()));
}

// The characters in the file at chars that the font at path has no glyph for.
function missing(path, list) {
  const script = [
    'import sys',
    'from fontTools.ttLib import TTFont',
    'cmap = TTFont(sys.argv[1]).getBestCmap()',
    'text = open(sys.argv[2], encoding="utf-8").read()',
    'sys.stdout.buffer.write("".join(c for c in text if ord(c) not in cmap).encode("utf-8"))',
  ].join('\n');
  return execFileSync('python', ['-c', script, path, list]).toString('utf8');
}

async function main() {
  mkdirSync(CACHE, { recursive: true });
  const chars = charset();
  const list = join(CACHE, 'charset.txt');
  writeFileSync(list, chars);
  for (const font of FONTS) {
    const whole = join(CACHE, font.file);
    const cut = join(OUT, font.file);
    await fetchTo(font.url, whole);
    if (sha256(whole) !== font.sha256) throw new Error(`${font.file}: not the pinned file (${sha256(whole)})`);
    await fetchTo(font.licence.url, join(OUT, font.licence.file));
    execFileSync('python', ['-m', 'fontTools.subset', whole, `--text-file=${list}`, `--output-file=${cut}`,
      '--layout-features=*', '--no-hinting', '--desubroutinize', '--name-IDs=*', '--name-languages=*'], { stdio: 'inherit' });
    const lacks = missing(whole, list);
    console.log(`${font.file}: ${(statSync(whole).size / 1048576).toFixed(1)} MB whole, ${(statSync(cut).size / 1024).toFixed(0)} KB cut` +
      (lacks === '' ? '' : `; lacks ${lacks}`));
  }
  console.log(`${[...chars].length} characters asked of every cut`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
}
