// Tests for scripts/release.mjs, the checks and the zip behind
// `npm run release -- <tag>` (plan task 25.5; the command itself is
// scripts/godot.mjs's `release`).

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
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
  assert.ok(end > 0);
  const count = zip.readUInt16LE(end + 10);
  let at = zip.readUInt32LE(end + 16);
  const out = new Map();
  for (let i = 0; i < count; i++) {
    assert.equal(zip.readUInt32LE(at), 0x02014b50);
    const method = zip.readUInt16LE(at + 10);
    const crc = zip.readUInt32LE(at + 16);
    const size = zip.readUInt32LE(at + 24);
    const nameLength = zip.readUInt16LE(at + 28);
    const extraLength = zip.readUInt16LE(at + 30);
    const commentLength = zip.readUInt16LE(at + 32);
    const local = zip.readUInt32LE(at + 42);
    const name = zip.toString('utf8', at + 46, at + 46 + nameLength);
    assert.equal(zip.readUInt32LE(local), 0x04034b50);
    const packed = zip.readUInt32LE(local + 18);
    const start = local + 30 + zip.readUInt16LE(local + 26) + zip.readUInt16LE(local + 28);
    const data = zip.subarray(start, start + packed);
    const body = method === 8 ? inflateRawSync(data) : Buffer.from(data);
    assert.equal(body.length, size);
    assert.equal(crc32(body) >>> 0, crc);
    out.set(name, body);
    at += 46 + nameLength + extraLength + commentLength;
  }
  return out;
}

describe('projectVersion', () => {
  it("reads project.godot's config/version", () => {
    assert.equal(projectVersion('[application]\n\nconfig/name="Monomachia"\nconfig/version="0.2.0"\n'), '0.2.0');
    assert.equal(projectVersion('[application]\nconfig/name="x"\n'), null);
  });
});

describe('checkTag', () => {
  it('takes v plus the game version, with or without a -suffix', () => {
    assert.equal(checkTag('v0.2.0', '0.2.0'), null);
    assert.equal(checkTag('v0.2.0-test', '0.2.0'), null);
    assert.equal(checkTag('v0.2.0-rc.1', '0.2.0'), null);
  });

  it('refuses a missing tag, a tag for another version, or one not shaped like a version', () => {
    assert.match(checkTag(undefined, '0.2.0'), /usage/);
    assert.match(checkTag('v0.3.0', '0.2.0'), /0\.2\.0/);
    assert.match(checkTag('0.2.0', '0.2.0'), /v0\.2\.0/);
    assert.match(checkTag('v0.2.0test', '0.2.0'), /v0\.2\.0/);
    assert.match(checkTag('v0.2.0-', '0.2.0'), /v0\.2\.0/);
    assert.match(checkTag('v0.2.0', null), /config\/version/);
  });
});

describe('zipName', () => {
  it('names the zip after the tag', () => {
    assert.equal(zipName('v0.2.0'), 'Monomachia-v0.2.0-windows.zip');
  });
});

describe('workProblems', () => {
  it('passes a clean tree whose HEAD a remote branch holds', () => {
    assert.deepEqual(workProblems('', '  origin/feature/godot-rebuild\n'), []);
  });

  it('refuses changes to tracked files', () => {
    const problems = workProblems(' M game/project.godot\n', '  origin/master\n');
    assert.equal(problems.length, 1);
    assert.ok(problems[0].includes('game/project.godot'));
  });

  it('refuses a HEAD that is on no remote branch', () => {
    const problems = workProblems('', '');
    assert.equal(problems.length, 1);
    assert.match(problems[0], /origin/);
  });

  it('counts only branches on origin', () => {
    assert.equal(workProblems('', '  upstream/master\n').length, 1);
  });
});

describe('releaseFiles', () => {
  it("lists the build's exe and text files, the stand-in note only when the build has one", () => {
    withDir((dir) => {
      for (const name of RELEASE_FILES) writeFileSync(join(dir, name), name);
      writeFileSync(join(dir, 'Monomachia.console.exe'), 'not shipped');
      assert.deepEqual(releaseFiles(dir).map((f) => f.name), RELEASE_FILES);
      writeFileSync(join(dir, STAND_IN_FILE), 'stand-in');
      assert.deepEqual(releaseFiles(dir).map((f) => f.name), [...RELEASE_FILES, STAND_IN_FILE]);
    });
  });

  it('throws when one of the files is missing', () => {
    withDir((dir) => {
      writeFileSync(join(dir, 'Monomachia.exe'), 'exe');
      assert.throws(() => releaseFiles(dir), /LICENSE\.txt/);
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
      assert.deepEqual([...back.keys()], ['Monomachia.exe', 'CREDITS.txt', 'empty.txt']);
      assert.equal(back.get('CREDITS.txt').toString('utf8'), text);
      assert.equal(back.get('Monomachia.exe').equals(binary), true);
      assert.equal(back.get('empty.txt').length, 0);
      assert.ok(readFileSync(zip).length < text.length + binary.length);
    });
  });
});
