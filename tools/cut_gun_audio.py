"""Cuts the guns' sounds out of the recordings they come from.

    blender --background --python tools/cut_gun_audio.py -- <folder of the original recordings>

Not needed to run the game: audio/guns/ already holds what this writes. It is
kept so that the cuts can be made again, or changed. The originals are not in
the project; audio/guns/CREDITS.md says where each came from. The names here
are: the BigSoundBank sound number ("1367.flac"); "fs_<number>.mp3", the
preview of that Freesound sound; "ffsl_<name>.wav", that file of the Free
Firearm Sound Library ("Prepared SFX Library"); "oga_...", from OpenGameArt.

Each sound is one stretch of one recording, brought to mono at 44.1 kHz and
16 bits (through a windowed-sinc low-pass, so that nothing above the new rate
folds down into it), with the rumble under 25 Hz taken off, a 1.5 ms fade in
and a fade out, and brought to the level its kind is given below. What that
level measures is in HOW: for most kinds it is the peak; for the shots it is
the RMS over the first tenth of a second (so that the takes of one gun are as
loud as each other), with the crack then rounded off under 0.89 by a soft
limiter (the recordings are of the kind where the first millisecond is far
above the rest, and most were clipped there already: the count is printed).
A shot starts 3 ms before its onset, so that it sounds on the frame it is fired.
"""
import os
import struct
import sys

import numpy as np

RAW = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio", "guns")
RATE = 44100
CEILING = 0.89

# kind: (level to bring it to (see HOW), [(recording, from, to), ...])
CUTS = {
    # A snub .38 revolver and a .45 pistol from 20-odd metres in the open, and a .357 Magnum
    "shot_revolver": (0.22, [("ffsl_V_22P.wav", 0.6702, 2.12), ("ffsl_A_34P.wav", 6.6522, 8.10), ("0438.mp3", 0.0104, 1.40)]),
    # Bolt-action rifles of the Great War, in the open: a US Model 1917 (.30-06), a Mosin-Nagant, an Arisaka
    "shot_rifle": (0.22, [("ffsl_B_16P.wav", 5.9690, 7.77), ("ffsl_M_26P.wav", 1.1347, 2.73), ("ffsl_E_18P.wav", 4.4836, 6.10)]),
    # 12-bores: a Mossberg and a Benelli in the open, and one at a clay shoot with its echo over the plain
    "shot_shotgun": (0.22, [("ffsl_N_26P.wav", 0.7833, 2.30), ("ffsl_O_17P.wav", 0.6909, 2.20), ("2853.flac", 0.0139, 1.19)]),
    # A flare being fired, and a flare gun
    "shot_flare": (0.18, [("fs_450837.mp3", 0.0511, 1.20), ("fs_675636.mp3", 3.4723, 4.50)]),
    # A bolt-action rifle's bolt worked, twice
    "cycle_bolt": (0.60, [("fs_675628.mp3", 0.177, 0.96), ("fs_675628.mp3", 2.335, 2.97)]),
    # An old revolver cocked; a pistol's hammer drawn back
    "cock": (0.60, [("fs_111676.mp3", 0.063, 0.30), ("1992.flac", 0.0819, 0.21)]),
    # A revolver's hammer falling on nothing
    "dry": (0.55, [("fs_540066.mp3", 0.047, 0.24), ("fs_540066.mp3", 1.039, 1.23), ("fs_540066.mp3", 2.1035, 2.40)]),
    # A revolver broken open, and a break-action shotgun opened; and each shut
    "break_open": (0.60, [("fs_722902.mp3", 0.037, 0.32), ("fs_52202.mp3", 0.3743, 0.62)]),
    "break_close": (0.60, [("fs_722902.mp3", 2.259, 2.56), ("fs_52202.mp3", 8.272, 8.55)]),
    # One cartridge pushed home
    "round_in": (0.50, [("oga_singlebullet1.wav", 0.041, 0.30), ("fs_675957.mp3", 4.065, 4.33), ("fs_675957.mp3", 15.131, 15.42)]),
    # A spent 7.62 mm case landing on concrete
    "shell": (0.55, [("1367.flac", 0.0675, 0.70), ("1368.flac", 0.059, 0.80), ("1369.flac", 0.0537, 0.62), ("1371.flac", 0.037, 0.80)]),
    # Rifle ricochets
    "ricochet": (0.75, [("fs_675955.mp3", 0.1875, 1.20), ("fs_675955.mp3", 3.6127, 4.65), ("fs_675955.mp3", 5.1887, 6.20),
                        ("fs_675955.mp3", 8.182, 9.00)]),
    # Stones of a kilo or more landing on a pile of stone, and a rock thrown into dirt
    "impact_stone": (0.80, [("1022.flac", 16.550, 16.95), ("1022.flac", 4.6485, 5.00), ("fs_319222.mp3", 0.284, 0.70)]),
    # Rocks thrown at wood
    "impact_wood": (0.80, [("fs_319226.mp3", 0.170, 0.384), ("fs_319227.mp3", 0.0666, 0.40), ("fs_319228.mp3", 0.0908, 0.267)]),
    # A ceramic pot smashed, clay pottery dropped on concrete, a plate dropped on concrete
    "break_pot": (0.85, [("fs_810043.mp3", 0.764, 1.70), ("fs_399080.mp3", 8.8215, 9.80), ("1643.flac", 0.0644, 1.20)]),
    # Glass bottles smashed on a hard floor
    "break_glass": (0.85, [("fs_450780.mp3", 0.3016, 1.40), ("fs_212698.mp3", 0.5086, 1.30)]),
    # A road flare burning (a steady stretch, its end crossfaded into its start so that it loops)
    "flare_burn": (0.10, [("fs_348766.mp3", 3.20, 5.95)]),
    # A box rattled and set down
    "pickup": (0.60, [("fs_580872.mp3", 0.049, 0.50)]),
}

# kind: (what its level is a measure of, seconds of fade out). Kinds not here: ("peak", 0.03)
HOW = {
    "shot_revolver": ("rms100", 0.15), "shot_rifle": ("rms100", 0.15), "shot_shotgun": ("rms100", 0.15),
    "shot_flare": ("rms100", 0.12),
    "ricochet": ("peak", 0.10), "break_pot": ("peak", 0.10), "break_glass": ("peak", 0.10), "shell": ("peak", 0.06),
    "flare_burn": ("loop", 0.25),
}


def load(path):
    """(rate, samples as rows of channels, each -1 to 1)"""
    if path.lower().endswith(".wav"):
        with open(path, "rb") as f:
            blob = f.read()
        position, form, data = 12, None, b""
        while position + 8 <= len(blob):
            name, size = blob[position:position + 4], struct.unpack("<I", blob[position + 4:position + 8])[0]
            if name == b"fmt ":
                form = list(struct.unpack("<HHIIHH", blob[position + 8:position + 24]))
                if form[0] == 0xFFFE:  # WAVE_FORMAT_EXTENSIBLE: the true format is further in
                    form[0] = struct.unpack("<H", blob[position + 32:position + 34])[0]
            elif name == b"data":
                data = blob[position + 8:position + 8 + size]
            position += 8 + size + (size & 1)
        kind, channels, rate, bits = form[0], form[1], form[2], form[5]
        data = data[:len(data) // (bits // 8 * channels) * (bits // 8 * channels)]
        if kind == 3:
            samples = np.frombuffer(data, dtype="<f4").astype(np.float64)
        elif bits == 16:
            samples = np.frombuffer(data, dtype="<i2") / 32768.0
        elif bits == 24:
            a = np.frombuffer(data, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
            samples = a[:, 0] | (a[:, 1] << 8) | (a[:, 2] << 16)
            samples = np.where(samples >= 1 << 23, samples - (1 << 24), samples) / float(1 << 23)
        else:
            samples = np.frombuffer(data, dtype="<i4") / float(1 << 31)
        return rate, samples.reshape(-1, channels)
    import aud
    sound = aud.Sound.file(path)
    samples = np.array(sound.data(), dtype=np.float64)
    return int(sound.specs[0]), samples.reshape(len(samples), -1)


def resampled(rate, data):
    """To RATE through a Kaiser-windowed sinc, which is the low-pass and the interpolation in one."""
    if rate == RATE:
        return data.copy()
    ratio = RATE / float(rate)
    cutoff = 0.5 * min(ratio, 1.0) * 0.92          # in cycles per sample of the original: 20.3 kHz
    half = int(np.ceil(32.0 / min(ratio, 1.0)))    # the kernel's half width, in samples of the original
    padded = np.concatenate([np.zeros(half + 1), data, np.zeros(half + 2)])
    count = int(len(data) * ratio)
    offsets = np.arange(-half, half + 1)
    out = np.empty(count)
    for start in range(0, count, 16384):
        at = np.arange(start, min(start + 16384, count)) / ratio
        whole = np.floor(at).astype(np.int64)
        t = (at - whole)[:, None] - offsets[None, :]
        window = np.i0(9.0 * np.sqrt(np.clip(1.0 - (t / (half + 1.0)) ** 2, 0.0, 1.0))) / np.i0(9.0)
        kernel = 2.0 * cutoff * np.sinc(2.0 * cutoff * t) * window
        kernel /= kernel.sum(axis=1, keepdims=True)
        out[start:start + len(at)] = (padded[whole[:, None] + offsets[None, :] + half + 1] * kernel).sum(axis=1)
    return out


def without_rumble(data, below=25.0):
    """A one-pole high-pass (causal, so it puts nothing before an onset), done in the spectrum."""
    count = len(data)
    spectrum = np.fft.rfft(data, 2 * count)
    f = np.fft.rfftfreq(2 * count, 1.0 / RATE)
    return np.fft.irfft(spectrum * (1j * f) / (1j * f + below), 2 * count)[:count]


def soft_limited(data, knee=0.45):
    """Leaves everything under the knee alone and bends what is above it over, never past CEILING."""
    size = np.abs(data)
    over = size > knee
    out = data.copy()
    out[over] = np.sign(data[over]) * (knee + (CEILING - knee) * np.tanh((size[over] - knee) / (CEILING - knee)))
    return out


def onset(data):
    """The first sample above a tenth of the peak."""
    return int(np.nonzero(np.abs(data) > 0.1 * np.abs(data).max())[0][0])


def rms100(data):
    """RMS over the tenth of a second from the onset."""
    first = onset(data)
    return float(np.sqrt((data[first:first + RATE // 10] ** 2).mean()))


def loud_rms(data):
    """RMS over the part of it that is sounding: the hundredths of a second above a tenth of its peak."""
    hop = RATE // 100
    frames = max(len(data) // hop, 1)
    power = (data[:frames * hop].reshape(frames, -1) ** 2).mean(axis=1)
    keep = power > power.max() * 0.01
    return float(np.sqrt(power[keep].mean()))


def centroid(data):
    """The middle of its spectrum over the 0.3 s from the onset: low for a boom, high for a crack."""
    first = onset(data)
    piece = data[first:first + int(0.3 * RATE)]
    power = np.abs(np.fft.rfft(piece * np.hanning(len(piece)))) ** 2
    return float((power * np.fft.rfftfreq(len(piece), 1.0 / RATE)).sum() / max(power.sum(), 1e-20))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    recordings = {}
    margin = 0.02
    for kind, (level, cuts) in CUTS.items():
        measure, fade_seconds = HOW.get(kind, ("peak", 0.03))
        for index, (source, start, end) in enumerate(cuts):
            if source not in recordings:
                recordings[source] = load(os.path.join(RAW, source))
            rate, whole = recordings[source]
            first, last = int(round(start * rate)), min(int(round(end * rate)), len(whole))
            clipped = int((np.abs(whole[first:last]) >= 0.999).sum())
            # (a little more than the stretch at each end, for the filters to settle in, cut off again after them)
            before = min(int(margin * rate), first)
            piece = resampled(rate, whole[first - before:min(last + int(margin * rate), len(whole))].mean(axis=1))
            piece = without_rumble(piece - piece.mean())
            skip = int(round(before * RATE / float(rate)))
            piece = piece[skip:skip + int(round((last - first) * RATE / float(rate)))]
            if measure == "loop":
                # The last stretch faded out over the first faded in (equal power): the end then runs on into the start
                cross = int(RATE * fade_seconds)
                ramp = np.linspace(0.0, 1.0, cross)
                head = piece[:cross] * np.sqrt(ramp) + piece[-cross:] * np.sqrt(1.0 - ramp)
                piece = np.concatenate([head, piece[cross:-cross]])
                gain = level / max(loud_rms(piece), 1e-6)
                piece = soft_limited(piece * gain)
            else:
                fade_in = min(int(RATE * 0.0015), len(piece) // 4)
                fade_out = min(int(RATE * fade_seconds), len(piece) // 3)
                piece[:fade_in] *= np.linspace(0.0, 1.0, fade_in)
                piece[-fade_out:] *= np.linspace(1.0, 0.0, fade_out)
                if measure == "rms100":
                    # (twice over: the limiter takes a little off the first try)
                    gain = level / max(rms100(piece), 1e-6)
                    gain *= level / max(rms100(soft_limited(piece * gain)), 1e-6)
                    piece = soft_limited(piece * gain)
                else:
                    gain = level / np.abs(piece).max()
                    piece = piece * gain
            # (never so loud that it clips)
            piece = piece * min(1.0, CEILING / np.abs(piece).max())
            name = "%s_%d.wav" % (kind, index + 1)
            frames = (np.clip(piece, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
            with open(os.path.join(OUT, name), "wb") as f:
                f.write(b"RIFF" + struct.pack("<I", 36 + len(frames)) + b"WAVEfmt " +
                        struct.pack("<IHHIIHH", 16, 1, 1, RATE, RATE * 2, 2, 16) + b"data" + struct.pack("<I", len(frames)))
                f.write(frames)
            print("CUT %-18s %5.3fs peak=%.2f rms=%.3f rms100=%.3f onset=%4.1fms centroid=%5.0fHz gain=%6.2f clipped-in-source=%-4d from %s %.4f-%.4f" % (
                name, len(piece) / float(RATE), np.abs(piece).max(), loud_rms(piece), rms100(piece),
                1000.0 * onset(piece) / RATE, centroid(piece), gain, clipped, source, start, end))
