import math
import unittest

from audio_sampler import BANDS, EDGES, RATE, SIZE, analyze, analyze_stereo, meter_level


class SamplerTests(unittest.TestCase):
    def test_silence(self):
        frame = analyze([0.0] * SIZE)
        self.assertEqual(frame["bands"], [0.0] * BANDS)
        self.assertEqual(frame["waveform"], [0.0] * 96)
        self.assertEqual(frame["rms"], 0)

    def test_tone_frequency_and_raw_waveform(self):
        for frequency in (100, 1000, 6000):
            samples = [0.2 * math.sin(2 * math.pi * frequency * i / RATE) for i in range(SIZE)]
            frame = analyze(samples)
            loudest = max(range(BANDS), key=lambda i: frame["bands"][i])
            self.assertLessEqual(EDGES[loudest] - RATE / SIZE, frequency)
            self.assertGreaterEqual(EDGES[loudest + 1] + RATE / SIZE, frequency)
            self.assertAlmostEqual(frame["rms"], 0.2 / math.sqrt(2), places=2)
            self.assertTrue(any(v > 0 for v in frame["waveform"]))
            self.assertTrue(any(v < 0 for v in frame["waveform"]))

    def test_nonfinite_input(self):
        frame = analyze([float("nan"), float("inf")] + [0.0] * (SIZE - 2))
        self.assertEqual(frame["rms"], 0)

    def test_stereo_channel_separation(self):
        tone = [0.2 * math.sin(2 * math.pi * 1000 * i / RATE) for i in range(SIZE)]
        for audible in (0, 1):
            interleaved = [v for sample in tone for v in ((sample, 0) if audible == 0 else (0, sample))]
            frame = analyze_stereo(interleaved)
            self.assertGreater(frame["channels"][audible], 0.35)
            self.assertEqual(frame["channels"][1 - audible], 0)
            self.assertGreaterEqual(frame["channelPeaks"][audible], frame["channels"][audible])

    def test_stereo_silence(self):
        frame = analyze_stereo([0.0] * (SIZE * 2))
        self.assertEqual(frame["channels"], [0, 0])
        self.assertEqual(frame["channelPeaks"], [0, 0])
        self.assertEqual(frame["bass"], 0)

    def test_meter_has_headroom_and_useful_dynamics(self):
        values = [meter_level(v) for v in (0.01, 0.05, 0.1, 0.2, 0.5, 1.0)]
        self.assertTrue(all(a < b for a, b in zip(values, values[1:])))
        self.assertLess(meter_level(0.5), 0.85)
        self.assertGreater(meter_level(0.2) - meter_level(0.05), 0.2)
        self.assertEqual(meter_level(0), 0)
        self.assertEqual(meter_level(1), 1)

    def test_bass_reacts_to_low_frequencies(self):
        def bass(frequency):
            tone = [0.2 * math.sin(2 * math.pi * frequency * i / RATE) for i in range(SIZE)]
            return analyze_stereo([v for sample in tone for v in (sample, sample)])["bass"]
        self.assertGreater(bass(80), bass(3000) + 0.5)

    def test_opposite_phase_does_not_cancel_visualizer(self):
        tone = [0.2 * math.sin(2 * math.pi * 1000 * i / RATE) for i in range(SIZE)]
        frame = analyze_stereo([v for sample in tone for v in (sample, -sample)])
        self.assertGreater(max(frame["bands"]), 0.5)
        self.assertEqual(frame["channels"][0], frame["channels"][1])

    def test_raw_bass_preserves_loud_signal_dynamics(self):
        frames = []
        for amplitude in (0.5, 0.9):
            tone = [amplitude * math.sin(2 * math.pi * 80 * i / RATE) for i in range(SIZE)]
            frames.append(analyze_stereo([v for sample in tone for v in (sample, sample)]))
        self.assertEqual(frames[0]["bass"], 1)
        self.assertEqual(frames[1]["bass"], 1)
        self.assertGreater(frames[1]["bassAmplitude"], frames[0]["bassAmplitude"] * 1.7)


if __name__ == "__main__":
    unittest.main()
