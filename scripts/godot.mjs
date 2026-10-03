#!/usr/bin/env node
// Task runner for the Godot project in game/. Finds the Godot executable, runs
// it with a watchdog (a GDScript runtime error in a --script run hangs Godot
// instead of exiting), and scans the output for script errors.
//
// usage: node scripts/godot.mjs <command> [args...]
//   import                 re-import assets and refresh the script class cache
//   test [gut args...]     run the GUT tests headless
//   typecheck              load every script; fail on parse or type errors
//   soak [matches]         computer-vs-computer matches with balance numbers
//   script <res://path.gd> [-- user args]   run a SceneTree tool script headless
//   shots <scene> [out.png] [frames] [scene args...]   render a scene in an off-screen window;
//                          fails on a shader or script error
//   run                    play the game
//   dev                    open the editor
//   build                  export the Windows build to build/windows/
//
// Godot is found through the GODOT environment variable, then `godot` or
// `godot4` on PATH, then a local `.godot-path` file (see findGodot).

import { spawn, spawnSync } from 'node:child_process';
import { existsSync, readFileSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const PROJECT = join(ROOT, 'game');
const WIN = process.platform === 'win32';

function onPath(name) {
  const r = spawnSync(WIN ? 'where' : 'which', [name], { encoding: 'utf8' });
  if (r.status !== 0) return null;
  const first = r.stdout.split(/\r?\n/).find((l) => l.trim());
  return first ? first.trim() : null;
}

/**
 * Godot is found through, in order: the GODOT environment variable, `godot` or
 * `godot4` on PATH, or a one-line `.godot-path` file at the repo root (not
 * committed) holding the executable's path. On Windows, point it at the
 * *_console.exe file, which forwards output and the exit code.
 */
export function findGodot() {
  if (process.env.GODOT && existsSync(process.env.GODOT)) return process.env.GODOT;
  for (const name of ['godot', 'godot4']) {
    const p = onPath(name);
    if (p) return p;
  }
  // In a linked git worktree, the untracked file lives in the main checkout.
  const roots = [ROOT];
  const common = spawnSync('git', ['rev-parse', '--path-format=absolute', '--git-common-dir'], { cwd: ROOT, encoding: 'utf8' });
  if (common.status === 0 && common.stdout.trim()) roots.push(dirname(common.stdout.trim()));
  for (const root of roots) {
    const local = join(root, '.godot-path');
    if (!existsSync(local)) continue;
    const p = readFileSync(local, 'utf8').trim();
    if (p && existsSync(p)) return p;
  }
  return null;
}

function die(msg) {
  console.error(msg);
  process.exit(1);
}

// Test and shot runs set this environment variable so the player's saved
// settings (user://settings.cfg, such as a lower graphics preset) can't change
// them. GameSettings.DEFAULTS_ENV reads it. (GUT refuses unknown arguments, so
// it can't be a command-line flag.)
const DEFAULT_SETTINGS_ENV = { MONOMACHIA_DEFAULT_SETTINGS: '1' };
const ERROR_PATTERNS = [/SCRIPT ERROR/, /Parse Error/, /Failed to load script/, /^ERROR: .*\.gd/m];
const SHADER_ERROR_PATTERNS = [/SHADER ERROR/];

/**
 * Run Godot with a timeout. Resolves with {code, output}. Output is streamed
 * through unless quiet is set.
 */
function runGodot(godot, args, { timeoutMs = 600000, quiet = false, cwd = PROJECT, env = {} } = {}) {
  return new Promise((res) => {
    const child = spawn(godot, args, { cwd, stdio: ['ignore', 'pipe', 'pipe'], env: { ...process.env, ...env } });
    let output = '';
    const onData = (stream) => (buf) => {
      const s = buf.toString();
      output += s;
      if (!quiet) stream.write(s);
    };
    child.stdout.on('data', onData(process.stdout));
    child.stderr.on('data', onData(process.stderr));
    const timer = setTimeout(() => {
      console.error(`\ngodot.mjs: timed out after ${Math.round(timeoutMs / 1000)} s; stopping Godot.`);
      child.kill('SIGKILL');
    }, timeoutMs);
    child.on('close', (code, signal) => {
      clearTimeout(timer);
      res({ code: code ?? (signal ? 124 : 1), output });
    });
  });
}

const hasScriptErrors = (out) => ERROR_PATTERNS.some((re) => re.test(out));
const hasShaderErrors = (out) => SHADER_ERROR_PATTERNS.some((re) => re.test(out));

async function importProject(godot) {
  const r = await runGodot(godot, ['--headless', '--path', PROJECT, '--import'], { quiet: true, timeoutMs: 900000 });
  if (r.code !== 0) {
    process.stderr.write(r.output);
    die(`godot.mjs: import failed (exit ${r.code}).`);
  }
}

async function main() {
  const [cmd = 'help', ...rest] = process.argv.slice(2);
  if (cmd === 'help' || cmd === '--help') {
    console.log('usage: node scripts/godot.mjs import|test|typecheck|soak|script|shots|run|dev|build');
    return;
  }
  const godot = findGodot();
  if (!godot) {
    die(
      'godot.mjs: Godot 4.7 not found. Put it on PATH as `godot`, set the GODOT environment variable, or ' +
        "write the executable's path into a .godot-path file at the repo root (on Windows, the *_console.exe file).",
    );
  }

  switch (cmd) {
    case 'path':
      console.log(godot);
      return;
    case 'import':
      await importProject(godot);
      console.log('godot.mjs: import done.');
      return;
    case 'test': {
      await importProject(godot);
      const r = await runGodot(godot, ['--headless', '--path', PROJECT, '-s', 'res://addons/gut/gut_cmdln.gd', ...rest], {
        timeoutMs: 900000,
        env: DEFAULT_SETTINGS_ENV,
      });
      if (r.code !== 0) process.exit(r.code);
      if (/Failing Tests|\[Failed\]/.test(r.output)) process.exit(1);
      // GUT skips a test script that fails to parse and still reports success.
      if (/Parse Error|Failed to load script|Failed parsing/.test(r.output)) {
        die('godot.mjs: a test script failed to load (see the parse errors above), so GUT skipped it.');
      }
      return;
    }
    case 'typecheck': {
      await importProject(godot);
      const r = await runGodot(godot, ['--headless', '--path', PROJECT, '--script', 'res://tools/typecheck.gd'], {
        timeoutMs: 300000,
      });
      if (r.code !== 0 || hasScriptErrors(r.output)) die('godot.mjs: typecheck failed.');
      return;
    }
    case 'soak': {
      await importProject(godot);
      const r = await runGodot(godot, ['--headless', '--path', PROJECT, '--script', 'res://tools/soak.gd', '--', ...rest], {
        timeoutMs: 3600000,
      });
      if (r.code === 0 && hasScriptErrors(r.output)) die('godot.mjs: soak reported script errors.');
      process.exit(r.code);
      return;
    }
    case 'script': {
      const [scriptPath, ...userArgs] = rest;
      if (!scriptPath) die('usage: node scripts/godot.mjs script res://tools/x.gd [-- args]');
      await importProject(godot);
      const r = await runGodot(godot, ['--headless', '--path', PROJECT, '--script', scriptPath, ...userArgs], {
        timeoutMs: 3600000,
      });
      if (r.code === 0 && hasScriptErrors(r.output)) die('godot.mjs: script reported errors.');
      process.exit(r.code);
      return;
    }
    case 'shots': {
      // Renders a scene in a real (off-screen) window: Movie Maker and viewport
      // capture do not work with --headless.
      // Arguments after the frame count are passed on to the scene, which can
      // read them with OS.get_cmdline_user_args() (for example --mode=sheet).
      const [scene = 'res://scenes/main.tscn', out = join(ROOT, 'shots', 'shot.png'), frames = '30', ...sceneArgs] = rest;
      mkdirSync(dirname(resolve(out)), { recursive: true });
      await importProject(godot);
      const r = await runGodot(
        godot,
        [
          '--path', PROJECT, '--position', '-3000,-3000', '--resolution', '1600x900', '--fixed-fps', '60',
          '--script', 'res://tools/shot.gd', '--', `--scene=${scene}`, `--out=${resolve(out)}`, `--frames=${frames}`,
          ...sceneArgs,
        ],
        { timeoutMs: 300000, env: DEFAULT_SETTINGS_ENV },
      );
      // Shaders compile only in a real window, so this is where their errors
      // show; a scene that draws a broken shader still saves its shot.
      if (r.code === 0 && hasShaderErrors(r.output)) die('godot.mjs: a shader failed to compile (see SHADER ERROR above).');
      if (r.code === 0 && hasScriptErrors(r.output)) die('godot.mjs: the scene reported script errors.');
      process.exit(r.code);
      return;
    }
    case 'run':
      spawn(godot, ['--path', PROJECT, ...rest], { stdio: 'inherit', detached: true }).unref();
      return;
    case 'dev':
      spawn(godot, ['--path', PROJECT, '-e', ...rest], { stdio: 'inherit', detached: true }).unref();
      return;
    case 'build': {
      await importProject(godot);
      const outDir = join(ROOT, 'build', 'windows');
      mkdirSync(outDir, { recursive: true });
      // The export preset bakes the shaders, which needs a GPU: on a PC the
      // export runs in a window (it flashes up briefly). CI has no GPU, so it
      // exports headless and the build compiles its shaders on first use.
      const headless = process.env.CI ? ['--headless'] : [];
      const r = await runGodot(
        godot,
        [...headless, '--path', PROJECT, '--export-release', 'Windows Desktop', join(outDir, 'Monomachia.exe')],
        { timeoutMs: 1800000 },
      );
      if (r.code === 0 && hasScriptErrors(r.output)) die('godot.mjs: the export reported script errors.');
      if (r.code !== 0 && /No export template found/.test(r.output)) {
        die(
          'godot.mjs: Windows export templates are not installed. In the Godot editor, open Editor → Manage Export ' +
            'Templates and download 4.7.2 (about 1.3 GB), or let CI build the Windows version.',
        );
      }
      process.exit(r.code);
      return;
    }
    default:
      die(`godot.mjs: unknown command "${cmd}".`);
  }
}

main();
