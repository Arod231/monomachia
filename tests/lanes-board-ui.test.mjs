// Tests for tools/lanes-board/ui.mjs: the pure pieces both board pages draw
// with, the context gauge, its chart and the roadmap's summary tiles.

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assertMatches } from './assert-matches.mjs';
import {
  fallbackPhases, fmtTokens, gaugeHtml, gaugeLevel, phaseState, planAsPhase, roadmapKpis, sparkPoints, sparkSvg,
} from '../tools/lanes-board/ui.mjs';
import { pageFor } from '../tools/lanes-board/access.mjs';

const ctx = (tokens, window = 200_000, extra = {}) => ({
  model: 'claude-sonnet-4-6', tokens, window, pct: Math.round((tokens / window) * 1000) / 10,
  autoCompactAt: window, updated: 0, series: [], compactions: [], ...extra,
});

describe('fmtTokens', () => {
  it('writes token counts the short way', () => {
    assert.equal(fmtTokens(0), '0');
    assert.equal(fmtTokens(950), '950');
    assert.equal(fmtTokens(1500), '1.5k');
    assert.equal(fmtTokens(9000), '9k');
    assert.equal(fmtTokens(143_210), '143k');
    assert.equal(fmtTokens(967_000), '967k');
    assert.equal(fmtTokens(1_000_000), '1M');
    assert.equal(fmtTokens(1_250_000), '1.3M');
  });
});

describe('gaugeLevel', () => {
  it('is calm under 60%, amber from 60% to 85%, red above 85%', () => {
    assert.equal(gaugeLevel(null), null);
    assert.equal(gaugeLevel(ctx(100_000)), 'calm');
    assert.equal(gaugeLevel(ctx(119_000)), 'calm');
    assert.equal(gaugeLevel(ctx(120_000)), 'warn');
    assert.equal(gaugeLevel(ctx(170_000)), 'warn');
    assert.equal(gaugeLevel(ctx(171_000)), 'high');
  });

  it('is red past the auto-compact line, wherever that is', () => {
    assert.equal(gaugeLevel(ctx(130_000, 200_000, { autoCompactAt: 120_000 })), 'high');
  });
});

describe('gaugeHtml', () => {
  it('draws nothing for a session with no context yet', () => {
    assert.equal(gaugeHtml(null), '');
  });

  it('draws a compact meter with the rounded percent', () => {
    const html = gaugeHtml(ctx(57_400, 200_000), { live: true });
    assert.ok(html.includes('class="gauge calm fresh"'));
    assert.ok(html.includes('width:28.7%'));
    assert.ok(html.includes('>29%<'));
    assert.ok(html.includes('title="Context: 57k of 200k tokens (28.7%)'));
  });

  it('mutes a session that is no longer at work', () => {
    assert.ok(gaugeHtml(ctx(57_400), { live: false }).includes('class="gauge calm stale"'));
  });

  it('draws the full meter with tokens, the exact percent and the auto-compact tick', () => {
    const html = gaugeHtml(ctx(287_495, 1_000_000, { autoCompactAt: 967_000, model: 'claude-opus-5-5' }), { live: true, full: true });
    assert.ok(html.includes('gauge full calm fresh'));
    assert.ok(html.includes('287k / 1M'));
    assert.ok(html.includes('28.7%'));
    assert.ok(html.includes('left:96.7%'));
    assert.ok(html.includes('auto-compacts at 967k'));
    assert.ok(html.includes('claude-opus-5-5'));
  });

  it('keeps the bar inside the meter past 100%', () => {
    assert.ok(gaugeHtml(ctx(260_000), {}).includes('width:100%'));
  });

  it('says 100% on the compact meter only when the window is full', () => {
    assert.ok(gaugeHtml(ctx(199_000), {}).includes('>99%<'));
    assert.ok(gaugeHtml(ctx(200_000), {}).includes('>100%<'));
    assert.ok(gaugeHtml(ctx(199_000), { full: true }).includes('<b>99.5%</b>'));
  });

  it('shows a session compacted since its last reply as just compacted, with an empty, calm meter', () => {
    const c = ctx(0, 200_000, { tokens: null, pct: null, compacted: true, before: 190_000 });
    assert.equal(gaugeLevel(c), 'calm');
    const html = gaugeHtml(c, { live: true });
    assert.ok(html.includes('width:0%'));
    assert.ok(html.includes('>compacted<'));
    assert.ok(html.includes('title="Context: compacted from 190k of 200k tokens; the next reply shows the new fill'));
    const full = gaugeHtml(c, { full: true });
    assert.ok(full.includes('<b>Compacted</b> from 190k / 200k'));
    assert.ok(!full.includes('NaN'));
    assert.ok(!full.includes('null'));
  });

  it('escapes the model name', () => {
    assert.ok(!gaugeHtml(ctx(1000, 200_000, { model: '<x>' }), { full: true }).includes('<x>'));
  });
});

describe('sparkPoints', () => {
  it('spreads the turns over the width by time and scales the height to the window', () => {
    const c = ctx(100_000, 200_000, { series: [{ t: 1000, tokens: 0 }, { t: 2000, tokens: 100_000 }, { t: 5000, tokens: 200_000 }] });
    const pts = sparkPoints(c, 100, 40);
    assert.deepEqual(pts.map((p) => p.x), [0, 25, 100]);
    assert.deepEqual(pts.map((p) => p.y), [40, 20, 0]);
    assertMatches(pts[1], { t: 2000, tokens: 100_000 });
  });

  it('spaces turns evenly when they share one time, and keeps a point above the window on the chart', () => {
    const c = ctx(0, 200_000, { series: [{ t: 5, tokens: 300_000 }, { t: 5, tokens: 50_000 }] });
    const pts = sparkPoints(c, 100, 40);
    assert.deepEqual(pts.map((p) => p.x), [0, 100]);
    assert.equal(pts[0].y, 0);
  });

  it('has no points without a series', () => {
    assert.deepEqual(sparkPoints(null, 100, 40), []);
    assert.deepEqual(sparkPoints(ctx(1), 100, 40), []);
  });
});

describe('sparkSvg', () => {
  const series = [{ t: 1000, tokens: 40_000 }, { t: 2000, tokens: 150_000 }, { t: 3000, tokens: 30_000 }, { t: 4000, tokens: 60_000 }];

  it('draws a scalable chart with a hover title on each turn', () => {
    const svg = sparkSvg(ctx(60_000, 200_000, { series }));
    assert.match(svg, /^<svg[^>]*viewBox="0 0 \d+ \d+"[^>]*preserveAspectRatio="none"/);
    assert.ok(svg.includes('width="100%"'));
    assert.equal(svg.match(/<title>/g).length, 4);
    assert.ok(svg.includes('150k'));
  });

  it('marks each compaction with a small vertical tick', () => {
    const svg = sparkSvg(ctx(60_000, 200_000, { series, compactions: [2500] }));
    assert.equal(svg.match(/class="sc"/g).length, 1);
  });

  it('says when the session has just compacted', () => {
    const svg = sparkSvg(ctx(0, 200_000, { series, tokens: null, pct: null, compacted: true, before: 60_000 }));
    assert.ok(svg.includes('aria-label="Context turn by turn, just compacted"'));
  });

  it('draws the auto-compact line', () => {
    assert.ok(sparkSvg(ctx(60_000, 200_000, { series, autoCompactAt: 150_000 })).includes('class="sa"'));
  });

  it('draws nothing without at least one turn', () => {
    assert.equal(sparkSvg(null), '');
    assert.equal(sparkSvg(ctx(1)), '');
  });
});

// /data plans and lanes, cut down.
const t = (title, status) => ({ title, status, blockers: [], ownerOk: [], gate: false, moved: null, movedTo: null, replaces: [] });
const plan = (key, name, tasks, extra = {}) => ({
  key, short: key.toUpperCase(), name, kind: 'flat', closed: false, branch: 'b', file: `${key}.md`,
  stages: [{ n: 1, name: 'All', ids: Object.keys(tasks) }], tasks,
  counts: Object.values(tasks).reduce((c, x) => ({ ...c, [x.status]: (c[x.status] ?? 0) + 1 }), {}),
  total: Object.values(tasks).filter((x) => !['moved', 'retired'].includes(x.status)).length, ...extra,
});
const GR = plan('gr', 'Godot rebuild', {
  '25.4': t('Credits', 'ready'), '25.5': t('Release', 'blocked'), '26.1': t('Node tests', 'done'),
  '18.4': t('Moved one', 'moved'), '12.9': t('Retired one', 'retired'), '18.11': t('Flashes', 'ready'),
});
const AA = plan('aa', 'Authored animation', { 1: t('Old', 'done') }, { closed: true });
const lane = (extra) => ({ folder: 'wt', branch: 'lane/gr-25.4', plan: 'gr', task: '25.4', scope: ['25.4'], working: true, ended: false, activity: 'active', ...extra });

describe('planAsPhase', () => {
  it('stands a plan in for a phase: its live tasks in build order, counts, ready tasks next and its lanes', () => {
    const ph = planAsPhase(GR, [lane(), lane({ plan: 'aa', folder: 'other' }), lane({ ended: true, folder: 'gone' })]);
    assert.equal(ph.name, 'Godot rebuild');
    assert.deepEqual(ph.refs, ['gr:25.4', 'gr:25.5', 'gr:26.1', 'gr:18.11']);
    assert.equal(ph.total, 4);
    assertMatches(ph.counts, { done: 1, open: 3, ready: 2, blocked: 1 });
    assert.deepEqual(ph.next.map((x) => x.ref), ['gr:25.4', 'gr:18.11']);
    assert.deepEqual(ph.lanes.map((l) => l.folder), ['wt']);
    assertMatches(ph.lanes[0], { task: 'gr:25.4', working: true });
  });
});

describe('fallbackPhases', () => {
  it('lists the open plans as phases until the roadmap is written, the first with open tasks current', () => {
    const done = plan('m1', 'Milestone 1', { 1: t('Done', 'done') });
    const phases = fallbackPhases({ plans: [done, GR, AA], lanes: [] });
    assert.deepEqual(phases.map((p) => p.name), ['Milestone 1', 'Godot rebuild']);
    assert.deepEqual(phases.map((p) => p.current), [false, true]);
  });
});

describe('phaseState', () => {
  const ph = (extra) => ({ current: false, total: 3, counts: { open: 1 }, waiting: [], ...extra });
  it('tells current, done, later and unwritten phases apart', () => {
    assert.equal(phaseState(ph({ current: true })), 'current');
    assert.equal(phaseState(ph({ counts: { open: 0 } })), 'done');
    assert.equal(phaseState(ph({})), 'later');
    assert.equal(phaseState(ph({ total: 0, counts: { open: 0 }, waiting: ['m1:*'] })), 'unwritten');
    assert.equal(phaseState(ph({ total: 0, counts: { open: 0 } })), 'empty');
  });

  it('keeps a phase whose plan is still unwritten open even when its written tasks are done', () => {
    assert.equal(phaseState(ph({ total: 2, counts: { open: 0 }, waiting: ['m1:*'] })), 'later');
  });
});

describe('roadmapKpis', () => {
  const phase = (n, name, refs, extra = {}) => ({ n, name, alongside: null, current: false, refs, unknown: [], waiting: [], total: refs.length, counts: {}, next: [], lanes: [], ...extra });

  it('sums the current phases, an alongside one with its partner, without counting a task twice', () => {
    const data = {
      plans: [GR], lanes: [lane(), lane({ working: false, activity: 'recent', folder: 'b' })],
      roadmap: { phases: [
        phase(1, 'Consolidation', ['gr:26.1'], {}),
        phase(2, 'Milestone 1', ['gr:25.4', 'gr:25.5'], { current: true }),
        phase(3, 'Master follow-ups', ['gr:18.11', 'gr:25.4'], { current: true, alongside: 2 }),
      ] },
    };
    const k = roadmapKpis(data);
    assertMatches(k.current, { names: ['Milestone 1', 'Master follow-ups'], done: 0, total: 3, open: 3, ready: 2, blocked: 1, fallback: false });
    assert.deepEqual(k.readyRefs, ['gr:25.4', 'gr:18.11']);
    assert.equal(k.m1, null);
    assert.equal(k.activeLanes, 1);
    assert.equal(k.onTask, 1);
  });

  it('counts milestone 1 from its plan once it has a copy', () => {
    const m1 = plan('m1', 'Milestone 1', { 1: t('A', 'done'), 2: t('B', 'ready'), 3: t('C', 'moved') });
    const k = roadmapKpis({ plans: [m1, GR], lanes: [], roadmap: { phases: [phase(1, 'M1', ['m1:1', 'm1:2'], { current: true })] } });
    assert.deepEqual(k.m1, { done: 1, total: 2, ready: 1 });
  });

  it('falls back to the first open plan while the roadmap has no copy', () => {
    const k = roadmapKpis({ plans: [GR, AA], lanes: [], roadmap: null });
    assertMatches(k.current, { names: ['Godot rebuild'], fallback: true, total: 4, done: 1 });
  });

  it('has no current phase when everything is done', () => {
    const k = roadmapKpis({ plans: [AA], lanes: [], roadmap: null });
    assertMatches(k.current, { names: [], total: 0 });
  });
});

describe('the board serves ui.mjs to its pages', () => {
  it('as JavaScript', () => {
    assert.deepEqual(pageFor('/ui.mjs', ''), { file: 'ui.mjs', type: 'text/javascript; charset=utf-8' });
  });
});
