Third person arena fighter with melee and weapon based combat

# Game Design Document: *Monomachia*

This is the full vision for the finished game. It combines the original design document with the "Updates to game design doc and plan" notes of Sep 30, 2026 (rebuild in Godot, eight fighters, per-weapon movesets, floating arenas, character select, match intros, music). Where the update changed or added something, it is marked **(update)**. How the current build works, and every rule question the design leaves open, is recorded in `docs/mvp-spec.md` (the original web demo) and in the specs under `docs/specs/`.

## 1. High Concept & Overview

***Monomachia*** is a 3D arena fighter inspired by For Honor, Tekken, Sekiro, and Soul Calibur. Each match is won by being the first to win 3 rounds. Fighters face off in an arena where they must use their weapon's move set to reduce the opponent's HP to zero. Players choose a fighter and a weapon before the match. Attacks can be blocked, parried, countered, and dodged with precise timing.

Players are encouraged to keep up the pressure, because each attack fills the defender's posture meter. Blocking attacks fills your own posture meter; parrying an opponent's attack fills theirs. Countering an attack stuns the attacker briefly and opens them to attacks that lower their HP. Once a player's posture meter is full, having one of their attacks parried disarms them.

Disarmed fighters fight hand to hand, with more agility, extra movement options and longer dodges. They can no longer parry a weapon or block, but they can counter by redirecting attacks with their hands. Bare-hand hits deal extra posture damage and extra knockback. A disarmed fighter can pick their weapon back up, while the other fighter tries to stand in their way to keep the advantage.

Once a player is at 25% HP or less, they gain a single-use-per-round **ultimate ability**. Armed, it is an attack unique to the weapon. Disarmed, it either re-arms the fighter or deals a hard blow to the opponent's posture meter.

Holding block while not being attacked lowers your posture meter. Holding block while standing still restores posture faster than blocking while moving.

* **Genre:** Arena fighter / Action combat / Local & Online Multiplayer
* **Platform (update):** PC (Windows). Built in the Godot engine.
* **Target Audience:** Fans of competitive, fast-paced fighting games and action RPGs (e.g., *For Honor*, *Tekken*, *Sekiro*, *Dark Souls*, *Soul Calibur*).
* **Core Loop:** control your fighter and use their weapon's capabilities to disarm the opponent and reduce their HP to 0 → maintain your posture meter → parry, block, counter and dodge attacks → use your ultimate ability to deal a devastating blow → win 3 rounds to win the match.
* **Tone (update):** dark fantasy, ancient oriental, gritty. Noble warriors who fight for honor and glory.

---

## 2. Core Mechanics & Controls

### Camera Perspective

* **(update)** Over-the-shoulder, like For Honor, but slightly more zoomed out. The camera stays locked on to the opponent: this is always a one-on-one duel.

### Movement & Physics

* **Precision fighter control:** an eight-way run system lets your fighter move smoothly in any direction. Pushing up or down moves you toward and away from the opponent. Pushing left or right (including diagonals) circles the opponent, who stays the focus point.
* **Step:** tapping the stick in a direction performs a short, precise step instead of a full run.
* **Sprint:** double-tapping and holding a direction sprints, which opens running-only attacks.
* **Dodge:** holding a direction and pressing dodge dashes that way. The dash grants invincibility frames: normal attacks pass through the fighter. It is a dash, not a roll, with momentum and slight friction for smooth control. Tapping dodge with no direction performs a backstep.
* **Jump:** opens a light or heavy jumping attack, and clears sweeps.
* **Blocking movement (update):** players can walk a little faster while blocking than in the original demo.

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

* **Dodge:** a dash with brief invincibility frames (like Dark Souls) that passes through attacks.
* **Parry:** tap block at the precise moment an attack would land. Every attack can be parried, and each parry does a consistent amount of posture damage. Parrying doesn't open the parrier to damage; it lets them act first with a light or heavy attack, which the opponent can in turn parry. The parrier then decides which attack or movement option gives them the advantage.
* **Parry presentation (update):** parries should be cinematic. The two weapons visibly bounce off each other, as in Sekiro, with a flashy "clang" effect and sound.
* **Block:** shields HP from blockable attacks, and reduces, but doesn't remove, posture damage.
* **Counters** answer the unblockable attacks, which are slow and telegraphed. Dodge invincibility doesn't work against them.
  * **Thrusts** must be dodged *into* to stomp on the thrusting weapon (like Sekiro's mikiri counter). The attacker is stunned and open to a string of attacks.
  * **Sweeps** (horizontal attacks at the feet) must be jumped over; the fighter leaps off the opponent for good posture damage.
  * **Overhead slams** are countered by back-dashing. The counter looks like a quick back dash that can instantly be followed by a special light attack that dashes you to the opponent while they recover.
* **Disarmed:** a disarmed fighter can't parry or block. Parry is replaced by the timed redirect counter, which deals high posture damage and stuns.
* **Not in this game (update):** no directional guard (block is a single hold, not For Honor's stance directions), and no combo breaker (there is no way to break out of a string once it connects; defense happens before the hit lands).

### Posture Meter (Posture System)

* Fighters take posture damage when they block, when they fail to defend an attack, and when their attacks are parried or countered. Blocking reduces posture damage and protects HP. Failing to defend deals more HP damage, plus the same posture damage as having an attack parried. Counters deal more posture damage.
* A fighter whose posture meter is full is disarmed when one of their attacks is parried, or when they try to block an unblockable attack, a fully charged power attack or an ultimate. The disarming blow does no HP damage.
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
* **Medium weapons:** katana, longsword & buckler, staff.
* **Small weapons:** twin daggers, bladed whip.

### Movesets (update)

* **Katana:** focused on slashes.
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
* **Arena themes:** Moonlit Shrine (from the demo), fantasy coliseum, hell and ice, each reimagined as a floating dark fantasy, oriental arena. The original list's Cyberpunk Grid, Deep Space Nebula, Synthwave Sunset and Retro Vector are dropped because they clash with the art direction.

### Progression & Customization

* **Cosmetics:** unlockable fighter skins earned through fighter proficiency, by performing fighter-specific feats.

---

## 5. Visuals, Audio, & UI/UX

### Art Style & Presentation

* **Visual style:** gritty dark fantasy, ancient oriental. **(update)** Rendered as stylized toon with outlines, ink-wash and painterly touches.
* **UI layout:** a minimalist HUD with HP bars in classic fighting-game style and the posture bar underneath. Ultimate access is shown by a glowing aura around the fighter when they are at 25% HP or less.

### Animation (update)

* Attacks should feel weighty, both when they land and when the attack begins.
* Fighters behave realistically:
  * Running fighters lean forward.
  * Dodges look evasive.
  * Each fighter moves according to their weapon. Colossal weapons are heavy and look it, and swinging one pulls the fighter along with its momentum.
* Strings flow naturally; a swing that ends on the right continues from the right.
* Unblockable attacks have longer range and a visible effect showing their reach.
* Hitboxes should be as tight to the weapon as possible.

### Sound Design

* **SFX:**
  * Weapon clangs when weapons make contact, and a satisfying metal clang unique to parries.
  * Slicing-flesh sounds when blades connect.
  * Bone and rock crushing noises when colossal weapons land.
  * **(update)** Each fighter's movement has its own sound, such as the Skeleton Knight's rattling bones.
* **Music (update):** dark fantasy and ancient oriental instruments, combined with electronic and metal.
  * Match music: 130–150 BPM, fast-paced, high-energy, upbeat battle themes, themed around each stage.
  * Final-round ("match point") themes: 150–170+ BPM.
  * Character select, menus and loading screens: 100–120 BPM, slower and groovier, an electric and oriental-funk fusion.

### Assets (update)

* Asset budget: to be determined.
* Assets must be easy to swap as new files and downloaded packs become available.
* Current sources:
  * Quaternius characters, outfits, animations and weapons (CC0).
  * The Sonniss GDC 2026 game audio bundle (royalty-free).

### Controls

* Players can map custom controls on individual player profiles, for keyboard and mouse and for controller.
