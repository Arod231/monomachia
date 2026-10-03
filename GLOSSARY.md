# Monomachia

A one-on-one weapon duel: two fighters, first to win three rounds. These are the words the design docs, specs and code use for its concepts.

## People and loadouts

**Fighter**:
One of the eight selectable characters (Fantasy Knight, Samurai, Orc, Rogue, Aristocrat, Hunter, Monk, Skeleton Knight). A fighter brings a body, a personality, an intro and a bare-hand style, but not a weapon.
_Avoid_: Character (except in the screen name "Character Select"), hero, champion

**Weapon**:
One of the nine weapons a fighter can wield. The weapon owns the armed moveset, the parry window and the ultimate.
_Avoid_: Class, style

**Weapon class**:
The size group a weapon belongs to: small, medium or colossal. It sets how fast and heavy the weapon feels.
_Avoid_: Weight, tier

**Loadout**:
The weapon and its two chosen block abilities, one on light and one on heavy, picked before a match.
_Avoid_: Build, kit

**Signature weapon**:
The weapon a fighter is offered by default at character select.

**Palette**:
One of a fighter's two colour schemes. In a mirror match the second fighter wears the other one, so the two can be told apart.
_Avoid_: Skin, costume

## Attacking

**Light attack** / **Heavy attack**:
The two attack buttons' moves: quick pressure, or slow and powerful.

**Charged heavy**:
A heavy attack held before release. At 2.5 seconds it releases by itself as a **power attack**.

**Iai Slash**:
The Katana's heavy attack, a quick-draw. Pressing heavy sheathes the blade; holding heavy keeps it sheathed, in the **stance**, which is the Katana's charged heavy; letting go draws one long-reaching cut, vertical, or horizontal if the stick is held left or right.

**String**:
A sequence of attacks that flow into one another when the player keeps pressing.
_Avoid_: Combo (outside the phrase "combo breaker"), chain

**Follow-up**:
An optional next attack that a specific attack flows into. The player may take it or not.

**Movement attack**:
An attack whose shape depends on the movement before it: out of a sprint, a dodge, a backstep or a jump.

**Block ability**:
One of the two moves a player triggers by holding block and pressing light or heavy.

**Unblockable**:
A slow, telegraphed thrust, sweep or overhead slam. Blocking it doesn't stop it, and dodge invincibility doesn't avoid it; each one has its own **counter**.

**Ultimate**:
The once-per-round signature move a fighter can use at 25% HP or less.

## Hits

**Swing**:
The path a move's weapon travels through the move, in the fighter's own space: the grip, the blade and the body's coil, frame by frame. It is baked from the move's clip, so the same motion decides hits and is seen on screen.
_Avoid_: Animation (for the path itself), hitbox

**Clip**:
An authored animation a fighter plays, such as an attack, a damage reaction or a walk. Clips are fitted to the rules' frames and never decide anything themselves.
_Avoid_: Animation (when the swing is meant), mocap

**Hurt capsule**:
The capsule around a fighter's body, from the feet up, that a swing must touch to hit them. It rises with the fighter in a jump.
_Avoid_: Hurtbox, hitbox

**Strike segment**:
What a swing strikes with, as a line with a thickness: a weapon's blade, from where its cutting part starts to its point; a bare fist, across the knuckles; or a foot, along the sole from heel to toe.
_Avoid_: Hitbox

**Sweep**:
The surface a blade (or another strike segment) covers from one frame to the next. A hit lands on the first active frame whose sweep touches the defender's hurt capsule. Not the low sweep attack that the leap counters: say "blade sweep" where the two could be confused.

**Contact point**:
Where a sweep first touches the hurt capsule: on the first frame it touches, the point where the blade went deepest, nearest the capsule's axis. Hit, block and parry effects start there.

## Defending

**Block**:
Holding the block button to protect HP from blockable attacks; posture still fills.

**Parry**:
Tapping block just before an attack lands, so the weapons bounce off each other.
_Avoid_: Deflect (as a separate mechanic), guard break

**Dodge**:
Pressing dodge with a direction: a **roll** that way, invincible to normal attacks for its first frames. Pressing dodge with no direction is a **backstep**, a quick hop away from the opponent.
_Avoid_: Dash (for the dodge), evade (that's a counter)

**Knockdown**:
Being knocked to the ground by an unblockable, a fully charged heavy or a colossal slam. The downed fighter can't be hit, and stands up on a fixed timer, able to block or parry as they rise.
_Avoid_: Knockback (the push every hit gives), launch

**Shouldered**:
A Greatsword resting on its fighter's shoulder, as it does at the round intro and after moving for a moment. An attack started shouldered is slower, because the sword has to be heaved off first.

**Counter**:
The specific answer to an unblockable: **stomp** (dodge into a thrust), **leap** (jump over a sweep) or **evade** (back-dash from a slam, then lunge).

**Redirect**:
A disarmed fighter's timed hand counter, which replaces the parry.

**Flash**:
The katana's block ability: a parry stance with a wide window that stuns.

## Posture and disarm

**Posture**:
The meter under HP that fills under pressure. A full meter is the danger state.
_Avoid_: Stamina, guard meter

**Disarm**:
What happens to a fighter whose posture is full when they are parried, or when they block a power attack, an unblockable or an ultimate: the weapon flies away.

**Bare hands**:
Fighting while disarmed, with the fighter's own hand-to-hand moves.
_Avoid_: Unarmed mode, fists mode

## Matches

**Round** / **Match**:
A round ends when a fighter's HP reaches zero; a match is won by the first fighter to win three rounds.

**Arena**:
The walled, floating stage a match is fought on.
_Avoid_: Map, level

**Lock in**:
Confirming a fighter and loadout at character select.

**Gate**:
The giant oriental portal a fighter walks through after locking in, and out of at the match intro.
_Avoid_: Portal (in docs)

**Match intro**:
The skippable sequence before the first round in which each fighter walks out of their gate and performs their intro.
