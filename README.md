# RETRO-REFLECTOR
**3D First-Person Light-Bounce Horror (Godot 4)**

> *"The main roof shutter jammed open during the solar eclipse, and the primary laser is still firing into the dark. Shut down the capacitors and get out."*

---

## Overview

**RETRO-REFLECTOR** is a 3D first-person sci-fi cosmic horror game built for Godot 4.
You play as **Leo**, an optics technician sent to shut down the **Mount Hale Lunar Observatory**—a decommissioned 1970s mountaintop facility that used high-powered lasers bounced off retroreflector arrays on the Moon.

During a solar eclipse tonight, a rogue test triggered an anomaly: the telescope array locked onto something in deep space (the Perseus Void), and something followed the beam down into the dark facility. Pitch-black shadow silhouettes roam the corridors—entities that absorb raw, unreflected light, and can only be banished by a **reflected beam**.

---

## Core Mechanics ("Bounce Back")

1. **The Handheld Alignment Laser**:
   - Shining the laser directly at shadow entities does **not** harm them—they absorb raw, direct light, agitate, glitch, and stalk faster towards you.
2. **The Retro-Reflector Mirrors**:
   - Harming or banishing an entity requires hitting it with a **reflected** beam (`bounce_count >= 1`).
   - Bounce beams off angled wall mirrors, metallic surfaces, or portable tripod mirrors you deploy.
   - Reflected light causes blinding static disintegration, burning away their silhouettes in an optical scream.
3. **Emitter Overheating & Darkness**:
   - Holding the laser continuously fills the heat gauge (~4.5s of fire).
   - Reaching 100% heat causes an **Overheat Lockout**: an emergency 3-second cooldown in total pitch-black darkness while shadow footsteps close in.
4. **Portable Mirrors**:
   - Pick up portable tripod reflectors (`RMB` or `Q`) and deploy them in hallways or doorways to create custom bounce angles.

---

## Storyline Progression (The 3 Acts)

- **Act I: The Control Room (Tutorial & Setup)**:
  - Supervisor Chen radios in through walkie-talkie static with your orders.
  - Discover the creepy astronomer's Polaroid on the desk (showing a shadow entity lurking behind his shoulder in the wall mirror).
  - Pick up the Handheld Alignment Laser from the workbench.
  - Solve the optical security sensor puzzle: bounce the beam off a tilted 45° wall mirror around an alcove partition to unlock the magnetic gallery door.
- **Act II: The Mirror Gallery (Escalation)**:
  - Winding, dark circular corridors lined with calibration mirrors and dusty optical benches.
  - Shadow entities stalk the halls. Lure them into mirror sightlines and ricochet beams into their blind spots.
  - Locate Breaker Rooms 1 & 2 to engage the two capacitor levers and listen to astronomer audio tapes detailing the deep-space void anomaly.
  - Engaging both capacitors unlocks the blast door to the Telescope Dome.
- **Act III: The Dome & The Alignment (Finale)**:
  - Massive circular telescope dome with the giant primary laser shooting a pillar of light up into the night sky through an open roof shutter.
  - Three shadow entities guard the central shutdown console.
  - Rotate the three giant telescope mirror stations (Station Alpha, Beta, Gamma) to form a complete triangular cage of reflected light across the dome floor.
  - The reflected light triangle sweeps the room, disintegrating the entities.
  - Sprint to the central console and pull the emergency manual shutdown lever: the primary beam dies down, heavy roof shutters seal shut, and emergency amber lights flicker on.
  - Walk down the exit corridor to the mountain exit—passing a dark glass display case with a final, eerie reflection...

---

## Controls

| Action | Key / Button |
|---|---|
| **Move** | `W`, `A`, `S`, `D` / Arrow Keys |
| **Look** | Mouse |
| **Fire Laser** | `Left Mouse Button` / `Space` |
| **Place Portable Mirror** | `Right Mouse Button` / `Q` |
| **Interact / Pick Up / Rotate** | `E` / `F` |
| **Sprint** | `Shift` |
| **Jump** | `Space` |
| **Pause / Settings** | `Escape` |
| **Quick Respawn Checkpoint** | `R` |

---

## Technical Details

- **Engine**: Godot Engine 4.x (Tested on Godot 4.7.2 Forward+).
- **Physics Raycast Reflection**: Dynamic vector reflection math (`dir.bounce(normal)`), raycast layers, and dynamic segment cylinders with unshaded shaders.
- **Audio**: Custom-generated 16-bit 44.1kHz sound effects for laser hums, switch clicks, mirror harmonics, pneumatic doors, entity stalking, and dark ambient mountaintop drone.
- **Shaders**:
  - `laser_beam.gdshader`: Unshaded additive glow with pulsating core.
  - `shadow_entity.gdshader`: Void jitter, unreflected light absorption flash, and static dissolve banish.
  - `crt_postprocess.gdshader`: 1970s CRT scanlines, vignette, chromatic aberration, and film static (toggleable in pause menu).

---

## How to Run

### In Godot Editor:
1. Open Godot 4.
2. Import or open `/home/koundinyag/Projects/LH1`.
3. Press `F5` (or click Play) to launch `res://scenes/main.tscn`.

### From Terminal:
```bash
godot res://scenes/main.tscn
```

### Automated Gameplay Verification Suite:
```bash
godot --headless tests/test_runner.tscn
```
All 7 unit and gameplay loop tests verify clean pass on mechanics!
