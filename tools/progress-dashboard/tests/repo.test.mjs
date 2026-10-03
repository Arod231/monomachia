import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { mainWorktree, findRepo, projectPrefix } from '../repo.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));

test('mainWorktree takes the first worktree of the porcelain list', () => {
  const porcelain = 'worktree /a/main\nHEAD 123\nbranch refs/heads/x\n\nworktree /a/main/.claude/worktrees/w\nHEAD 456\n';
  assert.equal(mainWorktree(porcelain), path.normalize('/a/main'));
  assert.equal(mainWorktree(''), null);
});

test('findRepo gives the checkout that owns the .git folder, even from a worktree', async () => {
  const common = execFileSync('git', ['rev-parse', '--path-format=absolute', '--git-common-dir'], { cwd: HERE, encoding: 'utf8' }).trim();
  assert.equal(path.resolve(await findRepo({ cwd: HERE, env: {} })), path.resolve(path.dirname(common)));
});

test('findRepo honours REPO', async () => {
  assert.equal(await findRepo({ cwd: HERE, env: { REPO: '/x/y' } }), path.resolve('/x/y'));
});

test('projectPrefix turns every non-alphanumeric character into a dash', { skip: process.platform !== 'win32' }, () => {
  assert.equal(projectPrefix('C:\\Users\\Win11\\Desktop\\Monomachia'), 'C--Users-Win11-Desktop-Monomachia');
});

test('projectPrefix on posix paths', { skip: process.platform === 'win32' }, () => {
  assert.equal(projectPrefix('/home/a/Mono.x'), '-home-a-Mono-x');
});
