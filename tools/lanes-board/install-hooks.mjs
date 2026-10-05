// Installs the Project Manager's hooks in user settings: copies relay-hook.mjs
// and stop-hook.mjs to ~/.claude/hooks/<name>/hook.mjs and registers them in
// ~/.claude/settings.json (hooks.mjs says how), backing the old settings up
// beside it. These run in every Claude Code session, so run this only with the
// owner's OK.
//   npm run board:hooks              install
//   npm run board:hooks -- --dry-run say what would change, change nothing
//   npm run board:hooks -- --check   say whether the installed hooks are current
// LANES_CLAUDE_DIR overrides ~/.claude, for tests.
import { copyFileSync, existsSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { HOOKS, hookFiles, hooksStatusOf, withHooks } from './hooks.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const CLAUDE = process.env.LANES_CLAUDE_DIR ?? path.join(os.homedir(), '.claude');
const SETTINGS = path.join(CLAUDE, 'settings.json');
const dry = process.argv.includes('--dry-run');
const check = process.argv.includes('--check');

const read = (file) => { try { return readFileSync(file, 'utf8'); } catch { return null; } };

if (check) {
  const s = hooksStatusOf({ claudeDir: CLAUDE, boardDir: HERE, read });
  console.log(s.current ? 'The installed hooks are current.' : `The installed hooks are out of date:\n- ${s.problems.join('\n- ')}`);
  process.exit(0);
}

const settings = existsSync(SETTINGS) ? JSON.parse(readFileSync(SETTINGS, 'utf8')) : {};
const next = withHooks(settings, CLAUDE);
for (const h of HOOKS) {
  for (const { from, to } of hookFiles(CLAUDE, h)) {
    if (dry) { console.log(`Would copy ${from} to ${to}`); continue; }
    mkdirSync(path.dirname(to), { recursive: true });
    copyFileSync(path.join(HERE, from), to);
    console.log(`Copied ${from} to ${to}`);
  }
}
if (JSON.stringify(next) === JSON.stringify(settings)) console.log(`${SETTINGS} already registers them.`);
else if (dry) console.log(`Would update ${SETTINGS}:\n${JSON.stringify(next.hooks, null, 2)}`);
else {
  // The new settings go to a temp file first, then over the old ones, which are
  // kept beside them; if settings.json can't be written, nothing is left behind.
  const backup = `${SETTINGS}.bak-${Date.now()}`;
  const tmp = `${SETTINGS}.tmp-${process.pid}`;
  try {
    writeFileSync(tmp, `${JSON.stringify(next, null, 2)}\n`);
    if (existsSync(SETTINGS)) copyFileSync(SETTINGS, backup);
    renameSync(tmp, SETTINGS);
    console.log(`Updated ${SETTINGS} (the old one is beside it as ${path.basename(backup)}).`);
  } catch (err) {
    rmSync(tmp, { force: true });
    rmSync(backup, { force: true });
    console.error(`Couldn't write ${SETTINGS} (${err.code ?? err.message}); it is unchanged. The hook files above were updated.`);
    process.exit(1);
  }
}
// Each hook runs its files afresh every time, so new copies take effect at once;
// settings load when a session starts, so new timeouts reach new sessions only.
if (!dry) console.log('The new copies take effect at once; new timeouts apply to sessions started from now on.');
