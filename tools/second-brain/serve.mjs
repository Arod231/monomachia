#!/usr/bin/env node
// Serves the second brain's viewer and its notes. brainHandler mounts the
// same routes in any server (the all-lanes board mounts it under /brain/);
// run directly, this file serves the working tree's vault on its own.
//
// usage: npm run brain:serve [-- --port 5196]

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { fsSource } from './sources.mjs';
import { buildVault } from './vault.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));

const FILES = {
  '': ['viewer.html', 'text/html; charset=utf-8'],
  'vendor/marked.umd.js': ['vendor/marked.umd.js', 'text/javascript; charset=utf-8'],
};

/**
 * Routes, relative to wherever they're mounted: the viewer page, its script,
 * and notes.json. getSource() returns { key, source, label? }; the vault is
 * rebuilt only when the key changes (a commit id, say), or on every request
 * without one. The label (where the notes came from) shows in the viewer.
 */
export function brainHandler({ getSource, viewerDir = HERE, label: defaultLabel = '' }) {
  let cached = { key: null, body: null };
  return async (req, res, subpath) => {
    const sub = subpath.replace(/^\/+/, '').split('?')[0];
    if (req.method !== 'GET') { res.writeHead(405); res.end(); return; }
    if (sub === 'notes.json') {
      const { key, source, label = defaultLabel } = getSource();
      if (key == null || key !== cached.key) {
        const started = Date.now();
        const { notes } = buildVault(source);
        cached = { key, body: JSON.stringify({ label, key, builtMs: Date.now() - started, notes }) };
      }
      res.writeHead(200, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
      res.end(cached.body);
      return;
    }
    const file = FILES[sub];
    if (!file) { res.writeHead(404, { 'content-type': 'text/plain' }); res.end('Not found'); return; }
    res.writeHead(200, { 'content-type': file[1], 'cache-control': 'no-store' });
    res.end(await readFile(join(viewerDir, file[0])));
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const ROOT = resolve(HERE, '../..');
  const at = process.argv.indexOf('--port');
  const PORT = Number(at > 0 ? process.argv[at + 1] : process.env.PORT ?? 5196);
  const handle = brainHandler({ getSource: () => ({ key: null, source: fsSource(ROOT) }), label: 'working tree' });
  createServer((req, res) => handle(req, res, req.url).catch((err) => {
    console.error(err);
    res.writeHead(500, { 'content-type': 'text/plain' });
    res.end(String(err?.message ?? err));
  })).listen(PORT, '127.0.0.1', () => console.log(`Second brain on http://localhost:${PORT}`));
}
