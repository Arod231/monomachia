// The checks and the zip behind `npm run release -- <tag>` (plan task 25.5),
// which scripts/godot.mjs's `release` command runs: a release is exported on
// the developer's PC, where the asset repository's licensed clips are, never
// on CI. The zip, Monomachia-<tag>-windows.zip, holds the exe and the text
// files the build writes beside it (game/tools/build_notices.gd).

import { mkdirSync, readFileSync, statSync, existsSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { crc32, deflateRawSync } from 'node:zlib';

/** What every release zip holds, in order. */
export const RELEASE_FILES = ['Monomachia.exe', 'LICENSE.txt', 'CREDITS.txt', 'THIRD-PARTY-NOTICES.txt'];
/** Written beside the exe when the build has no Iglesias clip libraries. */
export const STAND_IN_FILE = 'STAND-IN.txt';

/** project.godot's config/version, or null. */
export function projectVersion(projectGodot) {
  const m = projectGodot.match(/^config\/version="([^"]+)"/m);
  return m ? m[1] : null;
}

/**
 * Null when the tag may name a release of this version: `v` plus the game's
 * version, optionally with a `-suffix` (v0.2.0, v0.2.0-test); else why not.
 */
export function checkTag(tag, version) {
  if (!version) return 'project.godot has no config/version to check the tag against.';
  if (!tag) return `usage: npm run release -- v${version}[-suffix] [--no-upload]`;
  const m = tag.match(/^v(\d+\.\d+\.\d+)(-[0-9A-Za-z][0-9A-Za-z.-]*)?$/);
  if (!m || m[1] !== version) {
    return `the tag must be v${version} (project.godot's config/version), optionally with a -suffix such as v${version}-test; got ${tag}.`;
  }
  return null;
}

export const zipName = (tag) => `Monomachia-${tag}-windows.zip`;

/**
 * Why the working tree can't be released, from `git status --porcelain
 * --untracked-files=no` and `git branch -r --contains HEAD`: a release must be
 * exactly a commit that is on origin, so its tag can point at it.
 */
export function workProblems(status, remoteBranches) {
  const problems = [];
  const changed = status.split(/\r?\n/).filter((l) => l.trim());
  if (changed.length) {
    problems.push(`tracked files have uncommitted changes (commit or revert them first):\n${changed.map((l) => `  ${l.trim()}`).join('\n')}`);
  }
  const onOrigin = remoteBranches.split(/\r?\n/).some((l) => /^\s*origin\//.test(l));
  if (!onOrigin) problems.push('HEAD is on no branch of origin: push it first, so the release tag can point at it.');
  return problems;
}

/** The files a build folder contributes to its zip, as {name, path}. */
export function releaseFiles(buildDir) {
  const names = [...RELEASE_FILES];
  if (existsSync(join(buildDir, STAND_IN_FILE))) names.push(STAND_IN_FILE);
  return names.map((name) => {
    const path = join(buildDir, name);
    if (!existsSync(path)) throw new Error(`release.mjs: ${name} is missing from ${buildDir}`);
    return { name, path };
  });
}

/** MS-DOS date and time, as zip headers store them. */
function dosTime(date) {
  const time = (date.getHours() << 11) | (date.getMinutes() << 5) | (date.getSeconds() >> 1);
  const day = ((date.getFullYear() - 1980) << 9) | ((date.getMonth() + 1) << 5) | date.getDate();
  return { time, day };
}

/**
 * Writes a zip of files ({name, path}), each deflated, at their names in the
 * zip's root. Files and the zip must stay under 4 GB (no zip64).
 */
export function writeZip(zipPath, files) {
  const parts = [];
  const central = [];
  let offset = 0;
  for (const { name, path } of files) {
    const data = readFileSync(path);
    const packed = deflateRawSync(data, { level: 9 });
    const crc = crc32(data) >>> 0;
    const { time, day } = dosTime(statSync(path).mtime);
    const nameBytes = Buffer.from(name, 'utf8');
    if (data.length >= 0xffffffff || offset + packed.length >= 0xffffffff) throw new Error(`release.mjs: ${name} is too large for a zip without zip64`);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4); // version needed: deflate
    local.writeUInt16LE(0x0800, 6); // names in UTF-8
    local.writeUInt16LE(8, 8); // deflate
    local.writeUInt16LE(time, 10);
    local.writeUInt16LE(day, 12);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(packed.length, 18);
    local.writeUInt32LE(data.length, 22);
    local.writeUInt16LE(nameBytes.length, 26);
    local.writeUInt16LE(0, 28);
    const entry = Buffer.alloc(46);
    entry.writeUInt32LE(0x02014b50, 0);
    entry.writeUInt16LE(20, 4); // made by: MS-DOS attributes, version 2.0
    entry.writeUInt16LE(20, 6);
    entry.writeUInt16LE(0x0800, 8);
    entry.writeUInt16LE(8, 10);
    entry.writeUInt16LE(time, 12);
    entry.writeUInt16LE(day, 14);
    entry.writeUInt32LE(crc, 16);
    entry.writeUInt32LE(packed.length, 20);
    entry.writeUInt32LE(data.length, 24);
    entry.writeUInt16LE(nameBytes.length, 28);
    entry.writeUInt32LE(offset, 42);
    parts.push(local, nameBytes, packed);
    central.push(entry, nameBytes);
    offset += local.length + nameBytes.length + packed.length;
  }
  const directory = Buffer.concat(central);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(files.length, 8);
  end.writeUInt16LE(files.length, 10);
  end.writeUInt32LE(directory.length, 12);
  end.writeUInt32LE(offset, 16);
  mkdirSync(dirname(zipPath), { recursive: true });
  writeFileSync(zipPath, Buffer.concat([...parts, directory, end]));
}
