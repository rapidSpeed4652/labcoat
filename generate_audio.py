import wave
import struct
import math
import random
import os

SAMPLE_RATE = 44100

def write_wav(filename, samples, sample_rate=SAMPLE_RATE):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'w') as wav:
        wav.setnchannels(1) # mono
        wav.setsampwidth(2) # 16-bit
        wav.setframerate(sample_rate)
        
        # Normalize and convert to int16
        max_val = max(abs(s) for s in samples) if samples else 1.0
        if max_val == 0: max_val = 1.0
        scale = 30000.0 / max(1.0, max_val)
        
        raw_bytes = bytearray()
        for s in samples:
            val = int(max(-32767, min(32767, s * scale)))
            raw_bytes.extend(struct.pack('<h', val))
        wav.writeframes(raw_bytes)
    print(f"Generated {filename}")

def gen_laser_hum():
    # 2.0s loopable hum with high pitched laser harmonics and subtle warble
    duration = 2.0
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # fundamental 440Hz + 880Hz + 1320Hz + 2640Hz + sub 110Hz
        mod = 1.0 + 0.15 * math.sin(2 * math.pi * 8 * t)
        s = 0.4 * math.sin(2 * math.pi * 440 * t)
        s += 0.3 * math.sin(2 * math.pi * 880 * t)
        s += 0.2 * math.sin(2 * math.pi * 1760 * t * mod)
        s += 0.15 * math.sin(2 * math.pi * 3520 * t)
        s += 0.25 * math.sin(2 * math.pi * 110 * t)
        # White noise hiss
        s += 0.05 * (random.random() * 2.0 - 1.0)
        samples.append(s)
    # Smooth loop edges
    fade = int(SAMPLE_RATE * 0.05)
    for i in range(fade):
        factor = i / fade
        samples[i] = samples[i] * factor + samples[n - fade + i] * (1.0 - factor)
    return samples

def gen_laser_click():
    # Crisp vintage switch click
    duration = 0.08
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 60)
        s = (random.random() * 2 - 1) * 0.7 + 0.3 * math.sin(2 * math.pi * 1800 * t)
        samples.append(s * env)
    return samples

def gen_laser_overheat():
    # Sizzling steam vent and failing power buzz
    duration = 1.8
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 2.2)
        # Steam hiss: filtered noise
        hiss = (random.random() * 2 - 1) * 0.6
        # Downward pitch drop buzz
        freq = max(60, 480 - t * 300)
        buzz = 0.4 * math.sin(2 * math.pi * freq * t)
        samples.append((hiss + buzz) * env)
    return samples

def gen_laser_cooldown():
    # Retro ready beep (double beep)
    duration = 0.35
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        s = 0.0
        if 0.0 <= t < 0.12:
            s = math.sin(2 * math.pi * 1200 * t) * math.exp(-(t % 0.12) * 20)
        elif 0.15 <= t < 0.28:
            t2 = t - 0.15
            s = math.sin(2 * math.pi * 1600 * t2) * math.exp(-t2 * 20)
        samples.append(s * 0.5)
    return samples

def gen_mirror_reflect():
    # Resonant harmonic glass / crystal ping
    duration = 0.8
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 6.0)
        s = 0.5 * math.sin(2 * math.pi * 2093 * t) # C7
        s += 0.3 * math.sin(2 * math.pi * 3136 * t) # G7
        s += 0.2 * math.sin(2 * math.pi * 4186 * t) # C8
        samples.append(s * env)
    return samples

def gen_entity_stalk():
    # Low eerie rhythmic breath / void drone (3.0s loopable)
    duration = 3.0
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Deep pulsing sub 45Hz + 67Hz
        pulse = 0.5 + 0.5 * math.sin(2 * math.pi * 1.2 * t)
        sub = math.sin(2 * math.pi * 55 * t) * pulse * 0.5
        sub += math.sin(2 * math.pi * 73 * (t + 0.2)) * 0.3
        # Eerie breath noise
        noise = (random.random() * 2 - 1) * 0.15 * pulse
        samples.append(sub + noise)
    return samples

def gen_entity_absorb():
    # Agitated distortion glitch / screech when hit by raw beam
    duration = 0.6
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 3.0)
        freq = 220 + 80 * math.sin(2 * math.pi * 45 * t)
        s = math.sin(2 * math.pi * freq * t)
        # Glitch ring mod
        s = (1.0 if s > 0 else -1.0) * 0.4
        noise = (random.random() * 2 - 1) * 0.4
        samples.append((s + noise) * env)
    return samples

def gen_entity_banish():
    # Intense optical burn, rising static scream into crystalline vaporization
    duration = 1.4
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = 1.0 - (t / duration)
        # Rising resonance
        freq = 300 + 1200 * (t / duration)
        sine = math.sin(2 * math.pi * freq * t) * 0.3
        sparkle = math.sin(2 * math.pi * (freq * 2.5) * t) * 0.2
        noise = (random.random() * 2 - 1) * 0.5 * (1.0 - t / duration)
        samples.append((sine + sparkle + noise) * env)
    return samples

def gen_door_open():
    # Pneumatic air hiss followed by heavy metallic clunk
    duration = 1.2
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        s = 0.0
        # Hiss in first 0.6s
        if t < 0.7:
            hiss_env = (1.0 - t / 0.7)
            s += (random.random() * 2 - 1) * 0.4 * hiss_env
        # Metallic clunk around 0.5s
        if 0.45 <= t < 0.9:
            t2 = t - 0.45
            clunk_env = math.exp(-t2 * 12)
            s += math.sin(2 * math.pi * 120 * t2) * 0.6 * clunk_env
            s += math.sin(2 * math.pi * 280 * t2) * 0.3 * clunk_env
        samples.append(s)
    return samples

def gen_switch_flip():
    # Heavy breaker switch
    duration = 0.25
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 25)
        s = math.sin(2 * math.pi * 90 * t) * 0.5 + (random.random() * 2 - 1) * 0.5
        samples.append(s * env)
    return samples

def gen_radio_static():
    # Walkie-talkie squelch with static burst and retro radio tone
    duration = 0.4
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 8)
        beep = math.sin(2 * math.pi * 1750 * t) * 0.3
        squelch = (random.random() * 2 - 1) * 0.5
        samples.append((beep + squelch) * env)
    return samples

def gen_ambient_drone():
    # Cold observatory wind + deep low hum (4.0s loopable)
    duration = 4.0
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Sub 50Hz and 75Hz
        sub = 0.3 * math.sin(2 * math.pi * 50 * t) + 0.15 * math.sin(2 * math.pi * 75 * t)
        # Gentle wind noise
        wind_mod = 0.6 + 0.4 * math.sin(2 * math.pi * 0.5 * t)
        wind = (random.random() * 2 - 1) * 0.08 * wind_mod
        # Eerie high overtone
        whistle = 0.04 * math.sin(2 * math.pi * 880 * t + 0.5 * math.sin(2 * math.pi * 0.25 * t))
        samples.append(sub + wind + whistle)
    # Loop fade
    fade = int(SAMPLE_RATE * 0.1)
    for i in range(fade):
        factor = i / fade
        samples[i] = samples[i] * factor + samples[n - fade + i] * (1.0 - factor)
    return samples

def gen_footstep():
    # Boot step on metal grating
    duration = 0.15
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 35)
        s = math.sin(2 * math.pi * 110 * t) * 0.5 + (random.random() * 2 - 1) * 0.3
        samples.append(s * env)
    return samples

def gen_dome_alarm():
    # Pulsing emergency alarm tone
    duration = 1.0
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 600 + 200 * math.sin(2 * math.pi * 2 * t)
        s = math.sin(2 * math.pi * freq * t) * 0.4
        samples.append(s)
    return samples

def gen_shutter_close():
    # Massive heavy gears and mechanical thud
    duration = 2.5
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = 1.0 - (t / duration)
        grind = (random.random() * 2 - 1) * 0.3 * (0.8 + 0.2 * math.sin(2 * math.pi * 14 * t))
        motor = math.sin(2 * math.pi * 85 * t) * 0.4
        thud = 0.0
        if 1.8 <= t < 2.4:
            t2 = t - 1.8
            thud = math.sin(2 * math.pi * 50 * t2) * math.exp(-t2 * 6) * 0.8
        samples.append((grind + motor + thud) * env)
    return samples

def gen_interact():
    # Clean UI / item pickup beep
    duration = 0.15
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 20)
        s = math.sin(2 * math.pi * 880 * t) * 0.4
        samples.append(s * env)
    return samples

AUDIO_DIR = "/home/koundinyag/Projects/LH1/assets/audio"

sounds = {
    "laser_hum.wav": gen_laser_hum(),
    "laser_click.wav": gen_laser_click(),
    "laser_overheat.wav": gen_laser_overheat(),
    "laser_cooldown.wav": gen_laser_cooldown(),
    "mirror_reflect.wav": gen_mirror_reflect(),
    "entity_stalk.wav": gen_entity_stalk(),
    "entity_absorb.wav": gen_entity_absorb(),
    "entity_banish.wav": gen_entity_banish(),
    "door_open.wav": gen_door_open(),
    "switch_flip.wav": gen_switch_flip(),
    "radio_static.wav": gen_radio_static(),
    "ambient_drone.wav": gen_ambient_drone(),
    "footstep.wav": gen_footstep(),
    "dome_alarm.wav": gen_dome_alarm(),
    "shutter_close.wav": gen_shutter_close(),
    "interact.wav": gen_interact(),
}

for fname, s in sounds.items():
    write_wav(os.path.join(AUDIO_DIR, fname), s)

print("All audio files generated successfully!")
