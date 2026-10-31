"""Original synthwave loop for the Year in Review story (no samples, no third-party audio).

Usage: python3 year_in_review_music.py loop.wav  (see scripts/README.md for the AAC step)
"""
import math, random, struct, sys, wave

SR = 44100
BPM = 100
BEAT = 60 / BPM
BARS = 8
LOOP = BARS * 4 * BEAT
N = int(round(LOOP * SR))
TOTAL = 2 * N  # render twice; keep the second pass so tails wrap seamlessly
random.seed(7)

def hz(m):
    return 440 * 2 ** ((m - 69) / 12)

A2, F2, C3, G2 = 45, 41, 48, 43
chords = [  # midi notes, one chord per bar
    [57, 60, 64], [53, 57, 60], [55, 60, 64], [55, 59, 62],
]
roots = [A2, F2, C3 - 12, G2]

kick = [0.0] * TOTAL
drums = [0.0] * TOTAL
bass = [0.0] * TOTAL
pad = [0.0] * TOTAL
arp = [0.0] * TOTAL

def idx(t):
    return int(t * SR)

# Kick: four on the floor
for b in range(2 * BARS * 4):
    s = idx(b * BEAT)
    phase = 0.0
    for i in range(int(0.35 * SR)):
        if s + i >= TOTAL: break
        t = i / SR
        f = 48 + 110 * math.exp(-t * 28)
        phase += 2 * math.pi * f / SR
        kick[s + i] += math.sin(phase) * math.exp(-t * 7) * 0.95 + (0.25 * math.exp(-t * 400) if i < 200 else 0)

# Clap on 2 and 4, hats on the offbeats (open-ish) + 16th ghost hats
def noise_hit(start, length, decay, gain, hp=True):
    lp = 0.0
    for i in range(int(length * SR)):
        if start + i >= TOTAL: break
        x = random.uniform(-1, 1)
        lp += 0.35 * (x - lp)
        y = x - lp if hp else lp
        drums[start + i] += y * math.exp(-i / SR * decay) * gain

for b in range(2 * BARS * 4):
    t0 = b * BEAT
    if b % 2 == 1:
        for k, off in enumerate((0, 0.011, 0.022)):
            noise_hit(idx(t0 + off), 0.25, 22 if k == 2 else 90, 0.45)
    noise_hit(idx(t0 + BEAT / 2), 0.12, 30, 0.22)
    for q in (1, 3):
        noise_hit(idx(t0 + q * BEAT / 4), 0.04, 90, 0.08)

# Bass: driving 8ths on the root, plucky
for bar in range(2 * BARS):
    r = hz(roots[bar % 4])
    for e in range(8):
        s = idx((bar * 4 + e / 2) * BEAT)
        ph = 0.0
        lp = 0.0
        L = int(BEAT / 2 * SR * 0.92)
        for i in range(L):
            if s + i >= TOTAL: break
            t = i / SR
            ph = (ph + r / SR) % 1.0
            saw = 2 * ph - 1
            cut = 0.04 + 0.18 * math.exp(-t * 18)
            lp += cut * (saw - lp)
            env = min(1, i / 60) * (0.55 + 0.45 * math.exp(-t * 10)) * min(1, (L - i) / 200)
            bass[s + i] += (lp * 0.7 + 0.5 * math.sin(2 * math.pi * r * t)) * env * 0.55

# Pad: detuned saws per chord, slow attack
for bar in range(2 * BARS):
    notes = chords[bar % 4]
    s = idx(bar * 4 * BEAT)
    L = int(4 * BEAT * SR)
    phases = [random.random() for _ in range(len(notes) * 2)]
    freqs = []
    for n in notes:
        freqs += [hz(n) * 2 ** (7 / 1200), hz(n) * 2 ** (-7 / 1200)]
    lp = 0.0
    for i in range(L + int(0.3 * SR)):
        if s + i >= TOTAL: break
        v = 0.0
        for k, f in enumerate(freqs):
            phases[k] = (phases[k] + f / SR) % 1.0
            v += 2 * phases[k] - 1
        v /= len(freqs)
        lp += 0.09 * (v - lp)
        t = i / SR
        env = min(1, t / 0.08) * (1 if i < L else math.exp(-(i - L) / SR * 15))
        pad[s + i] += lp * env * 0.55

# Arp: 16ths over chord tones, second half of the loop only
pattern = [0, 1, 2, 3, 2, 1, 0, 2]
for bar in range(2 * BARS):
    if bar % BARS < 4: continue
    notes = chords[bar % 4]
    tones = [notes[0] + 12, notes[1] + 12, notes[2] + 12, notes[0] + 24]
    for q in range(16):
        f = hz(tones[pattern[q % 8]])
        s = idx((bar * 4 + q / 4) * BEAT)
        ph = 0.0
        lp = 0.0
        for i in range(int(0.22 * SR)):
            if s + i >= TOTAL: break
            t = i / SR
            ph = (ph + f / SR) % 1.0
            sq = 1.0 if ph < 0.5 else -1.0
            lp += 0.22 * (sq - lp)
            arp[s + i] += lp * math.exp(-t * 14) * min(1, i / 40) * 0.22

# Arp echo (dotted 8th), circular so it wraps over the loop point
d = idx(BEAT * 0.75)
for i in range(TOTAL):
    arp[i] += 0.38 * arp[i - d] if i >= d else 0

# Sidechain on pad + bass from the kick grid
out = []
for i in range(N, TOTAL):
    t = (i / SR) % BEAT
    duck = 1 - 0.65 * math.exp(-t / 0.11)
    x = kick[i] * 0.9 + drums[i] * 0.8 + (bass[i] * 0.9 + pad[i] * 0.9) * duck + arp[i]
    out.append(math.tanh(x * 0.9))
peak = max(abs(v) for v in out)
g = 0.89 / peak
with wave.open(sys.argv[1], 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(b''.join(struct.pack('<h', int(v * g * 32767)) for v in out))
print('ok', LOOP, 's')
