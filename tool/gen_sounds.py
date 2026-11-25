import math, os, struct, wave

SR = 44100

def make(path, notes, vol=0.5):
    total = max(s + d for f, d, s in notes)
    n = int(SR * (total + 0.02))
    buf = [0.0] * n
    for f, d, s in notes:
        i0 = int(SR * s)
        for i in range(int(SR * d)):
            t = i / SR
            env = math.exp(-t * (6.0 / d)) * min(1.0, i / (SR * 0.004))
            v = math.sin(2 * math.pi * f * t) + 0.3 * math.sin(4 * math.pi * f * t)
            buf[i0 + i] += v * env
    peak = max(1e-9, max(abs(x) for x in buf))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(x / peak * vol * 32767)) for x in buf))

os.makedirs("assets/sounds", exist_ok=True)
make("assets/sounds/tap.wav", [(1200, 0.05, 0.0)], 0.35)
make("assets/sounds/pop.wav", [(660, 0.09, 0.0), (990, 0.12, 0.05)], 0.45)
make("assets/sounds/success.wav", [(784, 0.12, 0.0), (988, 0.12, 0.08), (1318, 0.3, 0.16)], 0.5)
print("ok")
