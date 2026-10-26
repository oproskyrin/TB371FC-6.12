"""R162 test tone: 48 kHz S16 stereo WAV, 440 Hz at -40 dBFS in one channel only, 2 s with
200 ms fade in/out. Usage: py r162-make-tone.py out.wav left|right [dbfs]"""
import math, struct, sys, wave
out, ch = sys.argv[1], sys.argv[2]
db = float(sys.argv[3]) if len(sys.argv) > 3 else -40.0
rate, dur, fade = 48000, 2.0, 0.2
amp = 32767 * 10 ** (db / 20)
n = int(rate * dur)
with wave.open(out, 'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(rate)
    frames = bytearray()
    for i in range(n):
        t = i / rate
        g = min(1.0, t / fade, (dur - t) / fade)
        v = int(amp * g * math.sin(2 * math.pi * 440 * t))
        frames += struct.pack('<hh', v if ch == 'left' else 0, v if ch == 'right' else 0)
    w.writeframes(bytes(frames))
print(out, ch, db, 'dBFS peak', round(amp))
