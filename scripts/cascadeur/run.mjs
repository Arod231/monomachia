// Runs Python inside the owner's running Cascadeur through its script server
// (Scripts > MCP > Start script server, http://127.0.0.1:8765), with
// scripts/cascadeur/mono_csc.py loaded as `m` (milestone-1 task 59).
//
//   node scripts/cascadeur/run.mjs "<python>"        code to run
//   node scripts/cascadeur/run.mjs --file <script.py>
//
// It prints the script's own output and errors, and only a count of
// Cascadeur's warnings (a rig refit logs one per bone per frame). Exits 1
// when the script fails, or when Cascadeur isn't listening.

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
export const SERVER = process.env.CASCADEUR_SERVER ?? 'http://127.0.0.1:8765';
const LIB = join(here, 'mono_csc.py').replaceAll('\\', '/');

/** The lane calling: this checkout's git branch, which mono_csc takes the lock
 * and keeps its tab under (several lanes share the owner's one Cascadeur). */
export function lane() {
  try {
    return execFileSync('git', ['branch', '--show-current'], { cwd: here, encoding: 'utf8' }).trim() || 'detached';
  } catch {
    return 'unknown';
  }
}

/** The preamble every run gets: mono_csc (re)loaded as `m`, told the lane. */
export function preamble() {
  return [
    'import importlib.util, sys',
    `_spec = importlib.util.spec_from_file_location('mono_csc', r"${LIB}")`,
    'm = importlib.util.module_from_spec(_spec)',
    '_spec.loader.exec_module(m)',
    "sys.modules['mono_csc'] = m",
    `m.LANE = ${JSON.stringify(lane())}`,
    '',
  ].join('\n');
}

/** Runs `code` (after the preamble); resolves to { ok, value, lines, warnings, error }. */
export async function run(code) {
  const res = await fetch(`${SERVER}/run`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: preamble() + code }),
  });
  const body = await res.json();
  const lines = [];
  let warnings = 0;
  for (const msg of body.messages ?? []) {
    if (msg.level === 'Warning') warnings += 1;
    else lines.push(msg.level === 'Info' ? msg.text : `[${msg.level}] ${msg.text}`);
  }
  return { ok: body.ok === true, value: body.value, lines, warnings, error: body.error };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const code = args[0] === '--file' ? readFileSync(args[1], 'utf8') : args.join(' ');
  try {
    const r = await run(code);
    for (const l of r.lines) console.log(l);
    if (r.value && r.value !== 'None' && r.value !== '') console.log(r.value);
    if (r.warnings) console.log(`(${r.warnings} Cascadeur warnings)`);
    if (!r.ok) {
      console.error(r.error ?? 'failed');
      process.exit(1);
    }
  } catch (e) {
    console.error(`Cascadeur's script server isn't answering at ${SERVER}: start it in Cascadeur (Scripts > MCP > Start script server). ${e.message}`);
    process.exit(1);
  }
}
