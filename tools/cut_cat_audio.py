"""Cuts the cat's voice out of the recordings it comes from.

    blender --background --python tools/cut_cat_audio.py -- <folder of the original recordings>

Not needed to run the game: audio/cat/ already holds what this writes. It is
kept so that the cuts can be made again, or changed. The originals are not in
the project; audio/cat/CREDITS.md says where each came from (the names here
are the BigSoundBank sound numbers, each saved as <number>.wav, and the one
Wikimedia Commons file as commons_cat_hissing_zabuhailo.wav).

Each sound is one stretch of one recording, faded in and out, brought to mono
at 32 kHz and 16 bits, and brought to the loudness its kind is given below, so
that no file is far louder than the rest. (The same way as the hounds':
tools/cut_hound_audio.py.)

The stretches were found by measuring, not by ear: the loudness of each
recording every 20 ms gives where each sound starts and stops; a trill is told
from a meow by its roll (its loudness beating about 30 times a second, where a
meow holds a steady note), a hiss by having no note at all; and each purr runs
from one turn of the breath to another, two breaths in and two out, so that
any of them follows any other without a jump.
"""
import os
import sys
import wave

import numpy as np

RAW = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio", "cat")
RATE = 32000

# kind: (loudness to bring it to (RMS over its loud part), [(recording, from, to), ...])
CUTS = {
    # Single meows: four small mews of a cat asking to be let through a door, two of another cat
    # (the second of them in two syllables), and two of a third (Emi) asking for attention
    "meow": (0.16, [("0098.wav", 0.09, 0.72), ("0098.wav", 1.04, 1.76), ("0098.wav", 2.14, 2.68), ("0098.wav", 3.20, 3.86),
                    ("1896.wav", 0.62, 1.80), ("1895.wav", 0.00, 0.90), ("1477.wav", 0.02, 0.88), ("1480.wav", 0.04, 0.90)]),
    # Steady purring, each from one turn of the breath to another: one cat twice, and a louder one
    "purr": (0.05, [("1010.wav", 41.78, 45.02), ("1010.wav", 87.82, 90.66), ("0981.wav", 118.26, 121.42)]),
    # Hisses: a spit and a long hiss, and three shorter ones ("feulement", in the recordist's French)
    "hiss": (0.14, [("commons_cat_hissing_zabuhailo.wav", 0.90, 2.06), ("1881.wav", None, None), ("1882.wav", None, None),
                    ("1883.wav", None, None)]),
    # Rolled little calls ("mrrp") of a cat (Emi) asking for attention
    "trill": (0.12, [("1472.wav", 0.06, 0.80), ("1473.wav", 0.04, 0.88), ("1475.wav", 0.06, 0.78)]),
    # A low growl, a complaining growl, and the drawn-out moan of a cat that has seen an enemy cat
    "growl": (0.14, [("1886.wav", 0.12, 2.80), ("0658.wav", 10.90, 12.70), ("0903.wav", 10.38, 12.74)]),
}

# kind: (seconds of fade in, of fade out); the rest are faded as the hounds' barks are
FADES = {"purr": (0.15, 0.25), "growl": (0.02, 0.10)}


def load(path):
    if path.endswith(".wav"):
        with wave.open(path, "rb") as w:
            rate, width, channels, count = w.getframerate(), w.getsampwidth(), w.getnchannels(), w.getnframes()
            raw = w.readframes(count)
        if width == 3:
            a = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
            data = (a[:, 0] | (a[:, 1] << 8) | (a[:, 2] << 16))
            data = np.where(data >= 1 << 23, data - (1 << 24), data) / float(1 << 23)
        else:
            data = np.frombuffer(raw, dtype=np.int16) / 32768.0
        return rate, data.reshape(-1, channels).mean(axis=1)
    import aud
    sound = aud.Sound.file(path)
    data = np.array(sound.data(), dtype=np.float64)
    return int(sound.specs[0]), data.reshape(len(data), -1).mean(axis=1)


def resampled(rate, data):
    if rate == RATE:
        return data
    # (a short running mean first, so that nothing above the new rate folds down into it)
    width = max(int(round(rate / RATE)), 1)
    if width > 1:
        data = np.convolve(data, np.ones(width) / width, mode="same")
    count = int(len(data) * RATE / rate)
    # (the positions as floats: as whole numbers they are 32 bits wide on Windows, and count * rate
    # passes that 1.4 s into a 48 kHz recording, after which every sample came out as the first one)
    return np.interp(np.arange(count, dtype=np.float64) * rate / RATE, np.arange(len(data)), data)


def loud_rms(data):
    """RMS over the part of it that is sounding: the hundredths of a second above a tenth of its peak."""
    hop = RATE // 100
    frames = max(len(data) // hop, 1)
    power = (data[:frames * hop].reshape(frames, -1) ** 2).mean(axis=1)
    keep = power > power.max() * 0.01
    return float(np.sqrt(power[keep].mean()))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    recordings = {}
    for kind, (level, cuts) in CUTS.items():
        for index, (source, start, end) in enumerate(cuts):
            if source not in recordings:
                recordings[source] = load(os.path.join(RAW, source))
            rate, whole = recordings[source]
            piece = whole[int((start or 0.0) * rate):int(end * rate) if end else len(whole)]
            clipped = int((np.abs(piece) >= 0.999).sum())
            piece = resampled(rate, piece)
            piece = piece - piece.mean()
            # Trim the silence off each end of a whole recording
            if start is None:
                loud = np.nonzero(np.abs(piece) > np.abs(piece).max() * 0.03)[0]
                piece = piece[max(loud[0] - RATE // 50, 0):loud[-1] + RATE // 20]
            seconds_in, seconds_out = FADES.get(kind, (0.004, 0.04))
            fade_in = min(int(RATE * seconds_in), len(piece) // 4)
            fade_out = min(int(RATE * seconds_out), len(piece) // 3)
            piece[:fade_in] *= np.linspace(0.0, 1.0, fade_in)
            piece[-fade_out:] *= np.linspace(1.0, 0.0, fade_out)
            gain = level / max(loud_rms(piece), 1e-6)
            # (never so loud that it clips)
            gain = min(gain, 0.89 / np.abs(piece).max())
            piece = piece * gain
            name = "%s_%d.wav" % (kind, index + 1)
            with wave.open(os.path.join(OUT, name), "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(RATE)
                w.writeframes((np.clip(piece, -1.0, 1.0) * 32767.0).astype("<i2").tobytes())
            print("CUT %-16s %5.2fs peak=%.2f rms=%.3f gain=%5.2f clipped-in-source=%d  from %s %s" % (
                name, len(piece) / RATE, np.abs(piece).max(), loud_rms(piece), gain, clipped, source,
                "" if start is None else "%.2f-%.2f" % (start, end)))
