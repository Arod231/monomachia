// Finds the main checkout, whose plan and worktree list the dashboard reads,
// so a copy run from any lane's worktree shows the same data.
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const run = promisify(execFile);
const HERE = path.dirname(fileURLToPath(import.meta.url));

export function mainWorktree(porcelain) {
  const line = porcelain.split(/\r?\n/).find((l) => l.startsWith('worktree '));
  return line ? path.normalize(line.slice(9)) : null;
}

export async function findRepo({ cwd = HERE, env = process.env } = {}) {
  if (env.REPO) return path.resolve(env.REPO);
  const { stdout } = await run('git', ['--no-optional-locks', 'worktree', 'list', '--porcelain'], { cwd, windowsHide: true });
  const repo = mainWorktree(stdout);
  if (!repo) throw new Error('git worktree list named no worktree');
  return repo;
}

// Claude Code names a project's transcript folder after its path this way.
export function projectPrefix(repo) {
  return path.resolve(repo).replace(/[^A-Za-z0-9]/g, '-');
}
