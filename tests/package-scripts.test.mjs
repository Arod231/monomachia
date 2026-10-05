// Tests for package.json, which is only the task runner since the web demo
// went (plan tasks 26.2 and 26.3): its final script names, and its version
// kept to the game's.

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { projectVersion } from '../scripts/release.mjs';

const pkg = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8'));
const projectGodot = readFileSync(new URL('../game/project.godot', import.meta.url), 'utf8');

describe('package.json', () => {
  it("has project.godot's version", () => {
    assert.equal(pkg.version, projectVersion(projectGodot));
  });

  it("keeps the lockfile's version with it", () => {
    const lock = JSON.parse(readFileSync(new URL('../package-lock.json', import.meta.url), 'utf8'));
    assert.equal(lock.version, pkg.version);
    assert.equal(lock.packages[''].version, pkg.version);
  });

  it('has the final script names (plan task 26.3)', () => {
    assert.deepEqual(Object.keys(pkg.scripts).sort(), [
      'audio:music',
      'audio:sonniss',
      'audio:synth',
      'board',
      'brain',
      'brain:serve',
      'build',
      'check:sizes',
      'checklist',
      'counterlab',
      'dev',
      'godot',
      'play',
      'release',
      'shots',
      'soak',
      'soak:tune',
      'studio',
      'test',
      'test:godot',
      'test:node',
      'typecheck',
    ]);
  });

  it('runs every Godot command through the runner', () => {
    for (const name of ['build', 'counterlab', 'dev', 'play', 'shots', 'soak', 'soak:tune', 'studio', 'test:godot', 'typecheck', 'release']) {
      assert.match(pkg.scripts[name], /^node scripts\/godot\.mjs /, name);
    }
  });

  it('runs the Node tests and then GUT for npm test', () => {
    assert.equal(pkg.scripts.test, 'npm run test:node && npm run test:godot');
  });
});
