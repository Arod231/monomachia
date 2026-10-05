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
One of a fighter's two colour schemes, worn by side (crimson for one, indigo for the other), so the two fighters can be told apart.
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

**Recall**:
The disarmed ultimate's re-arm: a power-up whose burst returns the weapon to the fighter's hands and blasts a nearby opponent away and down.
_Avoid_: Summon, pick-up (that is pulling the dropped weapon out of the ground)

## Hits

**Swing**:
The path a move's weapon travels through the move, in the fighter's own space: the grip, the blade and the body's coil, frame by frame. It is baked from the move's clip, so the same motion decides hits and is seen on screen.
_Avoid_: Animation (for the path itself), hitbox

**Clip**:
An authored animation a fighter plays, such as an attack, a damage reaction or a walk. An attack's clip sets the move's frame data and footwork: the rules follow the clip.
_Avoid_: Animation (when the swing is meant), mocap

**Frame data**:
A move's startup, active and recovery, counted in the rules' frames (60 a second).
_Avoid_: Timing (on its own), speed

**Timing band**:
The range of frame data an attack is allowed, set by design. An attack's clip is edited until it lands inside its band.
_Avoid_: Window (that's the parry's), target frames

**Move kind**:
The row of the timing and distance band tables a move belongs to, such as a string light, a string heavy, an Iai follow-up or a sprint heavy. A move has one kind wherever it is played from.
_Avoid_: Slot (that's where a move is played from), move type (that's slash, thrust, sweep and the rest)

**Distance band**:
The range of duelling distances a weapon's attacks must connect from, set by design. A clip that falls short is re-keyed, never slid.

**Marker**:
A named frame on a clip that the frame data are generated from: the active frames' start and end, the dodge-cancel window, a branch point, a foot plant or lift, and on some clips a ready or kill frame. Markers are set on the Animation Studio's timeline.
_Avoid_: Keyframe (that's an animation key), tag

**Branch point**:
A marker on an attack's clip where the body can plausibly break off into a follow-up. The follow-up starts there instead of waiting for the attack to end. Dodge cancels open at markers of their own.
_Avoid_: Cancel frame (for the follow-up's start), chain point

**Inertial blending**:
How one motion hands over to the next: the new clip starts at once, and what is left of the old pose fades out over a few frames. It changes only the picture.
_Avoid_: Crossfade (that was the fixed-length blend it replaces)

**Transition clip**:
A short authored clip that bridges two motions, such as a return to guard, a bridge between the hits of a string, a run stop or a pivot. It plays on top of inertial blending, so the hand-off looks keyed rather than computed.
_Avoid_: Blend (that's the computed part)

**Physical reaction layer**:
A picture-only layer on the spine, head and arms that pushes the pose from where and how hard a hit landed, so no two hits look alike. The rules never read it.
_Avoid_: Ragdoll, physics (on their own)

**Protected timing**:
A defensive timing the rules set and every clip that shows it must fit: the parry window, the input buffer, the dodge and backstep, hitstun, blockstun, hit-stop and the knockdown phases, and also the stuns the counters buy, the disarm's stagger and the disarmed fighter's daze, and the parry recoil.
_Avoid_: Fixed frames, hard-coded timing

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

**Deflect pair**:
The matched motions of a parry: the parrier's deflect and the attacker's recoil, one pair per attack direction, with the two blades meeting at the contact point.

**Knockdown**:
Being knocked to the ground by an unblockable, a fully charged heavy or a colossal slam. The downed fighter can't be hit, and stands up on a fixed timer, able to block or parry as they rise.
_Avoid_: Knockback (the push every hit gives), launch

**Shouldered**:
A Greatsword resting on its fighter's shoulder, as it does at the round intro and after moving for a moment. An attack started shouldered is slower, because the sword has to be heaved off first.

**Counter**:
The specific answer to an unblockable: **stomp** (dodge into a thrust), **leap** (jump over a sweep) or **evade** (back-dash from a slam, then lunge).

**Paired clip**:
A two-fighter clip played by both fighters at once, lined up so their bodies meet: the counters, the Impaler and the finishers.

**Redirect**:
A disarmed fighter's timed hand counter, which replaces the parry.

**Flash**:
The katana's block ability: a parry stance with a wide window that stuns.

## Posture and disarm

**Posture**:
The meter under HP that fills under pressure. A full meter is the danger state.
_Avoid_: Stamina, guard meter

**Disarm**:
What happens to a fighter whose posture is full when they are parried, or when they block a power attack, an unblockable or an ultimate: the weapon flies off the way it was knocked and sticks in the ground.

**Bare hands**:
Fighting while disarmed, with the fighter's own hand-to-hand moves.
_Avoid_: Unarmed mode, fists mode

**Finisher**:
A weapon's cinematic killing move, open to the fighter who disarms an opponent at 5% HP or less: one timed press during the slow motion plays it and ends the round.
_Avoid_: Execution, fatality; calling a string's last hit a finisher

## Matches

**Round** / **Match**:
A round ends when a fighter's HP reaches zero or they are finished; a match is won by the first fighter to win three rounds.

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

**Warrior Slain**:
The call for every KO that ends a round, finishers included, shown with the brushed kanji 討死 ("fallen in battle"). A double KO keeps its own call.
_Avoid_: K.O. (the old call), ippon

**Cinematic shot**:
An authored camera shot, with its own path, lens and camera effects, that takes over from the gameplay camera for a moment: an ultimate once it connects, a finisher, the KO that wins the match. A **push-in** is smaller: the gameplay camera moves briefly closer, as on a parry, a Flash, a redirect or an ultimate's wind-up.
_Avoid_: Cutscene, replay

**Blood setting**:
The player's choice of On (blood on hits, and a finisher can cut the opponent apart), Reduced (finishers show the cut with less blood and the body stays whole) or Off (no blood). It changes only the picture.
_Avoid_: Gore setting, violence filter

## Making the game

**Milestone**:
A sign-off point where the owner plays the work so far and judges it against the quality bar. Bringing the existing content to final quality has two.
_Avoid_: Gate (that's the portal), checkpoint

**Move family**:
A group of moves and the clips that go with them (their deflect pairs, reactions, sounds and effects) brought to final quality together and reviewed by the owner as one, such as the Katana's light string. The first one, which proves the pipeline and the bar, is the **pilot family**.
_Avoid_: Batch, move set (that's a weapon's whole list)

**Mood board**:
The page of reference images, colours, a UI page and notes the owner approves before anything converts to the realistic look.

**Look test**:
The test scene, one fighter with the Katana in a corner of the Moonlit Shrine at Ultra on the RTX 3090, that settles the look, the lighting and the camera effects after the mood board and before the art converts.
_Avoid_: Vertical slice, demo scene

**Balance run**:
A long run of computer-against-computer matches whose numbers (round length, disarms, finishers, which moves appear) must come out inside a milestone's targets.
_Avoid_: Soak (that's the tool that plays it; a soak can also just check for failures)

**Stand-in**:
A labelled placeholder (a CC0 clip, a code-built model) that a clone or CI build without the asset repository plays in place of the real asset.
_Avoid_: Fallback (outside code), dummy (that's Training's opponent)

**Procedural pose**:
A pose made in code rather than played from a clip, such as the demo's stick poses, the swing player, the weapon-hold idles and the demo swings, which posed the weapon in space before every state had a clip. Milestone 1 retires them.
_Avoid_: Stand-in (that's a labelled placeholder asset)

**Reference preset**:
The graphics preset every look is judged at: Ultra, on an RTX 3090.

**Asset repository**:
The private repository of paid and large source art (and Blender files) that the game's import tools read. The public repository never holds paid art.
_Avoid_: Asset store (that's Unity's shop), asset pack

## Tools

**Animation Studio**:
The dev tool for looking at animations and setting their markers: a gallery of every animation, a timeline with each move's frame data against its timing band, the markers, and the chains of clips a move plays. Saving regenerates the frame data. Bone posing happens in Blender.
