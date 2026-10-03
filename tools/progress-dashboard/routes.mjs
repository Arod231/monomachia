// /api/* and /session/* for the session tracker. Mounted by server.mjs before
// its own routes; returns false for anything it doesn't serve.
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { attachStages, taskStates } from './stage.mjs';
import { stageDocs } from './docs.mjs';

const PLAN = 'docs/plans/godot-rebuild.md';
const SPEC = 'docs/specs/godot-rebuild.md';

function send(res, status, body, type = 'application/json') {
  res.writeHead(status, { 'content-type': type, 'cache-control': 'no-store' });
  res.end(type === 'application/json' ? JSON.stringify(body) : body);
}

export function makeRoutes(ctx) {
  async function sessions() {
    const [data, list] = await Promise.all([ctx.getData(), ctx.listSessions()]);
    return attachStages(list, data);
  }
  return async function handle(req, res) {
    // Not new URL(): it throws on a request line like '//', which must fall through to the old routes.
    const p = req.url.split('?')[0];
    let m;
    if (req.method === 'GET' && p === '/api/sessions') { send(res, 200, await sessions()); return true; }
    if (req.method === 'GET' && (m = p.match(/^\/api\/session\/([^/]+)$/))) {
      const s = (await sessions()).find((x) => x.id === m[1]);
      send(res, s ? 200 : 404, s ?? { error: 'no such session' });
      return true;
    }
    if (req.method === 'GET' && (m = p.match(/^\/api\/stage\/(\d+)$/))) {
      const data = await ctx.getData();
      const stage = data.stages.find((s) => s.n === Number(m[1]));
      if (!stage) { send(res, 404, { error: 'no such stage' }); return true; }
      const [plan, spec] = await Promise.all([PLAN, SPEC].map((f) => readFile(path.join(ctx.repo, f), 'utf8')));
      send(res, 200, stageDocs(plan, spec, stage, taskStates(stage, data)));
      return true;
    }
    if (req.method === 'GET' && /^\/session\/[^/]+$/.test(p)) {
      send(res, 200, await readFile(path.join(ctx.here, 'session.html')), 'text/html; charset=utf-8');
      return true;
    }
    if (req.method === 'GET' && p === '/markdown.mjs') {
      send(res, 200, await readFile(path.join(ctx.here, 'markdown.mjs')), 'text/javascript; charset=utf-8');
      return true;
    }
    return false;
  };
}
