#!/usr/bin/env python3
"""Generates the bundled binary assets that ship with Jhanda Burja.

Everything here is synthesised from scratch with the Python standard library
plus Pillow, so the build has no network dependency and no licensing questions.
Re-run after tweaking to regenerate assets/ in place:

    python3 tools/generate_assets.py

Sound effects are deliberately short and mono so the whole audio set costs well
under a megabyte in the APK.
"""

import math
import os
import random
import struct
import wave

from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FELT_DIR = os.path.join(ROOT, "assets", "felt")
AUDIO_DIR = os.path.join(ROOT, "assets", "audio")

SAMPLE_RATE = 22050
RNG = random.Random(20260927)  # fixed seed: assets are reproducible


# --------------------------------------------------------------------- felt
def generate_felt(path, size=1024):
    """A dark green casino felt: low-frequency mottling plus fine fibre noise.

    Stretched to fill the screen rather than tiled, so it needs no seam
    wrapping. Smoothing keeps it soft when upscaled on large displays.
    """
    base = (18, 74, 48)

    # Coarse mottling, upscaled with bicubic to get broad cloudy variation.
    coarse = Image.new("L", (size // 16, size // 16))
    coarse.putdata([RNG.randint(0, 255) for _ in range(coarse.width * coarse.height)])
    coarse = coarse.resize((size, size), Image.BICUBIC)
    coarse = coarse.filter(ImageFilter.GaussianBlur(12))

    # Fine fibre speckle.
    fine = Image.new("L", (size, size))
    fine.putdata([RNG.randint(0, 255) for _ in range(size * size)])
    fine = fine.filter(ImageFilter.GaussianBlur(0.4))

    r, g, b = base
    pixels = []
    coarse_px = coarse.load()
    fine_px = fine.load()
    for y in range(size):
        for x in range(size):
            c = (coarse_px[x, y] - 128) / 128.0 * 26.0
            f = (fine_px[x, y] - 128) / 128.0 * 9.0
            d = c + f
            pixels.append(
                (
                    max(0, min(255, int(r + d * 0.55))),
                    max(0, min(255, int(g + d))),
                    max(0, min(255, int(b + d * 0.7))),
                )
            )

    felt = Image.new("RGB", (size, size))
    felt.putdata(pixels)
    felt.save(path, optimize=True)
    print(f"  felt      {size}x{size} -> {os.path.relpath(path, ROOT)}")


# -------------------------------------------------------------------- audio
def _write_wav(path, samples):
    frames = b"".join(
        struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples
    )
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(frames)
    print(
        f"  {os.path.splitext(os.path.basename(path))[0]:10} "
        f"{len(samples) / SAMPLE_RATE:4.2f}s "
        f"{os.path.getsize(path) / 1024:6.1f} KB"
    )


def _noise_burst(duration, decay, cutoff=0.5):
    """A decaying noise burst, low-passed so it reads as a click not a hiss."""
    n = int(SAMPLE_RATE * duration)
    raw = [RNG.uniform(-1, 1) for _ in range(n)]
    # One-pole low-pass, strength from cutoff (0 = muffled, 1 = bright).
    a = max(0.02, min(0.99, cutoff))
    out, prev = [], 0.0
    for s in raw:
        prev = prev + a * (s - prev)
        out.append(prev * math.exp(-decay * len(out) / n))
    return out


def _tone(freq, duration, decay=4.0, harmonics=(1.0, 0.35, 0.12)):
    n = int(SAMPLE_RATE * duration)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-decay * t / duration)
        s = sum(
            amp * math.sin(2 * math.pi * freq * (k + 1) * t)
            for k, amp in enumerate(harmonics)
        )
        out.append(s * env)
    return out


def _mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    peak = max((abs(s) for s in out), default=1.0) or 1.0
    return [s / peak * 0.85 for s in out]


def _punch(samples, drive=2.2):
    """Drives a short tap into a soft clip so it reads louder and clearer.

    A chip click is only a few dozen milliseconds, so at an equal peak it sinks
    under the dice and the stingers. Pushing it into a tanh curve lifts its body
    and adds harmonics - louder and crisper to the ear - then re-normalises so
    it still peaks just under full scale instead of hard-clipping. Only the taps
    get this; the dice and the stingers are left exactly as they were.
    """
    shaped = [math.tanh(s * drive) for s in samples]
    peak = max((abs(s) for s in shaped), default=1.0) or 1.0
    return [s / peak * 0.98 for s in shaped]


def _sequence(notes, note_len, decay=5.0):
    """Concatenate tones, each fading in and out so notes do not click."""
    out = []
    for freq in notes:
        seg = _tone(freq, note_len, decay=decay)
        fade = max(1, int(len(seg) * 0.12))
        for i in range(fade):
            seg[i] *= i / fade
            seg[-1 - i] *= i / fade
        out.extend(seg)
    return out


def _silence(duration):
    return [0.0] * int(SAMPLE_RATE * duration)


def _read_wav(path):
    """Decode a mono or stereo 16-bit WAV into float samples at SAMPLE_RATE.

    The bundled clip master is a 44.1 kHz stereo file; averaging the two
    channels, then averaging each pair of frames, gives clean mono at the
    project rate with no dependency beyond the standard library.
    """
    with wave.open(path, "rb") as w:
        channels = w.getnchannels()
        rate = w.getframerate()
        frames = w.readframes(w.getnframes())
    raw = struct.unpack("<%dh" % (len(frames) // 2), frames)
    if channels == 2:
        raw = [(raw[i] + raw[i + 1]) / 2 for i in range(0, len(raw), 2)]
    samples = [s / 32768.0 for s in raw]
    if rate == SAMPLE_RATE:
        return samples
    # Pair-average to halve the rate (the master is 44.1k, the project 22.05k).
    return [
        (samples[i] + samples[i + 1]) / 2 for i in range(0, len(samples) - 1, 2)
    ]


def _roll_3d_from_master(path, duration=1.4, fade=0.25):
    """The 3D flight sound: the hand-placed master, trimmed and levelled.

    The clip is cut to just outlast the dice's flight, faded out over the last
    strip so it falls silent as the result stinger lands, then normalised to the
    same peak the rest of the sounds are written at.
    """
    samples = _read_wav(path)
    out = samples[: int(SAMPLE_RATE * duration)]
    fade_n = int(SAMPLE_RATE * fade)
    for i in range(1, fade_n + 1):
        out[-i] *= i / fade_n
    return _mix(out)


N = {
    "C5": 523.25,
    "D5": 587.33,
    "E5": 659.25,
    "G5": 783.99,
    "A5": 880.00,
    "C6": 1046.50,
    "G4": 392.00,
    "E4": 329.63,
    "C4": 261.63,
}


def generate_audio():
    # Chip landing on felt: tight, woody, very short. Punched so it carries.
    _write_wav(
        os.path.join(AUDIO_DIR, "chip_place.wav"),
        _punch(
            _mix(
                _noise_burst(0.07, decay=9.0, cutoff=0.28),
                _tone(520, 0.05, decay=14),
            )
        ),
    )

    # Dice rattling in a cup before the throw: scattered clicks.
    rattle = []
    for _ in range(14):
        rattle.extend(_silence(RNG.uniform(0.012, 0.045)))
        rattle.extend(_noise_burst(0.05, decay=11.0, cutoff=RNG.uniform(0.25, 0.5)))
    rattle.extend(_silence(0.05))
    _write_wav(os.path.join(AUDIO_DIR, "dice_rattle.wav"), _mix(rattle))

    # The throw itself: a swelling tumble that decays as the dice settle.
    n = int(SAMPLE_RATE * 1.1)
    roll, prev = [], 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        swell = math.sin(math.pi * min(1.0, t / 1.1)) ** 1.5
        prev = prev + 0.22 * (RNG.uniform(-1, 1) - prev)
        roll.append(prev * swell)
    for _ in range(5):
        roll.extend(_silence(RNG.uniform(0.02, 0.05)))
        roll.extend(_noise_burst(0.06, decay=10.0, cutoff=0.3))
    _write_wav(os.path.join(AUDIO_DIR, "dice_roll.wav"), _mix(roll))

    # Win: bright ascending major arpeggio.
    _write_wav(
        os.path.join(AUDIO_DIR, "win.wav"),
        _sequence([N["C5"], N["E5"], N["G5"], N["C6"]], 0.11),
    )

    # Big win: longer flourish, used when a multi-symbol round pays.
    _write_wav(
        os.path.join(AUDIO_DIR, "win_big.wav"),
        _sequence([N["C5"], N["E5"], N["G5"], N["C6"], N["E5"], N["G5"], N["C6"]], 0.10),
    )

    # Lose: soft descending two notes, never harsh or punishing.
    _write_wav(
        os.path.join(AUDIO_DIR, "lose.wav"),
        _sequence([N["G4"], N["E4"]], 0.17, decay=4.0),
    )

    # UI tick for chip selection. Punched like the chip so the pair matches.
    _write_wav(
        os.path.join(AUDIO_DIR, "select.wav"),
        _punch(
            _mix(
                _tone(880, 0.04, decay=16),
                _noise_burst(0.03, decay=18, cutoff=0.4),
            )
        ),
    )

    # Kept last so a full regeneration reproduces every earlier sound exactly,
    # then derives this one. The 3D coin-game throw plays a trimmed, levelled
    # copy of the hand-placed master many_dice_rolling_sound.wav: cut to just
    # outlast the flight, faded out before the result stinger, and normalised
    # to the same peak as the rest of the dice. Re-run the generator after
    # replacing the master to refresh the copy.
    _write_wav(
        os.path.join(AUDIO_DIR, "dice_roll_3d.wav"),
        _roll_3d_from_master(
            os.path.join(AUDIO_DIR, "many_dice_rolling_sound.wav")
        ),
    )


def main():
    os.makedirs(FELT_DIR, exist_ok=True)
    os.makedirs(AUDIO_DIR, exist_ok=True)
    print("Generating assets:")
    generate_felt(os.path.join(FELT_DIR, "felt.png"))
    generate_audio()
    print("Done.")


if __name__ == "__main__":
    main()
