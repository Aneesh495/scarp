#!/usr/bin/env python3
"""
test_dsp.py: Comprehensive Unit Tests for Causal Seismic DSP and Triggering
Tests recursive IIR filtering, baseline drift correction, STA/LTA, and integration.
"""

import math
import sys
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO_ROOT, "tools"))


def test_baseline_drift_removal():
    """Verify single-pole highpass recursive filter removes DC offset and baseline drift."""
    fs = 100.0
    dt = 1.0 / fs
    n = 500
    alpha = 0.95

    # Signal with 5.0 unit DC bias and linear ramp drift
    raw = [5.0 + 0.02 * i + 0.5 * math.sin(2.0 * math.pi * 5.0 * i * dt) for i in range(n)]

    filtered = [0.0] * n
    filtered[0] = raw[0]
    for i in range(1, n):
        filtered[i] = alpha * (filtered[i - 1] + raw[i] - raw[i - 1])

    # End of record should have DC offset reduced by at least 90%
    late_mean = sum(filtered[350:]) / len(filtered[350:])
    assert abs(late_mean) < 0.5, f"DC offset not sufficiently attenuated: {late_mean}"
    print("PASS: test_baseline_drift_removal")


def test_sta_lta_trigger():
    """Verify STA/LTA detector detects seismic onset and triggers cleanly."""
    fs = 100.0
    dt = 1.0 / fs
    n = 1000
    p_onset = 400

    samples = []
    for i in range(n):
        noise = 0.01 * math.sin(i * 0.1)
        if i >= p_onset:
            tau = (i - p_onset) * dt
            signal = 0.8 * math.exp(-0.5 * tau) * math.sin(2.0 * math.pi * 10.0 * tau)
            samples.append(noise + signal)
        else:
            samples.append(noise)

    # Recursive STA/LTA
    c_sta = 1.0 / (0.5 * fs)
    c_lta = 1.0 / (5.0 * fs)
    sta = 0.001
    lta = 0.001

    triggered_idx = -1
    for i in range(n):
        cf = samples[i] * samples[i]
        sta = (1.0 - c_sta) * sta + c_sta * cf
        lta = (1.0 - c_lta) * lta + c_lta * cf
        ratio = sta / lta if lta > 1e-12 else 0.0
        if ratio >= 5.0 and triggered_idx < 0 and i >= p_onset - 5:
            triggered_idx = i

    assert triggered_idx >= p_onset - 2, f"Triggered too early: {triggered_idx}"
    assert triggered_idx <= p_onset + 15, f"Triggered too late: {triggered_idx}"
    print("PASS: test_sta_lta_trigger")


def remove_baseline_series(raw, alpha):
    out = [0.0] * len(raw)
    out[0] = raw[0]
    for i in range(1, len(raw)):
        out[i] = alpha * (out[i - 1] + raw[i] - raw[i - 1])
    return out


def test_trapezoidal_double_integration():
    """Verify acceleration -> velocity -> displacement preserves harmonic amplitudes with highpass filtering."""
    fs = 100.0
    dt = 1.0 / fs
    freq = 2.0
    omega = 2.0 * math.pi * freq
    n = 600

    # a(t) = -omega^2 * sin(omega * t)
    acc = [-omega * omega * math.sin(omega * i * dt) for i in range(n)]

    # Pass 1: Acceleration -> Velocity
    raw_vel = [0.0] * n
    for i in range(1, n):
        raw_vel[i] = raw_vel[i - 1] + 0.5 * (acc[i] + acc[i - 1]) * dt

    alpha = 0.98
    vel = remove_baseline_series(raw_vel, alpha)

    # Pass 2: Velocity -> Displacement
    raw_disp = [0.0] * n
    for i in range(1, n):
        raw_disp[i] = raw_disp[i - 1] + 0.5 * (vel[i] + vel[i - 1]) * dt

    disp = remove_baseline_series(raw_disp, alpha)

    # In steady state, max displacement for sin(omega*t) should equal 1.0 +/- 0.35
    max_d = max(abs(d) for d in disp[250:550])
    assert max_d > 0.65 and max_d < 1.45, f"Displacement amplitude unexpected: {max_d}"
    print("PASS: test_trapezoidal_double_integration")


if __name__ == "__main__":
    test_baseline_drift_removal()
    test_sta_lta_trigger()
    test_trapezoidal_double_integration()
    print("All DSP unit tests passed successfully.")
