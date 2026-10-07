Third person arena fighter with melee and weapon based combat

# Game Design Document: *Monomachia*

This is the full vision for the finished game. It combines the original design document with the "Updates to game design doc and plan" notes of Sep 30, 2026 (rebuild in Godot, eight fighters, per-weapon movesets, floating arenas, character select, match intros, music). Where the update changed or added something, it is marked **(update)**. The direction set on Oct 4, 2026 (a realistic dark look, animation that leads the rules' timing, an RTX 3090 as the target, and quality before breadth) is marked **(Oct 4)**; where it replaces a Sep 30 update, the older text is gone, and `docs/adr/0001-animation-leads-realistic-look.md` records why. How the current build works, and every rule question the design leaves open, is recorded in `docs/mvp-spec.md` (the original web demo) and in the specs under `docs/specs/`.

## 1. High Concept & Overview

***Monomachia*** is a 3D arena fighter inspired by For Honor, Tekken, Sekiro, and Soul Calibur. Each match is won by being the first to win 3 rounds. Fighters face off in an arena where they must use their weapon's move set to reduce the opponent's HP to zero. Players choose a fighter and a weapon before the match. Attacks can be blocked, parried, countered, and dodged with precise timing.

Players are encouraged to keep up the pressure, because each attack fills the defender's posture meter. Blocking attacks fills your own posture meter; parrying an opponent's attack fills theirs. Countering an attack stuns the attacker briefly and opens them to attacks that lower their HP. Once a player's posture meter is full, having one of their attacks parried disarms them. **(Oct 4)** Disarming a fighter at 5% HP or less opens them to a weapon-specific **finisher** that ends the round.

Disarmed fighters fight hand to hand, with more agility, extra movement options and longer dodges. They can no longer parry a weapon or block, but they can counter by redirecting attacks with their hands. Bare-hand hits deal extra posture damage and extra knockback. A disarmed fighter can pick their weapon back up, while the other fighter tries to stand in their way to keep the advantage.

Once a player is at 25% HP or less, they gain a single-use-per-round **ultimate ability**. Armed, it is an attack unique to the weapon. Disarmed, it either re-arms the fighter or deals a hard blow to the opponent's posture meter. Re-arming is a power-up: the fighter roars in a burst of golden aura as the weapon returns to their hands, and the burst blasts a nearby opponent off their feet.

Holding block while not being attacked lowers your posture meter. Holding block while standing still restores posture faster than blocking while moving.

* **Genre:** Arena fighter / Action combat / Local & Online Multiplayer
* **Platform (update):** PC (Windows). Built in the Godot engine.
* **Engine (Oct 4):** Godot 4.7. The first milestone checks whether Godot reaches the look and animation bar; the engine is reconsidered only if it clearly doesn't.
* **Release (Oct 4):** a commercial release on Steam. Every asset, tool and licence must allow selling the game, and the age rating must cover blood and the finishers' dismemberment.
* **Target hardware (Oct 4):** the top graphics preset runs at 4K and 60 fps on an NVIDIA RTX 3090. The Low preset stays playable on laptops with integrated graphics, such as the Ryzen 7 4700U laptop the game was first built on. Development moves to the RTX 3090 desktop, where the look and performance are judged.
* **Graphics presets (Oct 4):** four presets. **Ultra** is the RTX 3090 target and the **reference preset** every look is judged at; High and Medium scale down; Low is the integrated-graphics laptop, reaching 60 fps at 1080p by rendering at about 720p and upscaling. The first launch picks a preset from the detected graphics card. Ultra may render below 4K (about 1440p to 1800p) and upscale to it. Low may drop what is only atmosphere (volumetric fog becomes height fog, glowing petals stop casting light, no ambient occlusion, fewer decals) but keeps what reads the fight: the side palettes, the fighters' rim lights, blood, the red 危 and the cinematic shots.
* **Rules rate (Oct 4):** the rules run at a fixed 60 steps a second, as fighting games do and as online rollback will need. Faster displays show frames blended between steps.
* **Order of work (Oct 4):** the existing content (the Katana, Greatsword, Twin Daggers and bare hands; the Rogue and the Hunter; the Moonlit Shrine) is brought to the final quality first, in two **milestones**: the Hunter (both palettes) with the Katana and bare hands on the Moonlit Shrine, then the Greatsword, the Twin Daggers and the second fighter. Animation comes first, on today's bodies re-textured; a mood board and a look test settle the look alongside it, and new fighter models arrive by the second milestone. Everything inside a round reaches final quality in these milestones (weapon draws, victory poses, the ultimates' cinematic shots, the finishers, the KO); match intros and gate walk-outs come with the breadth. A milestone ends when every move passes its checklist, Ultra holds 4K at 60 fps on the RTX 3090 and Low holds 60 fps on the laptop, a balance run comes out clean and every check is green, and then the owner plays the real build (with the asset repository) and signs off. The remaining weapons, fighters, arenas and progression come after, and online play last.
* **Target Audience:** Fans of competitive, fast-paced fighting games and action RPGs (e.g., *For Honor*, *Tekken*, *Sekiro*, *Dark Souls*, *Soul Calibur*).
* **Core Loop:** control your fighter and use their weapon's capabilities to disarm the opponent and reduce their HP to 0 → maintain your posture meter → parry, block, counter and dodge attacks → use your ultimate ability to deal a devastating blow → win 3 rounds to win the match.
* **Tone (update):** dark fantasy, ancient oriental, gritty. Noble warriors who fight for honor and glory.

---

## 2. Core Mechanics & Controls

### Camera Perspective

* **(update)** Over-the-shoulder, like For Honor. The camera stays locked on to the opponent: this is always a one-on-one duel. **(Oct 4, mood board)** Framed as close as For Honor's own camera, replacing the earlier "slightly more zoomed out": the mood board's Camera 2 (about 3.4 m back, 1.0 m to the right (swinging out 0.6 m for each metre closer than 3.5 m), 1.75 m up, a 55° field of view) is the target the look test scene confirms.
* **Cinematic shots (Oct 4):** the fighter intros, every ultimate, every finisher and the final KO get authored cinematic camera shots. Everything else stays on the gameplay camera. An ultimate's shot plays only once it connects: its wind-up stays on the gameplay camera, with the roar and a push-in, so the defender can read it and answer. A KO that ends a round plays on the gameplay camera (the slow motion, the sound drain and the Warrior Slain call), and the winner sheathes or shakes out their hands as a short beat; the authored KO shot and the full victory pose play only for the KO that wins the match. **Milestone 1 (Oct 4):** the recall gets a push-in rather than a shot, a finisher that ends a round plays its own shot through the Warrior Slain call, and a match-winning finisher's shot replaces the authored KO shot before the victory pose (`docs/specs/milestone-1.md`, P37 and P38).

### Movement & Physics

* **Precision fighter control:** an eight-way run system lets your fighter move smoothly in any direction. Pushing up or down moves you toward and away from the opponent. Pushing left or right (including diagonals) circles the opponent, who stays the focus point.
* **Step:** tapping the stick in a direction performs a short, precise step instead of a full run.
* **Sprint:** double-tapping and holding a direction sprints, which opens running-only attacks.
* **Dodge (update):** holding a direction and pressing dodge rolls that way, in any direction. The roll grants invincibility frames: normal attacks pass through the fighter. It keeps the old dash's distance and timing. Its travel follows the roll: an even pace while the fighter tumbles, easing to a stop as they come up. Tapping dodge with no direction performs a backstep, a quick hop back.
* **Jump:** opens a light or heavy jumping attack, and clears sweeps.
* **Blocking movement (update):** players can walk a little faster while blocking than in the original demo. **(Oct 4)** The blocking walk and the disarmed agility come from their gait clips' own measured speeds (about 55–65% of the run, and 1.2× the run when disarmed), not from rules multipliers (`docs/specs/milestone-1.md`, P29).

### Attacking

**Armed mode.** Players have two attack buttons, light and heavy.

* **Light attacks** are quick strikes that can be repeated to pressure the opponent.
* **Heavy attacks** are slow, powerful strikes that deal more HP and posture damage and more knockback. Holding heavy charges the attack; after 2.5 seconds it releases by itself and deals even more HP damage, posture damage and knockback. A charged attack leaves the player vulnerable for a moment.
* **Movement attacks:** sprinting opens running attacks, attacking out of a dodge triggers a dodge follow-up attack, and attacking after a backstep triggers a backstep attack.
* **Strings:** light attacks, heavy attacks and movement attacks combine into combo strings. Each weapon's strings are listed in section 3.
* **String flow (update):**
  * Strings should flow naturally from one swing into the next. If a fighter swings from left to right, the weapon ends on their right, so the next swing in the string comes back from right to left.
  * **Follow-ups are optional.** Many attacks can be followed up by a specific next attack, but the player never has to commit to the follow-up. This applies to every weapon.
  * Two light attacks should flow smoothly into a heavy attack as the third hit.
* **Attack types:** attacks are classed as directional slashes, thrusts, sweeps, overhead slams and ranged attacks, and each is answered in its own way. Thrusts, sweeps and overhead slams are **unblockable**; each has its own counter (see Defending).
* **Block abilities:** attacking while holding block triggers one of two weapon-specific abilities, depending on whether light or heavy is pressed.
* **Ultimate:** when available, pressing light and heavy together triggers the weapon's ultimate.

**Disarmed mode.** Fighters are more agile: dodges go farther and jumps go higher. Bare-hand light attacks deal little HP damage, but repeated strikes deal good posture damage. Each fighter has their own hand-to-hand light, heavy and movement attacks. Tapping block on impact performs a **redirect** counter instead of a parry; it deals extra posture damage to the opponent.

### Defending

Fighters have several defensive options: dodging, parrying, countering, blocking and jumping.

* **Dodge:** a roll with brief invincibility frames (like Dark Souls) that passes through attacks.
* **Parry:** tap block at the precise moment an attack would land. Every attack can be parried, and each parry does a consistent amount of posture damage. Parrying doesn't open the parrier to damage; it lets them act first with a light or heavy attack, which the opponent can in turn parry. The parrier then decides which attack or movement option gives them the advantage.
* **Parry presentation (update):** parries should be cinematic. The two weapons visibly bounce off each other, as in Sekiro, with a flashy "clang" effect and sound. **(Oct 4)** Each attack direction has a matched **deflect pair**, the parrier's deflect and the attacker's recoil, and on the parry the two blades meet at the contact point, where sparks fly off and the clang starts.
* **Block:** shields HP from blockable attacks, and reduces, but doesn't remove, posture damage.
* **Counters** answer the unblockable attacks, which are slow and telegraphed. Dodge invincibility doesn't work against them.
  * **(Oct 4)** Counters, and the Greatsword's Impaler, play **paired clips**: when one lands, the two fighters are lined up over a few frames so their bodies truly meet.
  * **Thrusts** must be dodged *into* to stomp on the thrusting weapon (like Sekiro's mikiri counter). The attacker is stunned and open to a string of attacks.
  * **Sweeps** (horizontal attacks at the feet) must be jumped over; the fighter leaps off the opponent for good posture damage.
  * **Overhead slams** are countered by back-dashing. The counter looks like a quick back dash that can instantly be followed by a special light attack that dashes you to the opponent while they recover.
* **Knockdown (update):** an unblockable, a fully charged heavy or a colossal slam knocks the defender down when it hits. A downed fighter can't be hit. They stand up on a fixed timer and can block or parry as they rise. A hit that knocks out plays a death instead.
* **Disarmed:** a disarmed fighter can't parry or block. Parry is replaced by the timed redirect counter, which deals high posture damage and stuns.
* **Not in this game (update):** no directional guard (block is a single hold, not For Honor's stance directions), and no combo breaker (there is no way to break out of a string once it connects; defense happens before the hit lands).

### Posture Meter (Posture System)

* Fighters take posture damage when they block, when they fail to defend an attack, and when their attacks are parried or countered. Blocking reduces posture damage and protects HP. Failing to defend deals more HP damage, plus the same posture damage as having an attack parried. Counters deal more posture damage.
* A fighter whose posture meter is full is disarmed when one of their attacks is parried, or when they try to block an unblockable attack, a fully charged power attack or an ultimate. The disarming blow does no HP damage.
* **Disarmed weapon (Oct 4):** the weapon flies off in the direction the disarming blow knocked it (on a parry, the way the deflect sends it) and lands stuck blade-first in the ground at an angle, as if thrust into it, instead of bouncing. It always lands inside the arena's walls. Picking it up means pulling it out of the ground.
* **Finisher (Oct 4):** when a fighter is disarmed at 5% HP or less, the disarm plays in slow motion and the fighter who disarmed them gets one timed button prompt: heavy, pressed within about a second of slow motion, shown as the button's glyph over the disarmed fighter (a press made before the prompt appears doesn't count). Pressed in time, it plays their weapon's **finisher**, a cinematic killing move that ends the round; missed, the disarm plays out as normal. The fighter being finished can't escape it, just as there's no combo breaker: defence happens before the disarm. Every weapon has its own finisher, and so do bare hands, since a redirect can disarm. The computer opponent uses finishers too. Section 3 describes each weapon's.
* The lower a fighter's HP, the more slowly posture drains while holding block. Posture drains only while the fighter holds block and isn't being attacked; standing still while blocking is the fastest way to restore it, and moving while blocking restores it more slowly.

---

## 3. Fighters, Weapons & Abilities

### Fighters (update)

Before a match, each player chooses a **fighter** and a **loadout** (a weapon and its two block abilities). Any fighter can wield any weapon; each fighter has a signature weapon offered by default. A fighter's identity shows in their model, personality, match intro and bare-hand fighting style.

| Fighter | Personality |
|---|---|
| **Fantasy Knight** | Noble, duty-driven warrior. |
| **Samurai** | Honor-driven samurai. |
| **Orc / Brute** | Large. Lives to fight: aggressive, but finds honor and glory in defeating enemies, and respects strong fighters. |
| **Rogue / Ninja** | Doesn't care about honor or glory; lives only to execute the mission, and will do anything to slay the enemy. |
| **Aristocrat / Noble** | Raised wealthy and trained in every combat art by the best teachers. Looks down on commoners and claims fighting is boorish, but finds euphoria in dominating an opponent. |
| **Hunter** | Think Bloodborne's Hunter, with old-English flavor. Views opponents as beasts to be eliminated; a slayer of nightmares. |
| **Monk** | Would rather not resort to violence, but defends himself when he must. Wears giant prayer beads around his neck. |
| **Skeleton Knight** | An armored Norse draugr. His bones clack and rattle as he moves. Lacking a soul of his own, he is drawn to powerful souls and believes reaping them will restore him to life. |

**Character models:** clothing should carry the game's aesthetic (gritty, worn, flowing) while also emphasizing each fighter's type and style.

**Roster look (Oct 4):** every fighter is reimagined through the ancient oriental world, with the fantasy pushed further, while keeping as much of their original vibe as possible. The Hunter, for example, stays a Bloodborne-inspired beast hunter in a Bloodborne hunter's clothes, given an oriental spin.

**Models and cloth (Oct 4):** capes, coats and other loose clothing are cloth-simulated. For the first milestone the current bodies are re-textured in the realistic look; new stylised-real models (slightly heroic, readable silhouettes with realistic materials and grime, as in For Honor) arrive by the second, and the owner intends to rework the bodies after that. Where the final models come from is decided at the second milestone. They share a UE5-style game skeleton: today's bone names plus twist bones in the arms and legs, a prop bone in each hand, IK bones and face bones. Faces show a small set of expressions driven by events: effort on attacks, pain on hits, a roar for the ultimate, and death.

**Bare hands (Oct 4):** per-fighter bare-hand movesets stay the goal but wait for the breadth phase; until then the fighters share one bare-hand moveset, re-animated at the new quality.

### Abilities

Each fighter has three abilities in a match: the weapon's ultimate, and two block abilities chosen before the match from a pool specific to the weapon. When choosing a loadout, the player picks which ability goes on light and which on heavy; holding block and pressing that attack triggers it. For example, a polearm's light ability might be a thrust and its heavy ability an overhead attack.

### Weapons

| Weapon | Class | Description |
|---|---|---|
| **Katana** | Medium | Standard Japanese katana: a well-rounded, versatile moveset with decent speed. Its signature block ability, **Flash**, is a parry with a larger window that stuns the opponent and leaves them open. |
| **Odachi** | Colossal | Giant katana: slow, powerful attacks, with overhead slam, sweep and area spin abilities. Larger parry window. Longer range than the katana. |
| **Giant Hammer** | Colossal | Slow and powerful. High posture and HP damage, high knockback, overhead slam abilities and a powerful swing. Larger parry window. |
| **Staff** | Medium | Fast and agile, low HP damage, but quick repeated strikes compensate. Thrust, sweep and spin abilities. Standard posture damage. Good range. |
| **Twin Daggers** | Small | Fast and agile, low posture damage but good HP damage over repeated strikes. A low dashing sweep, and movement abilities that outmaneuver the enemy. Short parry window. |
| **Greatsword** | Colossal | Slow and powerful, high HP and posture damage, high knockback, with sweep and overhead slam abilities. |
| **Longsword & Buckler** | Medium | All-round weapon with good blocking thanks to the shield. Special thrust abilities, and a shield bash that stuns. |
| **Bladed Whip** | Small | Fast and agile, long range, mid-tier damage. Sweep and thrust abilities (the whip extends in a straight line after a telegraphed windup). |
| **Scythe** | Colossal | Slow and powerful, high HP and posture damage, high knockback. Sweep and overhead slam abilities, and an auto-parry that spins the scythe around. |

* **Colossal weapons:** odachi, giant hammer, scythe, greatsword. **(update)** Colossal weapons are significantly bigger two-handed weapons (as in Elden Ring). They are heavy and must look it: swinging one carries the fighter along with its momentum.
* **Weapon models (Oct 4):** every weapon is modelled in Blender to fit the game's themes. The models set the blade lengths, and reach, spacing and balance are retuned to match. **Milestone 1 (Oct 4):** the Katana's model keeps today's 0.72 m blade within 2 cm, so milestone 1's distance bands hold; a different length shifts the band table once, with the owner's OK (`docs/specs/milestone-1.md`, P44).
* **Medium weapons:** katana, longsword & buckler, staff.
* **Small weapons:** twin daggers, bladed whip.

### Movesets (update)

* **Katana:** focused on slashes. **(Oct 4)** Every cut is a two-handed katana cut; only the Iai draws, the finisher's draw and a few one-handed extensions let the off hand go.
  * Lights: a string of four.
  * Heavy, **Iai Slash:** the fighter sheathes the blade and can strafe while holding; on release, a long-range horizontal or vertical draw slash.
    * The vertical slash comes from above and can be followed by a heavy that rises from below, continuing the overhead motion.
    * The horizontal slash cuts right to left and can be followed by a left-to-right heavy.
    * The Iai Slash reaches far but stays a melee attack; the ultimate's slash crosses the whole stage.
* **Odachi:** large, hard-commitment strings.
  * Lights: a three-hit string of two overhead strikes, then a final low-to-high strike.
  * Heavy: a charged spin; the fighter slowly spins and hurls toward the enemy with a heavy swing.
* **Giant Hammer:** large, heavy, slow strikes.
  * Lights: a three-hit string of two side-to-side swings, then a low-to-high golf swing.
  * Heavies: a two-hit string. A low-to-high swing flows, using the hammer's momentum, into a spin that ends in a hard-hitting side-to-side sweep across the front.
  * Charged heavy: a forward-flip overhead slam.
  * Backstep into heavy: a jumping slam.
* **Greatsword:** the sword is heavy; the fighter swings it and rides its momentum.
  * **(update)** It rests on the fighter's shoulder at the round intro and while moving. Heaving it off the shoulder makes that attack a little slower.
  * Lights: side-to-side swings.
  * Heavies: a two-hit string, an overhead strike into an unblockable low sweep.
  * Attacking out of a dodge: a thrust.
* **Bladed Whip:**
  * Lights: a four-hit whip string.
  * Charged heavy: extends the whip's range.
* **Scythe:** a colossal weapon.
  * Lights: side-to-side "reaping" strikes.
  * Heavies: an overhead slam, and an unblockable sweep.
  * Charged heavy: a wound-up side-to-side slash.
* **Longsword & Buckler:** as described in the Weapons table above.
* **Staff:** sweeping and slam attacks. Spinning the staff around is core to its identity.
* **Twin Daggers:** iterate on the demo's daggers. Proposal, to confirm by playtest:
  * Lights: a four-hit string alternating hands: right slash, left slash, crossing X-cut, double stab.
  * Any light can be cancelled into a dodge right after it connects or whiffs. Their identity is slipping in and out.
  * Heavies: a dashing double stab, flowing optionally into a spinning backhand.
  * Dodge attacks: a passing slash that carries the fighter past the opponent's side.
  * Block abilities: Serpent Sweep (a low, dashing, unblockable sweep), Shadow Step (a blink behind the opponent that turns the next light into a backstab), and Needle Thrust (a quick unblockable thrust).

#### Ultimate Weapon Abilities (require 25% HP or less)

1. **Katana:** the fighter sheathes the blade and unleashes a full-stage-length vertical or horizontal slash, chosen by tilting the stick up/down or left/right while sheathed. The horizontal version can be jumped over.
2. **Odachi:** the fighter drags the blade along the floor to unleash a powerful rising slash that knocks the enemy straight into the air, which can be followed by a powerful slash as they fall.
3. **Giant Hammer:** the fighter spins with the hammer, gaining momentum and moving toward the enemy, before a powerful golf swing that hurls the enemy across the arena into a wall, stunning them.
4. **Staff:** the fighter sits atop the staff like Sun Wukong; the staff extends into the air, then slams down on the enemy.
5. **Twin Daggers:** the fighter dashes like lightning to the enemy and spins incredibly fast, striking many times. Each spin can be parried in turn.
6. **Greatsword:** the fighter takes a stance aiming the sword at the enemy, then dashes across the stage to impale them. Once the enemy is impaled, pressing heavy unleashes an explosive burst of energy.
7. **Longsword & Buckler:** the fighter jumps high into the air, then slams the shield down onto the enemy.
8. **Bladed Whip:** the fighter coils up, as if tightening a spring, then spins around quickly, unleashing a cross-stage whip attack.
9. **Scythe:** the fighter jumps high into the air, then launches toward the enemy for a devastating horizontal sweep.

#### Finishers (Oct 4, on a disarm at 5% HP or less)

Each finisher is a paired clip with its own cinematic shot. **Finisher** names only these: the Twin Daggers' Flurry Finisher and the Tempest's Thunder Finisher are renamed when the Daggers are redone in the second milestone, and a string's last hit is called its last hit.

* **Katana:** the fighter sheathes their blade, then draws in a lightning-fast iai slash that carries them through to stand behind the opponent. They re-sheathe, and as the guard clicks home, blood sprays along the cut and the opponent falls to the floor in two halves, cut diagonally from one shoulder to the opposite hip.
* **Bare hands:** the fighter turns the opponent's last attack aside, then drops them with a crushing strike, a palm to the chest or a blow to the throat. It works against any weapon and cuts nothing.
* Each other weapon's finisher is designed as that weapon reaches final quality.

---

## 4. Game Modes & Progression

### Game Modes

* **Duel (1v1):** the standard competitive experience, against a computer opponent or another player.
* **Training, Watch and Versus:** added by the demo. Training is a practice dummy you control; Watch is two computer fighters duelling; Versus is two players on one PC in split screen. They stay.

### Character Select (update)

1. Entering Duel opens the character select screen.
2. Hovering over a fighter shows that fighter's model on the right side of the screen, and the loadout options (weapon and block abilities) on the left.
3. Once a fighter and loadout are chosen, the player **locks in**.
4. On lock-in, a giant gate with a dark fantasy, oriental design opens behind the fighter, and they walk through it. The arena is visible through the gate, unless the player picked random.

### Match Intro (update)

1. Gates appear at either end of the arena, and each selected fighter walks out of one.
2. Each fighter walks a few steps forward and performs an intro animation that reflects who they are and which weapon they picked.
3. The intros play one fighter at a time, and players can skip them.
4. The fighters then take their positions and the match begins (like Tekken 8).

### Arenas

* **(update)** Arenas are larger than the demo's and float above the land, suspended over a void or flying in the air. The backgrounds are dark fantasy, ancient oriental landscapes, with buildings and water features. Arena edges are walled; fighters can't fall off.
* **(Oct 4)** The distant landscape is real 3D: sculpted mountains and cliffs, pagoda and temple models, and volumetric fog and clouds. Low gets a simpler version.
* **(Oct 4)** The Moonlit Shrine is upgraded in place: its props, then its materials, and last its platform are replaced with modelled ones, keeping its layout.
* **The Moonlit Shrine's look (Oct 4):** an ancient battleground under a blood moon and a starry sky. Huge, imposing, ancient wisteria trees with dark bark stand around the arena, their canopy reaching out over it without covering the whole sky, and no tree hides the moon. Their blossoms glow a soft purple and give off light, and the wind sways the branches and rains glowing petals over the fight. The paving stones are worn, weathered, uneven and broken, and the whole arena shares that dilapidated look. Mist drifts through the moon shafts. The canopy never blocks the camera's view of the fighters.
* **Weather (Oct 4):** a dynamic weather system with five states: a clear night sky, partly cloudy, cloudy with lightning and thunder, light rain, and a rainstorm. A match starts in a random state, or one the players pick, and the weather drifts gradually during play, with storms more likely toward the final round. One wind drives it all: the clouds move with it, and so do the branches, falling petals, grass, banners, cloth and rain. A rainstorm is cinematic: lightning strikes light up the fight, and where blades clash the rain is pushed away from the point of impact, as if by a small shockwave. Weather never changes the rules. The clear night comes first, in the first milestone; the weather system and the other states follow after its sign-off.
* **Arena reactions (Oct 4):** arenas react to the fight in the picture only: slams that hit the ground knock up dust and crack the floor, blades leave cut marks and scorch on stone, sparks fly off pillars, and swings and falls push banners and grass. The cracks and marks last the whole match. Nothing in the arena changes the rules.
* **Arena themes:** Moonlit Shrine (from the demo), fantasy coliseum, hell and ice, each reimagined as a floating dark fantasy, oriental arena. The original list's Cyberpunk Grid, Deep Space Nebula, Synthwave Sunset and Retro Vector are dropped because they clash with the art direction.

### Progression & Customization

* **Cosmetics:** unlockable fighter skins earned through fighter proficiency, by performing fighter-specific feats.

---

## 5. Visuals, Audio, & UI/UX

### Art Style & Presentation

* **Visual style:** gritty dark fantasy, ancient oriental. **(Oct 4)** Rendered realistically: physically based materials, dark lighting and volumetric fog under a painterly colour grade. **Ghost of Tsushima** is the main visual reference for palette, atmosphere and material detail, taken from its darker side: the night, storm and supernatural moods of its Legends mode and Iki Island, with deep shadow, mist and the blood moon, and colour used as accents (red leaves, lanterns, blood). This replaces the Sep 30 update's stylized toon look with outlines and ink-wash.
* **No ink rendering (Oct 4):** no toon shading, outlines or ink-wash screen effect during play. Ink survives only as calligraphy in the UI: brushed kanji and titles in the menus, the HUD and the round calls.
* **Look test (Oct 4):** before anything converts, the owner approves a mood board, then a test scene (one fighter with the Katana in a corner of the Moonlit Shrine, at Ultra on the RTX 3090) that also settles the lighting and camera effects.
* **Camera effects (Oct 4):** clean during play: temporal anti-aliasing, subtle bloom, ambient occlusion, fog, the colour grade and light film grain, but no depth of field, motion blur or colour fringing while fighting, so wind-ups stay readable. Those come in for the intros, ultimates, parry push-ins and the KO.
* **Telling the sides apart (Oct 4):** muted but distinct dyed palettes (crimson against indigo, matching the HUD's red and blue) and key and rim lights that touch only the fighters. No outlines. **(Oct 4, mood board)** Crimson dye #9e2b25 against indigo dye #1d2a4d: crimson is the lighter value, so the two read apart in grey.
* **Combat effects (Oct 4):** fully realistic: sparks, blood, dust, smoke and air smears. The ink-brush trails retire. The ultimates keep their supernatural energy (fire, lightning, shockwaves, spirit energy), lit and rendered realistically. **(Oct 4, mood board)** Moonsplitter's wave is moonlight: a crescent of cold silver-white light with a wisteria-violet fringe, curling like a wave's crest and shedding mist and petals. The disarmed ultimate is a spirit shockwave: heat haze and lifted petals at the choice moment, a pale-gold flash and a ring of distortion for Breaker Palm, a larger ring for the recall's burst. Neither takes a side's colour.
* **Violence (Oct 4):** hits draw blood: a burst on each hit, blood on blades and clothes that lasts the whole match, and splatter on the floor that fades. No dismemberment or gore, except in the finishers: with Blood On, a finisher can cut the opponent apart (the Katana's cuts them in half). A Blood setting offers On, Reduced (less blood on every hit, smaller bursts, stains and splatter, and finishers show the cut with less blood, the body staying whole) or Off (no blood). **(Oct 6)** Reduced scales every blood effect as well as the finishers' (the owner's choice for milestone-1 task 38).
* **UI layout:** a minimalist HUD with HP bars in classic fighting-game style and the posture bar underneath. Ultimate access is shown by a glowing aura around the fighter when they are at 25% HP or less. **(Oct 4)** The menus and HUD are redesigned for the new look, replacing the ink-wash theme; the layout above stays, and the style is picked from a UI page of the mood board. **(Oct 4, mood board)** Lacquer and gold: black lacquer panels with gold hairlines and maki-e accents, lacquer-disc round pips, brushed kanji in ivory and Latin titles in a spaced serif. The ultimate aura is a smouldering glow of embers and heat haze in the side's colour.
* **KO call (Oct 4):** every KO that ends a round, finishers included, is called **Warrior Slain**, with a brushed kanji (討死, "fallen in battle"), replacing 一本 K.O. A double KO keeps its own call.
* **Black-and-white mode (Oct 4):** a Settings option, like Ghost of Tsushima's Kurosawa Mode. The whole picture turns black and white with heavier film grain, while blood and the red unblockable warning keep their colour, so the fight stays readable. The two sides' palettes must still read apart in grey.

### Animation (update)

* Attacks should feel weighty, both when they land and when the attack begins.
* Fighters behave realistically:
  * Running fighters lean forward.
  * Dodges look evasive: a directional dodge is a roll.
  * Each fighter moves according to their weapon. Colossal weapons are heavy and look it, and swinging one pulls the fighter along with its momentum.
* Strings flow naturally; a swing that ends on the right continues from the right.
* Unblockable attacks have longer range and a visible effect showing their reach. **(Oct 4)** As the wind-up starts, a red 危 flashes with a sound and the blade glints red; the attack type reads from the animation. Floating labels and floor markers appear only in Training. The "visible effect showing their reach" is the blade's red glint: in matches the reach shows only through the 危, its sound and the glint (`docs/specs/milestone-1.md`, P6).
* Hitboxes should be as tight to the weapon as possible.
* **(update)** Fighters animate from authored clips: attacks, reactions, movement, draws and victory poses. The path that decides hits is taken from the same clip.
* **Animation leads (Oct 4):** each attack's frame data (startup, active and recovery) and its footwork come from its clip; the rules follow the animation, not the other way round. Each attack has a **timing band** set by design, and its clip is edited until it lands inside the band. A clip is never sped up, slowed down or stretched while the game runs to fit the rules, and a fighter never slides along the floor further than the clip's own steps carry them. Only foot locking, the hands' grip on the weapon, mirroring and blending adjust a clip while the game runs; holds, such as the charged heavy's, are authored loops, not frozen frames. Walk, run, strafe and sprint speeds are the clips' own: at full stick each clip plays at its authored rate, and a blend between gaits or directions, kept in step, moves at the blended pace. Every weapon is rebalanced around its clips.
* **Protected timings (Oct 4):** a short list of defensive timings stays set by the rules, and the clips that show them are chosen or made to fit: the parry window, the input buffer, the dodge and backstep (their frames and invincibility), hitstun, blockstun, hit-stop and the knockdown phases. Hitstun, blockstun, hit-stop and the knockdown phases are retuned once for the slower pace, keeping the rule that a defender is free a frame or two before each next hit of a string (enough to block or parry, not to strike back), and then frozen. The parry window and the input buffer keep today's numbers. **Milestone 1 (Oct 4):** "a frame or two" is checked over the frame-data table as 1–2 free frames in light strings at the band floors and at least 1 frame for every other follow-up; the list also takes in the stuns the counters buy, the disarm's stagger and the disarmed daze, and the parry recoil with the parrier's recovery. The retuned values are in `docs/specs/milestone-1.md` (P28 and P50).
* **Pace (Oct 4):** the timing bands set a slower, weightier pace than the web demo's, close to For Honor's: a medium weapon's light attacks (the Katana's) land in roughly 400–500 ms, small weapons and bare hands faster, colossal weapons slower, so each class keeps its feel. Rounds last about 60–90 s. Every weapon is retuned around it.
* **All movement from clips (Oct 4):** a fighter moves only as their clips carry them: attacks' steps, knockback and pushback in the reactions, the ultimates' dashes, and the Shadow Step's vanishing and reappearing. Jump arcs are the exception: they stay a rules number, so clearing a sweep always works the same way, and the jump clips are made to match them.
* **Distance bands (Oct 4):** each weapon has a band of duelling distances its attacks must connect from, set by design. A clip that falls short is re-keyed with a longer step or reach, never slid.
* **Hit reactions (Oct 4):** directional (front, left, right and back; high and low; light and heavy), with a physical layer on the spine, head and arms, pushed from where and how hard the hit lands, so every hit lands a little differently. The physical layer is only in the picture and never changes the rules.
* **Strings and cancels (Oct 4):** follow-ups and dodge cancels open at markers on each clip, where the body can plausibly break off; a follow-up starts from its branch point rather than waiting for the move to end.
* **Guard movement (Oct 4):** the directional walk and run blend, plus guarded strafe and shuffle cycles for each weapon class and short starts, stops and pivots. A tap step keeps its instant start.
* **Momentum (Oct 4):** every movement carries momentum, and the weight visibly shifts. Starting a run, stopping and turning take the time and distance of their clips: a fighter running one way who reverses plants a foot, shifts their weight and pushes off the other way, and the rules move them exactly as that clip does. Attacks, dodges, backsteps, parries and blocks still start at once out of any movement, and the body's leftover momentum shows in the hand-off. Attacks move the body too: a Katana's vertical slash steps forward into the cut. Guarded steps start and stop within about 0.1 s; run stops and plant-and-reverse pivots take about 0.2 to 0.25 s and up to about 0.5 m; a sprint stop takes about a third of a second and 1 m.
* **Hand-offs (Oct 4):** one motion hands over to the next by inertial blending: the new motion starts at once, and what is left of the old pose fades out over a few frames, hit reactions included. Authored transition clips add to it: returns to guard, bridges between the hits of a string, and run stops and pivots.
* **Quality bar (Oct 4):** every move is judged against For Honor (weight and readability in a locked-on duel), Ghost of Tsushima (grounded, cinematic realism) and Tekken 8 / Mortal Kombat 1 (snap, and impacts that read instantly). A move is accepted against a written checklist (the attack type reads early in the wind-up, the weight visibly shifts, planted feet slide no more than 1 cm, the blade never passes through the body, the move hands off cleanly), with automated checks where possible, a side-by-side video against the reference games, and the owner playing it in a real match with the licensed clips loaded.
* **(update)** Each weapon is drawn at the round intro and has its own victory pose. The Katana is sheathed with a bow, the Daggers toss and catch a blade, the Greatsword is planted in the ground, and bare hands cheer.

### Sound Design

* **SFX:**
  * Weapon clangs when weapons make contact, and a satisfying metal clang unique to parries.
  * Slicing-flesh sounds when blades connect.
  * Bone and rock crushing noises when colossal weapons land.
  * **(update)** Each fighter's movement has its own sound, such as the Skeleton Knight's rattling bones.
  * **(Oct 4)** Footsteps land where the clips' feet do and sound like the surface underfoot (stone, wood, water). Each fighter's cloth and armour has its own movement sounds, flesh and bone layers match the blood, and metal impacts depend on which weapons meet.
  * **(Oct 4)** Each fighter has effort vocals: breaths, kiai shouts on heavies, pain on hits and death cries.
  * **(Oct 4)** The final hit flows into the KO call: its impact rings out as the slow motion drains the arena's sound and the music, then a deep drum lands under "Warrior Slain".
* **Music (update):** dark fantasy and ancient oriental instruments, combined with electronic and metal. **(Oct 4)** In matches, traditional percussion and instruments (taiko, shakuhachi, biwa, low choir) lead, and the electronic and metal layers rise at match point; the menus keep the groovier fusion.
  * Match music: 130–150 BPM, fast-paced, high-energy, upbeat battle themes, themed around each stage.
  * Final-round ("match point") themes: 150–170+ BPM.
  * Character select, menus and loading screens: 100–120 BPM, slower and groovier, an electric and oriental-funk fusion.

### Assets (update)

* **Spending (Oct 4):** up to about $300 on assets and tools for bringing the existing content to the final quality. First Cascadeur Indie (physics-assisted hand animation) and Git LFS storage for the asset repository; the rest waits until the first milestone shows what's missing.
* **Animation sources (Oct 4):** the owned Kevin Iglesias packs, plus clips hand-keyed in Blender. No animation packs are bought for the existing content.
* **Where assets live (Oct 4):** paid and large source art lives in a private **asset repository** (with Git LFS for big files), which the import tools read. The public repository holds the code, free-licence and self-made art, and stand-ins. Blender source files live in the asset repository too, and a scripted export makes the files the game uses. Size budgets are set per place: a small public repository, a budget per asset in the asset repository, and a target size for the shipped game. Clones and CI builds without the asset repository use labelled stand-ins; real builds, playtests and releases always use it.
* **Licence (Oct 4):** the repository's own code and art are source-visible with all rights reserved; third-party assets keep their own terms.
* **Generative AI (Oct 4):** allowed for concept art and mood boards only, never for shipped or committed art.
* Assets must be easy to swap as new files and downloaded packs become available.
* Current sources:
  * Quaternius characters, outfits, animations and weapons (CC0).
  * Kevin Iglesias's Human Melee and Human Basic Motions animation packs (Standard Asset Store EULA: commercial use allowed, no redistribution). They are used in builds but never committed: an import tool converts the clips locally, and CC0 clips stand in when the packs are missing. **(Oct 4)** Numbers measured from them (frame data, hit paths, travel) are committed, with each move's source clip recorded so it can be re-baked from another clip.
  * The Sonniss GDC 2026 game audio bundle (royalty-free).

### Controls

* Players can map custom controls on individual player profiles, for keyboard and mouse and for controller.
