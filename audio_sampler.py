"""Read the default PipeWire output monitor; emit spectrum and PCM trace as JSON.

Uses only Python's standard library and pw-cat. Audio is never saved to disk.
"""

import argparse
import cmath
import ctypes
import json
import math
import signal
import struct
import subprocess
import sys

RATE = 24000
SIZE = 1024
BANDS = 16
WINDOW = [0.5 - 0.5 * math.cos(2 * math.pi * i / (SIZE - 1)) for i in range(SIZE)]
ORDER = [int(f"{i:010b}"[::-1], 2) for i in range(SIZE)]
TWIDDLES = {
    size: [cmath.exp(-2j * math.pi * k / size) for k in range(size // 2)]
    for size in (2, 4, 8, 16, 32, 64, 128, 256, 512, 1024)
}
EDGES = [45 * (10000 / 45) ** (i / BANDS) for i in range(BANDS + 1)]


def analyze(samples):
    """Hann-windowed radix-2 FFT plus a zero-crossing-aligned real PCM trace."""
    samples = [v if math.isfinite(v) else 0.0 for v in samples]
    values = [complex(samples[i] * WINDOW[i]) for i in ORDER]
    for size, twiddles in TWIDDLES.items():
        half = size // 2
        for start in range(0, SIZE, size):
            for k, twiddle in enumerate(twiddles):
                even = values[start + k]
                odd = twiddle * values[start + k + half]
                values[start + k] = even + odd
                values[start + k + half] = even - odd
    magnitudes = [abs(v) * 4 / SIZE for v in values[:SIZE // 2]]
    bands = []
    for lo, hi in zip(EDGES, EDGES[1:]):
        left = max(1, int(lo * SIZE / RATE))
        right = min(SIZE // 2, max(left + 1, math.ceil(hi * SIZE / RATE)))
        amplitude = max(magnitudes[left:right], default=0)
        # Fixed dB range: silence stays silent; gentle high-frequency weighting.
        boost = min(10, max(0, 6 * math.log10(math.sqrt(lo * hi) / 200)))
        db = 20 * math.log10(max(1e-12, amplitude)) + boost
        bands.append(round(max(0, min(1, (db + 70) / 58)), 4))
    start = next((i for i in range(1, 256) if samples[i - 1] <= 0 < samples[i]), 0)
    waveform = [round(max(-1, min(1, samples[start + i * 3] * 2.5)), 4) for i in range(96)]
    return {
        "bands": bands,
        "waveform": waveform,
        "rms": round(math.sqrt(sum(v * v for v in samples) / SIZE), 6),
        # Keep unclipped low-band amplitude for relative dynamics in the dots.
        "bassAmplitude": round(max(magnitudes[max(1, int(EDGES[0] * SIZE / RATE)):
            math.ceil(EDGES[4] * SIZE / RATE)], default=0), 7),
    }


def parent_death_signal():
    # Ensure the capture child exits even if the shell/helper dies unexpectedly.
    ctypes.CDLL(None).prctl(1, signal.SIGTERM)


def meter_level(amplitude):
    # Reserve full scale for 0 dBFS, not -8 dBFS. Expand the useful middle range
    # so mastered music does not light almost every segment all the time.
    normalized = max(0, min(1, (20 * math.log10(max(1e-12, amplitude)) + 48) / 48))
    return round(normalized ** 1.6, 4)


def analyze_stereo(interleaved):
    channels = [[v if math.isfinite(v) else 0.0 for v in interleaved[offset::2]] for offset in (0, 1)]
    rms = [math.sqrt(sum(v * v for v in channel) / SIZE) for channel in channels]
    mono = [(left + right) / 2 for left, right in zip(*channels)]
    # Preserve the signal if opposite-phase channels cancel in the mono mix.
    mixed_rms = math.sqrt(sum(v * v for v in mono) / SIZE)
    if mixed_rms < max(rms) * 0.1:
        mono = channels[0 if rms[0] >= rms[1] else 1]
    frame = analyze(mono)
    frame["channels"] = [meter_level(value) for value in rms]
    frame["channelPeaks"] = [meter_level(max(map(abs, channel))) for channel in channels]
    # First four logarithmic bands cover the low end, approximately 45–174 Hz.
    frame["bass"] = round(max(frame["bands"][:4], default=0), 4)
    return frame


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frames", type=int, default=0, help="Stop after N frames (testing)")
    args = parser.parse_args()
    capture = subprocess.Popen(
        ["pw-cat", "--record", "--raw", "--rate", str(RATE), "--channels", "2",
         "--channel-map", "stereo",
         "--format", "f32", "--latency", "50ms", "--properties",
         "{ stream.capture.sink = true node.name = alec-media-visualizer application.name = Alec-Media-Visualizer }", "-"],
        stdout=subprocess.PIPE,
        preexec_fn=parent_death_signal,
    )

    def stop(_signum, _frame):
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, stop)
    try:
        count = 0
        while True:
            data = capture.stdout.read(SIZE * 2 * 4)
            if len(data) != SIZE * 2 * 4:
                raise RuntimeError("PipeWire audio stream ended")
            frame = analyze_stereo(struct.unpack(f"<{SIZE * 2}f", data))
            print(json.dumps(frame, separators=(",", ":")), flush=True)
            count += 1
            if args.frames and count >= args.frames:
                return
    finally:
        capture.terminate()
        try:
            capture.wait(timeout=2)
        except subprocess.TimeoutExpired:
            capture.kill()
            capture.wait()


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        pass
    except Exception as error:
        print(f"Audio sampler: {error}", file=sys.stderr)
        sys.exit(1)
