# magnitude_pd.b: Real-Time Peak Displacement Magnitude Scaling in Limbo
implement MagnitudePd;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "magnitude.m";
    magnitude: MagnitudeEngine;

MagnitudePd: module
{
    PATH: con "/dis/magnitude_pd.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    estimate_mpd: fn(pd_cm: real, hypocentral_dist_km: real): real;
};

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

log10_approx(x: real): real
{
    if (x <= 1e-12) return -12.0;
    # ln(x) using series around x = m * 2^k
    # log10(x) = ln(x) / 2.302585092994046
    val := x;
    k := 0;
    while (val > 2.0) {
        val *= 0.5;
        k++;
    }
    while (val < 0.5) {
        val *= 2.0;
        k--;
    }
    # ln(val) for val near 1 using y = (val - 1)/(val + 1)
    y := (val - 1.0) / (val + 1.0);
    y2 := y * y;
    ln_val := 2.0 * y * (1.0 + y2 / 3.0 + (y2 * y2) / 5.0 + (y2 * y2 * y2) / 7.0);
    ln_x := ln_val + real k * 0.6931471805599453;
    return ln_x / 2.302585092994046;
}

estimate_mpd(pd_cm: real, hypocentral_dist_km: real): real
{
    if (pd_cm <= 1e-8) pd_cm = 1e-8;
    dist := hypocentral_dist_km;
    if (dist < 1.0) dist = 1.0;

    # Wu & Kanamori / Kuyuk & Allen relationship:
    # log10(Pd) = 0.82 * M - 1.35 * log10(R) - 4.34
    # => M = (log10(Pd) + 1.35 * log10(R) + 4.34) / 0.82
    log_pd := log10_approx(pd_cm);
    log_r := log10_approx(dist);

    m_est := (log_pd + 1.35 * log_r + 4.34) / 0.82;

    if (m_est < 1.0) m_est = 1.0;
    if (m_est > 9.5) m_est = 9.5;

    return m_est;
}
