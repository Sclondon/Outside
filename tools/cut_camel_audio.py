"""Cuts the camel's voice out of the recordings it comes from.

    blender --background --python tools/cut_camel_audio.py -- <folder of the original recordings>

Not needed to run the game: audio/camels/ already holds what this writes. It is
kept so that the cuts can be made again, or changed. The originals are not in
the project; audio/camels/CREDITS.md says where they came from (camel_01.flac
and camel_02.flac, as they are named in the archive they come in).

Each sound is one stretch of one recording, faded in and out, brought to mono
at 32 kHz and 16 bits, and brought to the loudness its kind is given below.
(The same way as the hounds', whose tools this uses: tools/cut_hound_audio.py.)

There are only two recordings, both of one long groan, loud from end to end
(measured every tenth of a second, neither falls quiet anywhere in it). So the
groans are those two, the longer of them also in two halves; and the grunts are
short stretches of them, faded quickly in and slowly out.
"""
import os
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cut_hound_audio as cutter  # noqa: E402  (load, resampled, loud_rms)

RAW = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio", "camels")
RATE = cutter.RATE

# kind: (loudness to bring it to (RMS over its loud part), seconds of fade in and out, [(recording, from, to), ...])
CUTS = {
    # The long complaint: at being made to kneel or to get up, or at nothing
    "groan": (0.16, 0.05, 0.45, [("camel_01.flac", 0.05, 3.30), ("camel_02.flac", 0.0, 3.70), ("camel_02.flac", 3.90, 7.80)]),
    # A shorter one
    "grunt": (0.13, 0.04, 0.30, [("camel_01.flac", 0.10, 1.00), ("camel_02.flac", 5.10, 6.00), ("camel_02.flac", 0.95, 1.75)]),
}


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    recordings = {}
    for kind, (level, fade_in, fade_out, cuts) in CUTS.items():
        for index, (source, start, end) in enumerate(cuts):
            if source not in recordings:
                recordings[source] = cutter.load(os.path.join(RAW, source))
            rate, whole = recordings[source]
            piece = cutter.resampled(rate, whole[int(start * rate):int(end * rate)])
            piece = piece - piece.mean()
            rise = min(int(RATE * fade_in), len(piece) // 4)
            fall = min(int(RATE * fade_out), len(piece) // 2)
            piece[:rise] *= np.linspace(0.0, 1.0, rise)
            piece[-fall:] *= np.linspace(1.0, 0.0, fall)
            gain = level / max(cutter.loud_rms(piece), 1e-6)
            # (never so loud that it clips)
            gain = min(gain, 0.89 / np.abs(piece).max())
            piece = piece * gain
            name = "%s_%d.wav" % (kind, index + 1)
            with wave.open(os.path.join(OUT, name), "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(RATE)
                w.writeframes((np.clip(piece, -1.0, 1.0) * 32767.0).astype("<i2").tobytes())
            print("CUT %-12s %5.2fs peak=%.2f rms=%.3f gain=%5.2f  from %s %.2f-%.2f" % (
                name, len(piece) / RATE, np.abs(piece).max(), cutter.loud_rms(piece), gain, source, start, end))
