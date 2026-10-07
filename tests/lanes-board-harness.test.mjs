// The round trip's cleanup: Windows can hold a just-used folder open for a
// moment after the board exits, and the throwaway folders must still go.
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { removeTree } from './lanes-board-harness.mjs';

describe('removeTree', () => {
  it('waits out a folder another process holds open for a moment, then removes it', async () => {
    const root = mkdtempSync(path.join(os.tmpdir(), 'pm-remove-'));
    const held = path.join(root, 'state');
    mkdirSync(held);
    writeFileSync(path.join(held, 'notifications.json'), '[]');
    // A process working in the folder holds it open on Windows until it exits.
    const child = spawn(process.execPath, ['-e', 'setTimeout(() => {}, 600)'], { cwd: held, windowsHide: true });
    await new Promise((r) => child.on('spawn', r));
    await removeTree(root);
    assert.equal(existsSync(root), false);
  });
});
