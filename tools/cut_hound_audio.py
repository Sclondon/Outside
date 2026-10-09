"""Cuts the hounds' voices out of the recordings they come from.

    blender --background --python tools/cut_hound_audio.py -- <folder of the original recordings>

Not needed to run the game: audio/hounds/ already holds what this writes. It is
kept so that the cuts can be made again, or changed. The originals are not in
the project; audio/hounds/CREDITS.md says where each came from (the names here
are the BigSoundBank sound numbers, and the other files as they were saved).

Each sound is one stretch of one recording, faded in and out, brought to mono
at 32 kHz and 16 bits, and brought to the loudness its kind is given below, so
that no file is far louder than the rest.
"""
import os
import sys
import wave

import numpy as np

RAW = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio", "hounds")
RATE = 32000

# kind: (loudness to bring it to (RMS over its loud part), [(recording, from, to), ...])
CUTS = {
    # Deep single barks: a sled dog, outdoors
    "bark_deep": (0.20, [("2954.wav", 0.03, 0.27), ("2954.wav", 0.37, 0.62), ("2954.wav", 2.42, 2.67), ("2954.wav", 2.81, 3.06),
                         ("2954.wav", 5.03, 5.26), ("2954.wav", 15.02, 15.26), ("2955.wav", 0.01, 0.72)]),
    # Sharper ones: an old dog, and a dog indoors
    "bark_sharp": (0.20, [("2353.wav", 0.00, 0.26), ("2353.wav", 0.68, 0.96), ("2353.wav", 1.54, 1.83), ("2353.wav", 2.02, 2.29),
                          ("2353.wav", 3.04, 3.31), ("2353.wav", 4.23, 4.50), ("0112.wav", 2.02, 2.36), ("0112.wav", 4.62, 4.96)]),
    # A small dog's yap, for play
    "yap": (0.16, [("0612.wav", 9.27, 9.52), ("0612.wav", 13.23, 13.50), ("0612.wav", 18.84, 19.12), ("0612.wav", 44.67, 44.95),
                   ("0682.wav", 0.68, 1.12)]),
    # Howls: one dog "singing", a pack of sled dogs, and a small dog
    "bay": (0.16, [("2451.wav", 0.02, 2.30), ("2953.wav", 18.30, 20.90), ("2953.wav", 13.85, 16.66), ("2953.wav", 1.02, 3.60),
                   ("jem_howls.ogg", 0.0, 3.3)]),
    "whine": (0.10, [("2450.wav", 0.06, 1.74)]),
    "growl": (0.12, [("oga_growl.ogg", None, None), ("plos_growl7.ogg", None, None), ("plos_growl6.ogg", None, None)]),
    "pant": (0.05, [("1547.wav", 1.0, 3.0), ("1547.wav", 6.0, 8.0), ("1547.wav", 10.0, 12.0)]),
    # A bark with a growl in it, and a burst of barks, for when it has him
    "snap": (0.20, [("1060.wav", 0.24, 0.80), ("1060.wav", 23.21, 23.47), ("2354.wav", 0.00, 1.00)]),
}


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
    # (in 64-bit floats: counted in 32-bit integers, as numpy does on Windows, this overflows 1.4 s in)
    return np.interp(np.arange(count, dtype=np.float64) * rate / RATE, np.arange(len(data), dtype=np.float64), data)


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
            fade_in = min(int(RATE * (0.004 if kind != "pant" else 0.15)), len(piece) // 4)
            fade_out = min(int(RATE * (0.04 if kind not in ("pant", "bay") else 0.25)), len(piece) // 3)
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
