"""R191 microphone self-test without a person: play a 1 kHz tone on the speakers while recording,
then compare the 1 kHz energy (Goertzel) with a silent recording. Usage: python3 ... A.wav B.wav"""
import math, struct, sys, wave

def level(path, freq):
    w = wave.open(path)
    n, ch, rate = w.getnframes(), w.getnchannels(), w.getframerate()
    raw = w.readframes(n)
    data = struct.unpack('<%dh' % (len(raw) // 2), raw)
    out = []
    for c in range(ch):
        x = data[c::ch][rate // 2:]           # skip the first 0.5 s
        k = 2 * math.cos(2 * math.pi * freq / rate)
        s1 = s2 = 0.0
        for v in x:
            s1, s2 = v + k * s1 - s2, s1
        p = s1 * s1 + s2 * s2 - k * s1 * s2
        rms = math.sqrt(sum(v * v for v in x) / max(len(x), 1))
        out.append((10 * math.log10(p / len(x) + 1e-9), rms))
    return out

tone, quiet = level(sys.argv[1], 1000), level(sys.argv[2], 1000)
for c, (t, q) in enumerate(zip(tone, quiet)):
    print(f'channel {c}: 1 kHz {t[0]:.1f} dB (tone) vs {q[0]:.1f} dB (quiet), rms {t[1]:.0f} vs {q[1]:.0f}, delta {t[0]-q[0]:+.1f} dB')
