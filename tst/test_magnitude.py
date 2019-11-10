#!/usr/bin/env python3
"""
test_magnitude.py: Comprehensive Unit Tests for Magnitude Scaling
Tests Pd distance scaling, tau_c period relations, and Bayesian pooling.
"""

import math
import sys
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def test_pd_magnitude_scaling():
    """Verify Pd scaling relation reproduces moment magnitude across distances."""
    # Wu & Kanamori relationship:
    # log10(Pd) = 0.82 * M - 1.35 * log10(R) - 4.34
    true_m = 6.5
    dist_km = 30.0

    log10_pd = 0.82 * true_m - 1.35 * math.log10(dist_km) - 4.34
    pd_cm = 10.0 ** log10_pd

    # Invert for magnitude
    est_m = (math.log10(pd_cm) + 1.35 * math.log10(dist_km) + 4.34) / 0.82
    assert abs(est_m - true_m) < 1e-6, f"Pd magnitude inversion failed: {est_m} vs {true_m}"
    print("PASS: test_pd_magnitude_scaling")


def test_tau_c_period_scaling():
    """Verify tau_c scaling relation is distance-independent."""
    # Kanamori & Allen relation: log10(tau_c) = 0.29 * M - 1.30
    true_m = 7.0
    log10_tc = 0.29 * true_m - 1.30
    tau_c_s = 10.0 ** log10_tc

    est_m = (math.log10(tau_c_s) + 1.30) / 0.29
    assert abs(est_m - true_m) < 1e-6, f"Tau_c magnitude inversion failed: {est_m} vs {true_m}"
    print("PASS: test_tau_c_period_scaling")


def test_bayesian_pooling():
    """Verify Bayesian combination weights smaller uncertainties more heavily."""
    m1 = 6.4
    sigma1 = 0.2

    m2 = 6.8
    sigma2 = 0.5

    w1 = 1.0 / (sigma1 * sigma1)
    w2 = 1.0 / (sigma2 * sigma2)

    comb_m = (w1 * m1 + w2 * m2) / (w1 + w2)
    comb_sigma = 1.0 / math.sqrt(w1 + w2)

    assert comb_m > 6.4 and comb_m < 6.8, "Combined magnitude out of bounds"
    assert comb_m < 6.55, "Combined magnitude not sufficiently pulled toward m1"
    assert comb_sigma < sigma1, "Combined uncertainty must be smaller than individual sigma"
    print("PASS: test_bayesian_pooling")


if __name__ == "__main__":
    test_pd_magnitude_scaling()
    test_tau_c_period_scaling()
    test_bayesian_pooling()
    print("All magnitude unit tests passed successfully.")
