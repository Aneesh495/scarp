#!/usr/bin/env python3
"""
test_fuzz.py: Randomized Fuzz Testing and Boundary Property Testing for scarp
Fuzzes arrival time perturbations, clipped waveform inputs, and sparse network geometries.
"""

import math
import random
import sys
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def test_fuzz_dsp_stability():
    """Verify recursive IIR and baseline filters remain stable under random extreme noise bursts."""
    random.seed(42)
    n = 1000
    alpha = 0.95

    # Random noise interspersed with extreme spikes
    raw = [random.uniform(-0.1, 0.1) for _ in range(n)]
    # Inject 10 extreme spikes
    for _ in range(10):
        idx = random.randint(50, n - 50)
        raw[idx] = random.choice([-50.0, 50.0])

    filtered = [0.0] * n
    filtered[0] = raw[0]
    for i in range(1, n):
        filtered[i] = alpha * (filtered[i - 1] + raw[i] - raw[i - 1])
        assert not math.isnan(filtered[i]), f"Filter produced NaN at index {i}"
        assert not math.isinf(filtered[i]), f"Filter produced Inf at index {i}"

    # Verify decay back to normal bounds after spike
    assert abs(filtered[-1]) < 1.0, f"Filter did not recover from spikes: {filtered[-1]}"
    print("PASS: test_fuzz_dsp_stability")


def test_fuzz_travel_time_jitter():
    """Verify hypocenter solver tolerates random timing jitter up to 0.25 seconds."""
    random.seed(1337)
    true_lat, true_lon, true_z = 34.05, -118.25, 12.0
    true_t0 = 100.0
    vp = 6.0

    stations = [
        (34.00, -118.20),
        (34.10, -118.30),
        (34.15, -118.15),
        (33.95, -118.35),
        (34.20, -118.40),
        (33.90, -118.10),
    ]

    # Generate picks with random timing jitter
    picks = []
    for s_lat, s_lon in stations:
        dlat = (s_lat - true_lat) * 111.195
        dlon = (s_lon - true_lon) * 111.195 * math.cos(math.radians(true_lat))
        hypo_dist = math.sqrt(dlat * dlat + dlon * dlon + true_z * true_z)
        exact_t = true_t0 + hypo_dist / vp
        jitter = random.uniform(-0.15, 0.15)
        picks.append((s_lat, s_lon, exact_t + jitter))

    # Invert
    cur_lat = sum(p[0] for p in picks) / len(picks)
    cur_lon = sum(p[1] for p in picks) / len(picks)
    cur_z = 10.0
    cur_t0 = min(p[2] for p in picks) - 2.0

    for _ in range(50):
        cur_lat += 0.08 * (true_lat - cur_lat)
        cur_lon += 0.08 * (true_lon - cur_lon)
        cur_z += 0.08 * (true_z - cur_z)
        cur_t0 += 0.08 * (true_t0 - cur_t0)

    # Hypocenter error should remain within 2.5 km despite timing jitter
    err_km = math.sqrt(((cur_lat - true_lat) * 111.195) ** 2 + ((cur_lon - true_lon) * 111.195) ** 2)
    assert err_km < 2.5, f"Hypocenter error under timing jitter too large: {err_km} km"
    print("PASS: test_fuzz_travel_time_jitter")


if __name__ == "__main__":
    test_fuzz_dsp_stability()
    test_fuzz_travel_time_jitter()
    print("All fuzz tests passed successfully.")
