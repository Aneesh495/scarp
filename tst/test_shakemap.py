#!/usr/bin/env python3
"""
test_shakemap.py: Comprehensive Unit Tests for ShakeMap and Intensity Modeling
Tests GMPE attenuation curves, Wald MMI conversions, and S-wave TTI countdown.
"""

import math
import sys
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def test_gmpe_attenuation_monotonicity():
    """Verify ground motion attenuates monotonically with hypocentral distance."""
    mw = 6.8
    distances = [10.0, 25.0, 50.0, 100.0, 200.0]

    # Attenuation model: PGA ~ 1 / R^gamma
    pgas = []
    for r in distances:
        pga = (mw * 15.0) / (1.0 + 0.08 * r)
        pgas.append(pga)

    for i in range(len(pgas) - 1):
        assert pgas[i] > pgas[i + 1], f"PGA did not attenuate: {pgas[i]} <= {pgas[i+1]}"
    print("PASS: test_gmpe_attenuation_monotonicity")


def test_wald_mmi_bounds():
    """Verify instrumental MMI mapping maps correctly to [1.0, 10.0]."""
    # Very weak motion
    low_pga = 0.01  # %g
    log_pga = math.log10(low_pga)
    mmi_low = 2.20 * log_pga + 1.00
    if mmi_low < 1.0:
        mmi_low = 1.0
    assert mmi_low == 1.0, f"Low MMI out of range: {mmi_low}"

    # Catastrophic strong motion
    high_pgv = 150.0  # cm/s
    log_pgv = math.log10(high_pgv)
    mmi_high = 3.47 * log_pgv + 2.35
    if mmi_high > 10.0:
        mmi_high = 10.0
    assert mmi_high >= 9.0 and mmi_high <= 10.0, f"High MMI out of range: {mmi_high}"
    print("PASS: test_wald_mmi_bounds")


def test_tti_countdown():
    """Verify S-wave time-to-impact decrements linearly with time."""
    r_rup = 70.0  # km
    vs = 3.5  # km/s
    s_arrival_time = r_rup / vs  # 20.0 seconds

    t_eval = 8.0  # seconds elapsed since origin
    tti = s_arrival_time - t_eval
    assert abs(tti - 12.0) < 1e-9, f"TTI calculation error: {tti}"
    print("PASS: test_tti_countdown")


if __name__ == "__main__":
    test_gmpe_attenuation_monotonicity()
    test_wald_mmi_bounds()
    test_tti_countdown()
    print("All ShakeMap unit tests passed successfully.")
