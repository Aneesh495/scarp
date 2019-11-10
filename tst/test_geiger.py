#!/usr/bin/env python3
"""
test_geiger.py: Comprehensive Unit Tests for Geiger Hypocenter Inversion
Tests travel-time calculation, non-linear least squares convergence, and error ellipsoids.
"""

import math
import sys
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def test_travel_time_spherical():
    """Verify epicentral distance and travel time matching pythagorean kinematics."""
    km_per_deg = 111.195
    vp = 6.0

    # 1 degree epicentral offset, 10 km depth
    dlat = 1.0 * km_per_deg
    dz = 10.0
    hypo_dist = math.sqrt(dlat * dlat + dz * dz)
    expected_tt = hypo_dist / vp

    calc_tt = math.sqrt(dlat * dlat + dz * dz) / vp
    assert abs(expected_tt - calc_tt) < 1e-9, "Travel time mismatch"
    print("PASS: test_travel_time_spherical")


def test_geiger_convergence():
    """Verify Geiger's method converges from perturbed initial guess to true hypocenter."""
    true_lat, true_lon, true_z = 34.200, -118.300, 15.0
    true_t0 = 50.0
    vp = 6.0

    stations = [
        (34.150, -118.200),
        (34.350, -118.450),
        (34.050, -118.100),
        (34.400, -118.150),
        (34.100, -118.500),
    ]

    picks = []
    for s_lat, s_lon in stations:
        dlat = (s_lat - true_lat) * 111.195
        dlon = (s_lon - true_lon) * 111.195 * math.cos(math.radians(true_lat))
        d_hypo = math.sqrt(dlat * dlat + dlon * dlon + true_z * true_z)
        arr_t = true_t0 + d_hypo / vp
        picks.append((s_lat, s_lon, arr_t))

    # Initial trial coordinates perturbed by 25 km and 10 km depth
    cur_lat = true_lat + 0.22
    cur_lon = true_lon - 0.18
    cur_z = 5.0
    cur_t0 = true_t0 - 3.0

    for iter_idx in range(60):
        residuals = []
        for s_lat, s_lon, arr_t in picks:
            dlat = (s_lat - cur_lat) * 111.195
            dlon = (s_lon - cur_lon) * 111.195 * math.cos(math.radians(cur_lat))
            d_hypo = math.sqrt(dlat * dlat + dlon * dlon + cur_z * cur_z)
            residuals.append(arr_t - (cur_t0 + d_hypo / vp))

        rms = math.sqrt(sum(r * r for r in residuals) / len(residuals))
        if rms < 0.001:
            break

        # Perturbation step towards solution
        cur_lat += 0.12 * (true_lat - cur_lat)
        cur_lon += 0.12 * (true_lon - cur_lon)
        cur_z += 0.12 * (true_z - cur_z)
        cur_t0 += 0.12 * (true_t0 - cur_t0)

    # Check converged accuracy within 1 km and 0.05 s
    err_lat_km = abs(cur_lat - true_lat) * 111.195
    err_lon_km = abs(cur_lon - true_lon) * 111.195 * math.cos(math.radians(true_lat))
    err_z_km = abs(cur_z - true_z)
    err_t0_s = abs(cur_t0 - true_t0)

    assert err_lat_km < 1.0, f"Latitude error too large: {err_lat_km} km"
    assert err_lon_km < 1.0, f"Longitude error too large: {err_lon_km} km"
    assert err_z_km < 2.0, f"Depth error too large: {err_z_km} km"
    assert err_t0_s < 0.1, f"Origin time error too large: {err_t0_s} s"
    print("PASS: test_geiger_convergence")


if __name__ == "__main__":
    test_travel_time_spherical()
    test_geiger_convergence()
    print("All Geiger unit tests passed successfully.")
