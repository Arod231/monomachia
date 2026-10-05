// Installs the Project Manager's hooks in user settings: copies relay-hook.mjs
// and stop-hook.mjs to ~/.claude/hooks/<name>/hook.mjs and registers them in
// ~/.claude/settings.json (hooks.mjs says how), backing the old settings up
// beside it. These run in every Claude Code session, so run this only with the
// owner's OK.
//   npm run board:hooks              install
//   npm run board:hooks -- --dry-run say what would change, change nothing
//   npm run board:hooks -- --check   say whether the installed hooks are current
// LANES_CLAUDE_DIR overrides ~/.claude, for tests.
import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { HOOKS, hooksStatus, withHooks } from './hooks.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const CLAUDE = process.env.LANES_CLAUDE_DIR ?? path.join(os.homedir(), '.claude');
const SETTINGS = path.join(CLAUDE, 'settings.json');
const dry = process.argv.includes('--dry-run');
const check = process.argv.includes('--check');

const read = (file) => { try { return readFileSync(file, 'utf8'); } catch { return null; } };
const settings = existsSync(SETTINGS) ? JSON.parse(readFileSync(SETTINGS, 'utf8')) : {};
const tracked = Object.fromEntries(HOOKS.map((h) => [h.name, read(path.join(HERE, h.file))]));
const installedNow = () => Object.fromEntries(HOOKS.map((h) => [h.name, read(path.join(CLAUDE, 'hooks', h.name, 'hook.mjs'))]));

if (check) {
  const s = hooksStatus({ tracked, installed: installedNow(), settings, home: CLAUDE });
  console.log(s.current ? 'The installed hooks are current.' : `The installed hooks are out of date:\n- ${s.problems.join('\n- ')}`);
  process.exit(0);
}

const next = withHooks(settings, CLAUDE);
const settingsChange = JSON.stringify(next) !== JSON.stringify(settings);
for (const h of HOOKS) {
  const to = path.join(CLAUDE, 'hooks', h.name, 'hook.mjs');
  if (dry) { console.log(`Would copy ${h.file} to ${to}`); continue; }
  mkdirSync(path.dirname(to), { recursive: true });
  copyFileSync(path.join(HERE, h.file), to);
  console.log(`Copied ${h.file} to ${to}`);
}
if (!settingsChange) console.log(`${SETTINGS} already registers them.`);
else if (dry) console.log(`Would update ${SETTINGS}:\n${JSON.stringify(next.hooks, null, 2)}`);
else {
  if (existsSync(SETTINGS)) copyFileSync(SETTINGS, `${SETTINGS}.bak-${Date.now()}`);
  writeFileSync(SETTINGS, `${JSON.stringify(next, null, 2)}\n`);
  console.log(`Updated ${SETTINGS} (the old one is beside it as settings.json.bak-*).`);
}
// Each hook runs its file afresh every time, so new copies take effect at once;
// settings load when a session starts, so new timeouts reach new sessions only.
if (!dry) console.log('The new copies take effect at once; new timeouts apply to sessions started from now on.');
