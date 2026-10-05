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
//   bench [scene args...]  the frame-time harness: plays the worst-case replay in a window
//                          and writes every frame's time to build/bench/ (tools/bench/frame_time_bench.gd)
//   run                    play the game
//   studio                 open the Animation Studio (gallery, editor and chat panel; dev tool)
//   dev                    open the editor
//   build                  export the Windows build to build/windows/, with the licence,
//                          credits and notices beside the exe (tools/build_notices.gd)
//   release <tag> [--no-upload]   on the PC with the clips: export, --smoke the exe, zip
//                          Monomachia-<tag>-windows.zip and attach it to the tag's GitHub
//                          release, a draft made if needed (scripts/release.mjs)
//   clips                  convert the clip manifest's Iglesias clips into the
//                          gitignored clip libraries (needs the packs; see findAssetsSrc)
//   bake [--weapon=<id>] [--check]   bake the swings of the moves in the move-clip
//                          table from the clip libraries (tools/bake_swings.gd)
//
// package.json's scripts call most of these by their own names (plan task
// 26.3): test:godot, typecheck, soak (soak:tune runs 300), build, release,
// play (= run), dev, studio, shots, bench, counterlab (= script
// res://tools/counterlab.gd) and bench:record (= script
// res://tools/bench/record_worst_case.gd); `npm run godot -- <command>` reaches the rest.
//
// Godot is found through the GODOT environment variable, then `godot` or
// `godot4` on PATH, then a local `.godot-path` file (see findGodot).

import { spawn, spawnSync } from 'node:child_process';
import { existsSync, readFileSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { STAND_IN_FILE, checkTag, projectVersion, releaseFiles, workProblems, writeZip, zipName } from './release.mjs';

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

/**
 * The folder holding the raw asset packs (quaternius/ and kevin_iglesias/),
 * a checkout of the private asset repository on the owner's PC, from a
 * one-line `.assets-src-path` file at the repo root
 * (not committed), or the main checkout's in a linked git worktree. Null when
 * there is none; the Godot tools then look in `assets_src/` at the repo root
 * (tools/asset_source.gd). Passed to every Godot run as MONOMACHIA_ASSETS_SRC.
 */
export function findAssetsSrc() {
  if (process.env.MONOMACHIA_ASSETS_SRC) return process.env.MONOMACHIA_ASSETS_SRC;
  const roots = [ROOT];
  const common = spawnSync('git', ['rev-parse', '--path-format=absolute', '--git-common-dir'], { cwd: ROOT, encoding: 'utf8' });
  if (common.status === 0 && common.stdout.trim()) roots.push(dirname(common.stdout.trim()));
  for (const root of roots) {
    const file = join(root, '.assets-src-path');
    if (!existsSync(file)) continue;
    const p = readFileSync(file, 'utf8').trim();
    if (p) return p;
  }
  return null;
}

function die(msg) {
  console.error(msg);
  process.exit(1);
}

// Test and shot runs set this environment variable so the player's saved
// settings (user://settings.cfg, such as a lower graphics preset) and controls
// profiles (user://controls.cfg) can't change them. GameSettings.DEFAULTS_ENV
// reads it. (GUT refuses unknown arguments, so it can't be a command-line flag.)
const DEFAULT_SETTINGS_ENV = { MONOMACHIA_DEFAULT_SETTINGS: '1' };
const ERROR_PATTERNS = [/SCRIPT ERROR/, /Parse Error/, /Failed to load script/, /^ERROR: .*\.gd/m];
const SHADER_ERROR_PATTERNS = [/SHADER ERROR/];

/**
 * Run Godot with a timeout. Resolves with {code, output}. Output is streamed
 * through unless quiet is set.
 */
function runGodot(godot, args, { timeoutMs = 600000, quiet = false, cwd = PROJECT, env = {} } = {}) {
  return new Promise((res) => {
    const assets = findAssetsSrc();
    const assetsEnv = assets ? { MONOMACHIA_ASSETS_SRC: assets } : {};
    const child = spawn(godot, args, { cwd, stdio: ['ignore', 'pipe', 'pipe'], env: { ...process.env, ...assetsEnv, ...env } });
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

const UPLOAD_TRIES = 3;
const STAND_IN_WARNING =
  'godot.mjs: WARNING: no Kevin Iglesias clip libraries, so this is a stand-in build (STAND-IN.txt is in it, and in ' +
  'attacks the weapons drift off the hands). Build the libraries with `node scripts/godot.mjs clips` before a real release.';

/**
 * Exports the Windows build to build/windows/ and writes LICENSE.txt,
 * CREDITS.txt and THIRD-PARTY-NOTICES.txt beside the exe, plus STAND-IN.txt
 * when the project has no clip libraries (tools/build_notices.gd). Returns the
 * folder; exits on any failure.
 */
async function exportWindows(godot) {
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
  if (r.code !== 0) process.exit(r.code);
  const out = `--out=${outDir.split('\\').join('/')}`;
  const notices = await runGodot(godot, ['--headless', '--path', PROJECT, '--script', 'res://tools/write_build_notices.gd', '--', out]);
  if (notices.code !== 0 || hasScriptErrors(notices.output)) die('godot.mjs: writing the licence and credits files failed.');
  return outDir;
}

async function main() {
  const [cmd = 'help', ...rest] = process.argv.slice(2);
  if (cmd === 'help' || cmd === '--help') {
    console.log('usage: node scripts/godot.mjs import|test|typecheck|soak|script|shots|bench|run|studio|dev|build|release|clips|bake');
    console.log('npm scripts: test:godot, typecheck, soak, soak:tune, build, release, play (run), dev, studio, shots, bench, bench:record, counterlab;');
    console.log('the rest through npm run godot -- <command> (see the top of scripts/godot.mjs).');
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
    case 'bench': {
      // The frame-time harness (milestone-1 task 28) in a real window: the
      // match renders into its own 4K target, so the window's size doesn't
      // matter. --fixed-fps 60 moves the view 1/60 s a frame, one rules step
      // a frame, without capping the frame rate.
      const outDir = join(ROOT, 'build', 'bench');
      mkdirSync(outDir, { recursive: true });
      const stamp = new Date().toISOString().replace(/[-:]/g, '').replace('T', '-').slice(0, 15);
      const args = rest.some((a) => a.startsWith('--out=')) ? rest : [`--out=${join(outDir, `frame-times-${stamp}.csv`)}`, ...rest];
      await importProject(godot);
      const r = await runGodot(
        godot,
        ['--path', PROJECT, '--resolution', '1600x900', '--fixed-fps', '60', 'res://tools/bench/frame_time_bench.tscn', '--', ...args],
        { timeoutMs: 1800000, env: DEFAULT_SETTINGS_ENV },
      );
      if (r.code === 0 && hasShaderErrors(r.output)) die('godot.mjs: a shader failed to compile (see SHADER ERROR above).');
      if (r.code === 0 && hasScriptErrors(r.output)) die('godot.mjs: the bench reported script errors.');
      process.exit(r.code);
      return;
    }
    case 'clips': {
      // Stage the manifest's clips from the packs, import them, then build the
      // libraries (tools/import_clips.gd).
      await importProject(godot);
      const staged = await runGodot(godot, ['--headless', '--path', PROJECT, '--script', 'res://tools/import_clips.gd', '--', '--stage']);
      if (staged.code === 2) die('godot.mjs: no clips converted: the Iglesias packs were not found (see above).');
      if (staged.code !== 0 || hasScriptErrors(staged.output)) die('godot.mjs: staging the clips failed.');
      await importProject(godot);
      const built = await runGodot(godot, ['--headless', '--path', PROJECT, '--script', 'res://tools/import_clips.gd', '--', '--build']);
      if (built.code !== 0 || hasScriptErrors(built.output)) die('godot.mjs: building the clip libraries failed.');
      return;
    }
    case 'bake': {
      // Bake the swings of the moves in the move-clip table (tools/bake_swings.gd).
      await importProject(godot);
      const r = await runGodot(godot, ['--headless', '--path', PROJECT, '--script', 'res://tools/bake_swings.gd', '--', ...rest]);
      if (r.code === 2) die('godot.mjs: nothing baked: no clip libraries (run node scripts/godot.mjs clips).');
      if (r.code !== 0 || hasScriptErrors(r.output)) die('godot.mjs: the bake failed.');
      return;
    }
    case 'run':
      spawn(godot, ['--path', PROJECT, ...rest], { stdio: 'inherit', detached: true }).unref();
      return;
    case 'studio':
      // The Animation Studio (tools/anim_studio), windowed at 1600x900.
      spawn(godot, ['--path', PROJECT, '--resolution', '1600x900', 'res://tools/anim_studio/studio.tscn', ...rest], { stdio: 'inherit', detached: true }).unref();
      return;
    case 'dev':
      spawn(godot, ['--path', PROJECT, '-e', ...rest], { stdio: 'inherit', detached: true }).unref();
      return;
    case 'build':
      await exportWindows(godot);
      return;
    case 'release': {
      // A release, exported here on the PC with the asset repository's clips
      // (CI's export is only a stand-in): the checks, the export, the exe's
      // --smoke, the zip, then gh release upload to the tag's release, made as
      // a draft if there is none; publishing stays a person's click. See
      // scripts/release.mjs.
      const [tag] = rest.filter((a) => !a.startsWith('--'));
      const upload = !rest.includes('--no-upload');
      const tagProblem = checkTag(tag, projectVersion(readFileSync(join(PROJECT, 'project.godot'), 'utf8')));
      if (tagProblem) die(`godot.mjs: ${tagProblem}`);
      spawnSync('git', ['fetch', '--quiet', 'origin'], { cwd: ROOT, stdio: 'inherit' });
      const git = (args) => spawnSync('git', args, { cwd: ROOT, encoding: 'utf8' }).stdout ?? '';
      const problems = workProblems(git(['status', '--porcelain', '--untracked-files=no']), git(['branch', '-r', '--contains', 'HEAD']));
      if (problems.length) die(`godot.mjs: can't release ${tag}:\n- ${problems.join('\n- ')}`);
      const head = git(['rev-parse', 'HEAD']).trim();
      const outDir = await exportWindows(godot);
      const standIn = existsSync(join(outDir, STAND_IN_FILE));
      if (standIn) console.warn(`\n${STAND_IN_WARNING}\n`);
      console.log('godot.mjs: playing the exported game with --smoke...');
      const smoke = await runGodot(join(outDir, 'Monomachia.exe'), ['--smoke'], { cwd: outDir, timeoutMs: 300000 });
      if (smoke.code !== 0) die(`godot.mjs: the exported game failed its --smoke run (exit ${smoke.code}).`);
      const zip = join(ROOT, 'build', 'release', zipName(tag));
      writeZip(zip, releaseFiles(outDir));
      console.log(`godot.mjs: wrote ${zip}.`);
      if (upload) {
        const gh = (args) => spawnSync('gh', args, { cwd: ROOT, encoding: 'utf8' });
        if (gh(['release', 'view', tag]).status !== 0) {
          const made = gh([
            'release', 'create', tag, '--draft', '--target', head, '--title', `Monomachia ${tag}`,
            '--notes', `Monomachia ${tag} for Windows: unzip ${zipName(tag)} and run Monomachia.exe.`,
          ]);
          if (made.status !== 0) die(`godot.mjs: gh release create failed:\n${made.stderr}`);
          console.log(`godot.mjs: made a draft release ${tag} at ${head.slice(0, 7)}.`);
        }
        // A slow uplink can stall long enough for GitHub to drop the upload
        // (HTTP 408), so it gets three tries; --clobber replaces a partial asset.
        let sent;
        for (let attempt = 1; attempt <= UPLOAD_TRIES; attempt++) {
          console.log(`godot.mjs: uploading ${zipName(tag)} (try ${attempt} of ${UPLOAD_TRIES})...`);
          sent = gh(['release', 'upload', tag, zip, '--clobber']);
          if (sent.status === 0) break;
          console.warn(`godot.mjs: the upload failed: ${sent.stderr.trim()}`);
        }
        if (sent.status !== 0) die(`godot.mjs: gh release upload failed ${UPLOAD_TRIES} times; retry with gh release upload ${tag} "${zip}" --clobber`);
        const url = gh(['release', 'view', tag, '--json', 'url', '--jq', '.url']).stdout.trim();
        console.log(`godot.mjs: uploaded ${zipName(tag)} to ${url}`);
      }
      console.log(standIn ? STAND_IN_WARNING : `godot.mjs: release ${tag} ${upload ? 'uploaded' : 'zipped (not uploaded)'}, with the licensed clips.`);
      return;
    }
    default:
      die(`godot.mjs: unknown command "${cmd}".`);
  }
}

main();
