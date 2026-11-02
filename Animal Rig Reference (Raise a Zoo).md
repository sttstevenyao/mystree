---
tags: [mystree, creatures, reference]
---
# Animal rig reference: Raise a Zoo (2026-10-31)

The owner likes how Raise a Zoo's animals (place "pen", 124917330991360; source in `CreaturePens/src`) move, how their joints connect and their body shapes. Mystree copies those qualities in its own smoother wedge-triangle style. Raise a Zoo itself is studded and lower poly, so copy the rig and the motion, not the look.

Sources:
- `CreaturePens/src/ReplicatedStorage/CreaturePens/Builders.lua` (B): the bodies and `jointify` (B:6915-7290).
- `AnimalAnims.lua` (AA): poses and gaits.
- `StarterPlayer/.../CreaturePensClient/AnimalAnimator.lua` (AN): the per-frame driver.

## Joint hierarchy (quadruped)
- **Hips**: Root → Body, pivot at the barrel centre. Everything else hangs off Body, so the whole torso can bob, roll, pitch and twist.
- **Neck and HeadTilt**:
  - Neck: Body → NeckBase, at the top-front of the chest.
  - HeadTilt: NeckBase → Head, at the head's bottom-back (the poll). The head stays level while the neck pumps: HeadTilt = -neckPitch × 0.85 + look.
- **Jaw**: Head → Jaw, hinged at the jaw's back-top edge.
- **Legs**:
  - Leg: Body → Leg, at the top of the leg. Attributes `Side` ±1 and `Front` -1/+1.
  - Then Knee → Hock → ToeJoint → Ankle (paw/hoof).
  - Ball knobs on each joint ride the child segment and hide the seam when it bends.
- **Tail**: Body → Tail, then a `TailSeg` chain of 4-5 tapering segments, each hinged at its near end.
- **Strands**: manes, ruffs and tail hair are 3-segment hinged chains (Motor6D "Strand" with Kind/Index/Seg).
  - The unicorn mane has 3 layers of 9/11/9 strands.
  - Each strand has its own twist and S-curl, so no two are coplanar.
- **Joint frames**: aligned with the model (X right, Y up, -Z forward), so every bend is `CFrame.Angles(a, 0, 0)`.

## Body proportions (B numbers; scale to Mystree size)
- **Body**: 3 overlapping segments (chest 33% / middle 36% / hips 31% of length), each two crossed boxes for an octagonal section. Gives a deep chest, narrower waist and full rump. Per-species width/height scales, e.g. Horse F{1.02,1.06} M{.96,.96} B{1.02,1.0}.
- **Leg joint heights** (`LEG_SHAPE`, fractions of leg length):
  - Hoof: wrist .44, hock .56, stifle .10 forward, hock-back .13.
  - Paw: wrist .20, hock .36.
- **Leg length**: horse 1.58 × body height, fox 1.24 ×.
- **Leg width**: about 0.26 × body width, the lower bone tapered to 0.78.
- **Thigh and shoulder masses**: front 0.36×0.66×0.54, hind 0.42×0.82×0.68 (horse).

## Motion (formulas with file:line in the subagent report, 2026-10-31)
- **Speed and stride**:
  - Speed is measured from root movement and eased (dt·8).
  - walk = clamp(speed/2.5) and idle = 1 - walk scale every term.
  - **No-skate stride**: θ = asin(speed·stance/(2·legHeight)), so feet don't slide. Short legs step faster (StepRateNeed).
- **Leg cycle**:
  - Stance: sweep 1 → -1. Swing: smoothstep, with lift = sin(wπ).
  - Footfalls: walk LH 0, LF .25, RH .5, RF .75. Trot shifts the fronts +.25 and is blended by speed, not switched.
  - Fold: front elbow +.3f and wrist -1.25f; hind stifle -.7f and hock +1.0f (f = knee·lift·walk).
- **Body**:
  - Bob is highest when the planted legs are vertical (it vaults over them).
  - Roll leans toward the planted side.
  - At idle the body breathes: lift sin(2t+Seed)·.035, pitch sin(1.4t+Seed)·.015.
- **Head**:
  - Look = sin(.45t+3Seed)·sin(.17t+Seed). Two slow sines multiplied give irregular glances and pauses.
  - Neck nods twice per stride.
- **Tail**:
  - Root wag sin(TailPhase)·(.2+.15walk). Big animals wag slower (/scale^.75).
  - The chain wave lags .75 per segment and streams back at a run.
- **Hair**: two clocks, lag 1.25 per segment, amplitude 1.4/2.4/3.2 down the strand. Manes stream back and down when running.
- **Feet on the floor**: forward kinematics finds the lowest foot each frame, and the Hips are moved so planted feet never float or sink.
- **Gallop**:
  - Horse 4-beat: HL 0, HR .1, FL .32, FR .42, stance .58.
  - Other animals use a wolf bound.
- **Attacks and emotes**: blended with an Envelope (smooth in and out). The jaw eases at dt·14.
- **Desync**: a random Seed per animal keeps them from moving in sync.
- **LOD**: off-screen animals are skipped, and beyond 220 studs they are posed at 20 Hz. Each rig is posed in a pcall.
- **Not in Raise a Zoo**: turn banking, ear flicks and blinking. Possible Mystree extras.

## Raise a Zoo species that match Mystree creatures
Qilin, Kitsune (nine-tailed fox), Tiger, Lion, Panda, Fenrir (wolf), Dragon, Thunderbird, Crocodile, Gorilla, Polar Bear, Horse, Fae Stag, Phoenix, Titanoboa.

Their Qilin reads as a real qilin:
- a cream body covered in jade scale plates;
- two long swept-back black horns and a dragon-like head with whiskers;
- a long white mane and a flowing tail plume (swaying strands);
- white fur at the fetlocks.
