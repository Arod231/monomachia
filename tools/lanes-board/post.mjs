#!/usr/bin/env node
// npm run post -- <files> [--caption "…"] [--task <ref>] [--session <id>]
// Publishes shots and clips to the session's page in the Project Manager: it
// copies stills and MP4s into the media store (media.mjs, outside the repo, so
// nothing posted is ever committed), converts other video (the Movie Maker's
// AVIs, MOV, WebM) to an H.264 MP4 with ffmpeg, gives each clip a poster still,
// and sweeps media past 30 days or 5 GB. The session is the one whose shell
// runs it (CLAUDE_CODE_SESSION_ID), or --session. The board sees the new
// entries on its next look, so no server needs to be up.
import { execFileSync, spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, rmSync, statSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { addEntries, mediaKind, mediaRoot, postArgs, sessionOf, sweepStore } from './media.mjs';

const STATE = process.env.LANES_STATE ?? path.join(os.homedir(), '.claude', 'lanes-board');

const ffmpeg = (args) => spawnSync('ffmpeg', ['-v', 'error', '-y', ...args], { windowsHide: true, encoding: 'utf8' });
const hasFfmpeg = () => spawnSync('ffmpeg', ['-version'], { windowsHide: true }).status === 0;

function branchOf(dir) {
  try { return execFileSync('git', ['-C', dir, 'branch', '--show-current'], { encoding: 'utf8', windowsHide: true, stdio: ['ignore', 'pipe', 'ignore'] }).trim() || null; } catch { return null; }
}

function main(argv) {
  const args = postArgs(argv);
  const session = sessionOf({ flag: args.session, env: process.env });
  const files = args.files.map((f) => {
    const kind = mediaKind(f);
    if (!kind) throw new Error(`Can't post ${f}: post stills (PNG, JPEG, WebP, GIF) or video (MP4, AVI, MOV, WebM, MKV)`);
    const source = path.resolve(f);
    if (!existsSync(source) || !statSync(source).isFile()) throw new Error(`No such file: ${f}`);
    return { kind, source };
  });
  if (files.some((f) => f.kind === 'video') && !hasFfmpeg()) throw new Error('Converting video needs ffmpeg on the PATH');

  const root = mediaRoot(STATE);
  const dir = path.join(root, session);
  mkdirSync(dir, { recursive: true });
  let time = Date.now();
  while (existsSync(path.join(dir, `${time}-0.png`)) || existsSync(path.join(dir, `${time}-0.mp4`))) time++;
  const entries = files.map(({ kind, source }, n) => {
    const id = `${time}-${n}`;
    const base = { id, caption: args.caption, task: args.task, time, source, poster: null };
    if (kind === 'still') {
      const file = `${id}${path.extname(source).toLowerCase().replace('.jpeg', '.jpg')}`;
      copyFileSync(source, path.join(dir, file));
      return { ...base, kind: 'still', file, bytes: statSync(path.join(dir, file)).size };
    }
    const file = `${id}.mp4`;
    const out = path.join(dir, file);
    if (kind === 'clip') copyFileSync(source, out);
    else {
      const r = ffmpeg(['-i', source, '-an', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
        '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2:out_range=tv,format=yuv420p', out]);
      if (r.status !== 0) { rmSync(out, { force: true }); throw new Error(`ffmpeg couldn't convert ${path.basename(source)}: ${r.stderr.trim()}`); }
    }
    let poster = `${id}.poster.jpg`;
    if (!hasFfmpeg() || ffmpeg(['-i', out, '-frames:v', '1', '-q:v', '3', path.join(dir, poster)]).status !== 0) poster = null;
    return { ...base, kind: 'clip', file, poster, bytes: statSync(out).size };
  });
  const cwd = process.cwd();
  addEntries(root, session, { cwd, branch: branchOf(cwd) }, entries);
  const swept = sweepStore(root);
  console.log(`Posted ${entries.length} visual${entries.length === 1 ? '' : 's'} to the session's page in the Project Manager.`
    + `${swept ? ` (The sweep removed ${swept} older one${swept === 1 ? '' : 's'}.)` : ''}`);
}

try { main(process.argv.slice(2)); } catch (err) {
  console.error(`post: ${err.message}`);
  process.exit(1);
}
