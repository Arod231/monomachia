# Monomachia

**A one-on-one weapon duel that runs in your browser.** Read your opponent,
parry on the clang, break their posture and send their weapon flying.

![A parry between the katana and the greatsword](docs/screenshots/parry.jpg)

Monomachia (Greek for "single combat") is a third-person 1v1 arena fighter.
This repository is its playable MVP: the core combat loop, built with
[three.js](https://threejs.org) using simple block-built fighters, animation
driven by code and sound generated in code. The whole game builds into a single
HTML file with nothing to install.

## Play

Download **Monomachia.html** from the latest
[release](../../releases) and open it in Chrome, Edge or Firefox. Or build it
yourself (below).

| Mode | What it is |
| --- | --- |
| Duel | You against the computer: easy, normal or hard. First to 3 rounds. |
| Training | A dummy you tell what to do (keys 1–9), with health refill (key 0). |
| Versus | Two players on one screen, split down the middle. |
| Watch | Two computer fighters duel. |

## How a fight works

- **Posture.** The bar under your health. Hits, blocks, parries and counters you
  take fill it. It drains only while you hold block and aren't being hit. While
  it is full, being parried, or blocking an unblockable, a fully charged heavy
  or an ultimate, **disarms you**.
- **Block and parry.** Hold block to stop health damage. Tap it just before a
  hit to parry: their weapon bounces off, their posture fills and you strike
  first. Mashing shrinks the window.
- **Dodge and jump.** A dodge passes through normal attacks; with no direction
  it is a backstep.
- **Unblockables** (red 危 mark) each have a counter: dodge **into** a thrust to
  stomp the blade, **jump** a sweep to vault off the attacker, **back-dash** a
  slam and lunge.
- **Disarmed.** Fight with your fists: faster, with longer dodges and higher
  jumps, but no block. A timed block press becomes a redirect counter. Stand
  on your weapon and press pick up to re-arm.
- **Ultimate.** At 25% health or less, press light + heavy together (or the
  ultimate button), once per round.

![The katana's Moonsplitter ultimate](docs/screenshots/ultimate.jpg)

| Weapon | Size | Style | Ultimate |
| --- | --- | --- | --- |
| Katana | Medium | Balanced and quick, a flash counter | Moonsplitter: a slash wave, vertical (sidestep it) or horizontal (jump it) |
| Greatsword | Colossal | Slow, huge reach and posture damage | Impaler: a lunging skewer, then a burst |
| Twin Daggers | Small | Very fast, short reach | Lightning Tempest: a flash strike into a spinning flurry |

## Controls

Every action can be remapped (menu → Controls) for keyboard, mouse and
controller, and saved in named profiles in the browser. PlayStation and Xbox
controllers show their own button names, and there is an 8-button fight-stick
preset.

| Action | Keyboard & mouse | PlayStation | Xbox |
| --- | --- | --- | --- |
| Move around the opponent | W A S D | Left stick / D-pad | Left stick / D-pad |
| Light attack | Left click or J | R1 | RB |
| Heavy attack (hold to charge) | Right click or K | R2 | RT |
| Block / parry | Shift or L | L1 | LB |
| Dodge / backstep | Space | ○ | B |
| Jump | F or I | ✕ | A |
| Ultimate | Q or U, or light + heavy | △, or R1 + R2 | Y, or RB + RT |
| Block ability 1 / 2 | Hold block + light / heavy | Hold L1 + R1 / R2 | Hold LB + RB / RT |
| Pick up weapon | E | □ | X |
| Pause | Esc or P | Options | Menu |

Tap a direction to step; double-tap and hold to sprint.

In **Versus**, each player picks a device: keyboard and mouse, a controller, or
the arrow-key layout, so two people can share one keyboard (arrows move;
J K L = light, heavy, block; ; dodge; I jump; O pick up; U ultimate;
Backspace pause; numpad 4 5 6 0 8 9 7 also work).

![Versus split screen](docs/screenshots/versus.jpg)

## Build and develop

Needs [Node.js](https://nodejs.org) 22.12 or newer.

```sh
npm install
npm run dev          # live-reloading dev server at http://localhost:5173
npm test             # combat rule tests (no graphics)
npm run soak -- 40   # 40 computer-vs-computer matches; prints balance numbers
npm run build        # type-check, then one self-contained file: dist/index.html
```

`npx tsx scripts/counterlab.ts` measures how often the computer lands each
unblockable counter. `node scripts/browser.mjs <scenario>` plays the built game
in a headless browser and saves screenshots to `shots/` (needs Playwright:
`npm i -D playwright && npx playwright install chromium`).

| Folder | What it holds |
| --- | --- |
| `src/sim` | The rules, with no graphics. They run at a fixed 60 steps per second, so timing is identical on every computer. `fighter.ts` (states), `world.ts` (hits, blocks, parries, counters), `match.ts` (rounds), `ai/` (computer opponent and training dummy). |
| `src/sim/moves` | Frame data for each weapon: startup, active and recovery frames, damage, posture, range. |
| `src/sim/constants.ts` | Global tuning: posture fill and drain, parry windows, counter stuns, movement. |
| `src/render` | three.js scene: arena, puppet fighters posed by code, effects, lock-on camera, split screen, and a safe-graphics fallback for devices that can't draw the full lighting. |
| `src/input` | Keyboard, mouse and controller reading; bindings and profiles. |
| `src/ui` | Menus, HUD, how-to-play. |
| `src/audio` | Sound effects and music generated in code (no audio files). |
| `tests` | Rule tests. |
| `scripts` | Soak runner, counter lab, headless browser checks, post-build step. |
| `scripts/audio` | The Godot build's audio: `npm run audio:sonniss` cuts sounds from the Sonniss bundle zips, `npm run audio:synth` generates the rest, `npm run audio:music` the placeholder music. Output and sources list in `game/assets/audio`. |

## Publishing on GitHub

Three workflows in `.github/workflows` are ready to use:

- **CI** runs the tests and builds the game on every push. The built file is
  downloadable from each run's page.
- **Release**: publish a release on GitHub and `Monomachia.html` is attached
  to it automatically.
- **Deploy to GitHub Pages** puts the game online. One-time setup: Settings →
  Pages → Source: *GitHub Actions*. Then run it from the Actions tab.

## Credits

Built with [three.js](https://threejs.org) (MIT License). Fonts: Zen Antique
and Zen Kaku Gothic New from Google Fonts (SIL Open Font License), loaded when
online. The Godot build's sound effects include processed recordings from the
Sonniss #GameAudioGDC 2026 bundle (royalty-free); `game/assets/audio/SOURCES.md`
lists each one.
