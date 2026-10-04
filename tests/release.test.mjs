// Tests for scripts/release.mjs, the checks and the zip behind
// `npm run release -- <tag>` (plan task 25.5; the command itself is
// scripts/godot.mjs's `release`).

import { describe, expect, it } from 'vitest';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { crc32, inflateRawSync } from 'node:zlib';
import { RELEASE_FILES, STAND_IN_FILE, checkTag, projectVersion, releaseFiles, workProblems, writeZip, zipName } from '../scripts/release.mjs';

function withDir(body) {
  const dir = mkdtempSync(join(tmpdir(), 'release-'));
  try {
    body(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

/** Reads a zip back by its central directory: name -> contents (a Buffer). */
function readZip(file) {
  const zip = readFileSync(file);
  const end = zip.lastIndexOf(Buffer.from([0x50, 0x4b, 0x05, 0x06]));
  expect(end).toBeGreaterThan(0);
  const count = zip.readUInt16LE(end + 10);
  let at = zip.readUInt32LE(end + 16);
  const out = new Map();
  for (let i = 0; i < count; i++) {
    expect(zip.readUInt32LE(at)).toBe(0x02014b50);
    const method = zip.readUInt16LE(at + 10);
    const crc = zip.readUInt32LE(at + 16);
    const size = zip.readUInt32LE(at + 24);
    const nameLength = zip.readUInt16LE(at + 28);
    const extraLength = zip.readUInt16LE(at + 30);
    const commentLength = zip.readUInt16LE(at + 32);
    const local = zip.readUInt32LE(at + 42);
    const name = zip.toString('utf8', at + 46, at + 46 + nameLength);
    expect(zip.readUInt32LE(local)).toBe(0x04034b50);
    const packed = zip.readUInt32LE(local + 18);
    const start = local + 30 + zip.readUInt16LE(local + 26) + zip.readUInt16LE(local + 28);
    const data = zip.subarray(start, start + packed);
    const body = method === 8 ? inflateRawSync(data) : Buffer.from(data);
    expect(body.length).toBe(size);
    expect(crc32(body) >>> 0).toBe(crc);
    out.set(name, body);
    at += 46 + nameLength + extraLength + commentLength;
  }
  return out;
}

describe('projectVersion', () => {
  it("reads project.godot's config/version", () => {
    expect(projectVersion('[application]\n\nconfig/name="Monomachia"\nconfig/version="0.2.0"\n')).toBe('0.2.0');
    expect(projectVersion('[application]\nconfig/name="x"\n')).toBeNull();
  });
});

describe('checkTag', () => {
  it('takes v plus the game version, with or without a -suffix', () => {
    expect(checkTag('v0.2.0', '0.2.0')).toBeNull();
    expect(checkTag('v0.2.0-test', '0.2.0')).toBeNull();
    expect(checkTag('v0.2.0-rc.1', '0.2.0')).toBeNull();
  });

  it('refuses a missing tag, a tag for another version, or one not shaped like a version', () => {
    expect(checkTag(undefined, '0.2.0')).toMatch(/usage/);
    expect(checkTag('v0.3.0', '0.2.0')).toMatch(/0\.2\.0/);
    expect(checkTag('0.2.0', '0.2.0')).toMatch(/v0\.2\.0/);
    expect(checkTag('v0.2.0test', '0.2.0')).toMatch(/v0\.2\.0/);
    expect(checkTag('v0.2.0-', '0.2.0')).toMatch(/v0\.2\.0/);
    expect(checkTag('v0.2.0', null)).toMatch(/config\/version/);
  });
});

describe('zipName', () => {
  it('names the zip after the tag', () => {
    expect(zipName('v0.2.0')).toBe('Monomachia-v0.2.0-windows.zip');
  });
});

describe('workProblems', () => {
  it('passes a clean tree whose HEAD a remote branch holds', () => {
    expect(workProblems('', '  origin/feature/godot-rebuild\n')).toEqual([]);
  });

  it('refuses changes to tracked files', () => {
    const problems = workProblems(' M game/project.godot\n', '  origin/master\n');
    expect(problems).toHaveLength(1);
    expect(problems[0]).toContain('game/project.godot');
  });

  it('refuses a HEAD that is on no remote branch', () => {
    const problems = workProblems('', '');
    expect(problems).toHaveLength(1);
    expect(problems[0]).toMatch(/origin/);
  });

  it('counts only branches on origin', () => {
    expect(workProblems('', '  upstream/master\n')).toHaveLength(1);
  });
});

describe('releaseFiles', () => {
  it("lists the build's exe and text files, the stand-in note only when the build has one", () => {
    withDir((dir) => {
      for (const name of RELEASE_FILES) writeFileSync(join(dir, name), name);
      writeFileSync(join(dir, 'Monomachia.console.exe'), 'not shipped');
      expect(releaseFiles(dir).map((f) => f.name)).toEqual(RELEASE_FILES);
      writeFileSync(join(dir, STAND_IN_FILE), 'stand-in');
      expect(releaseFiles(dir).map((f) => f.name)).toEqual([...RELEASE_FILES, STAND_IN_FILE]);
    });
  });

  it('throws when one of the files is missing', () => {
    withDir((dir) => {
      writeFileSync(join(dir, 'Monomachia.exe'), 'exe');
      expect(() => releaseFiles(dir)).toThrow(/LICENSE\.txt/);
    });
  });
});

describe('writeZip', () => {
  it('writes a zip whose files read back byte for byte', () => {
    withDir((dir) => {
      const text = 'Monomachia credits\n'.repeat(200);
      const binary = Buffer.alloc(70000, 7);
      writeFileSync(join(dir, 'CREDITS.txt'), text);
      writeFileSync(join(dir, 'Monomachia.exe'), binary);
      writeFileSync(join(dir, 'empty.txt'), '');
      const zip = join(dir, 'out', 'game.zip');
      writeZip(zip, [
        { name: 'Monomachia.exe', path: join(dir, 'Monomachia.exe') },
        { name: 'CREDITS.txt', path: join(dir, 'CREDITS.txt') },
        { name: 'empty.txt', path: join(dir, 'empty.txt') },
      ]);
      const back = readZip(zip);
      expect([...back.keys()]).toEqual(['Monomachia.exe', 'CREDITS.txt', 'empty.txt']);
      expect(back.get('CREDITS.txt').toString('utf8')).toBe(text);
      expect(back.get('Monomachia.exe').equals(binary)).toBe(true);
      expect(back.get('empty.txt').length).toBe(0);
      expect(readFileSync(zip).length).toBeLessThan(text.length + binary.length);
    });
  });
});
