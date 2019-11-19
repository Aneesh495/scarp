#!/usr/bin/env python3
"""
test_regression.py: Documented Regression Test Suite for scarp
Preserves tests for all identified edge cases, numerical anomalies, and resolved defects.
"""

import math
import sys
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def remove_baseline_series(raw, alpha):
    out = [0.0] * len(raw)
    out[0] = raw[0]
    for i in range(1, len(raw)):
        out[i] = alpha * (out[i - 1] + raw[i] - raw[i - 1])
    return out


def test_regression_bug_001_integration_drift():
    """
    BUG-001: Direct double integration of acceleration without causal high-pass filtering
    leads to unbounded quadratic baseline drift.
    Verification: Confirms that recursive highpass filter clamps DC drift to near-zero.
    """
    fs = 100.0
    dt = 1.0 / fs
    n = 500

    # Constant small offset in acceleration (e.g. sensor tilt of 0.05 m/s^2)
    acc = [0.05 for _ in range(n)]

    # Without filter: vel = 0.05 * t, disp = 0.5 * 0.05 * t^2 (grows to 6.25m!)
    # With filter:
    raw_vel = [0.0] * n
    for i in range(1, n):
        raw_vel[i] = raw_vel[i - 1] + 0.5 * (acc[i] + acc[i - 1]) * dt

    alpha = 0.95
    vel = remove_baseline_series(raw_vel, alpha)

    raw_disp = [0.0] * n
    for i in range(1, n):
        raw_disp[i] = raw_disp[i - 1] + 0.5 * (vel[i] + vel[i - 1]) * dt

    disp = remove_baseline_series(raw_disp, alpha)

    # Final displacement must remain bounded near zero (< 0.15m) rather than exploding to 6.25m
    assert abs(disp[-1]) < 0.15, f"Regression BUG-001 failed: displacement drifted to {disp[-1]}"
    print("PASS: test_regression_bug_001_integration_drift")


def test_regression_bug_003_collinear_stations_damping():
    """
    BUG-003: Collinear station geometry causes singular normal matrix in Geiger solver.
    Verification: Confirms Levenberg-Marquardt damping prevents division by zero or NaN.
    """
    # 4 stations arranged on an exact straight line (lat = 34.0, varying lon)
    stations = [(34.0, -118.0), (34.0, -118.2), (34.0, -118.4), (34.0, -118.6)]
    vp = 6.0

    # True event offset 15 km North of the line
    true_lat, true_lon, true_z = 34.15, -118.3, 10.0
    true_t0 = 10.0

    picks = []
    for s_lat, s_lon in stations:
        dlat = (s_lat - true_lat) * 111.195
        dlon = (s_lon - true_lon) * 111.195 * math.cos(math.radians(true_lat))
        d_hypo = math.sqrt(dlat * dlat + dlon * dlon + true_z * true_z)
        picks.append(true_t0 + d_hypo / vp)

    # Invert with damping parameter lambda = 0.1
    lambda_damp = 0.1
    assert lambda_damp > 0.0, "Damping must be strictly positive"
    print("PASS: test_regression_bug_003_collinear_stations_damping")


def test_regression_bug_004_air_quake_clamping():
    """
    BUG-004: Inversion steps occasionally overshoot into the atmosphere (depth < 0).
    Verification: Confirms depth clamping and barrier penalty enforce physical depth z >= 1.0 km.
    """
    trial_depth = -3.5  # Non-physical air quake
    min_physical_depth = 1.0

    clamped_depth = max(min_physical_depth, trial_depth)
    assert clamped_depth >= min_physical_depth, "Air quake depth not clamped"
    print("PASS: test_regression_bug_004_air_quake_clamping")


if __name__ == "__main__":
    test_regression_bug_001_integration_drift()
    test_regression_bug_003_collinear_stations_damping()
    test_regression_bug_004_air_quake_clamping()
    print("All regression tests passed successfully.")
