"""Cuts the hyena's voice out of the recordings it comes from.

    blender --background --python tools/cut_hyena_audio.py -- <folder of the original recordings>

Not needed to run the game: audio/hyenas/ already holds what this writes. It is
kept so that the cuts can be made again, or changed. The originals are not in
the project; audio/hyenas/CREDITS.md says where they came from. In the folder
they are looked for as `giggle_S1.oga` to `giggle_S8.oga` (Additional files 1
to 8 of Mathevon et al. 2010) and `bl_hyaena.ogg` (the British Library's).

Each sound is one stretch of one recording, faded in and out, brought to mono
at 32 kHz and 16 bits, and brought to the loudness its kind is given below.
(The same way as the hounds', whose tools this uses: tools/cut_hound_audio.py.)

The giggles are each a whole recording, a second long. The whoops are the three
stretches of the one long recording in which a hyena calls: measured every
quarter of a second, it is loudest from 15.25 s to 17.75 s, and there are two
fainter calls, further off, at 1.25 s and at 11 s.
"""
import os
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cut_hound_audio as cutter  # noqa: E402  (load, resampled, loud_rms)

RAW = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio", "hyenas")
RATE = cutter.RATE

# kind: (loudness to bring it to (RMS over its loud part), seconds of fade in and out, [(recording, from, to), ...])
CUTS = {
    # The cackle: when it rushes in, when it breaks off, and when it is driven away
    "giggle": (0.15, 0.01, 0.06, [("giggle_S%d.oga" % n, 0.0, 1.02) for n in range(1, 9)]),
    # The long call, from a way off
    "whoop": (0.13, 0.15, 0.35, [("bl_hyaena.ogg", 15.25, 17.85), ("bl_hyaena.ogg", 1.2, 3.3), ("bl_hyaena.ogg", 10.9, 13.0)]),
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
            # (never so loud that it clips; and a faint recording is not brought up so far that it is all hiss)
            gain = min(gain, 0.89 / np.abs(piece).max(), 12.0)
            piece = piece * gain
            name = "%s_%d.wav" % (kind, index + 1)
            with wave.open(os.path.join(OUT, name), "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(RATE)
                w.writeframes((np.clip(piece, -1.0, 1.0) * 32767.0).astype("<i2").tobytes())
            print("CUT %-12s %5.2fs peak=%.2f rms=%.3f gain=%5.2f  from %s %.2f-%.2f" % (
                name, len(piece) / RATE, np.abs(piece).max(), cutter.loud_rms(piece), gain, source, start, end))
