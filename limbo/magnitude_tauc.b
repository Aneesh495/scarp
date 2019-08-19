# magnitude_tauc.b: Characteristic Period Tau_c Magnitude Scaling in Limbo
implement MagnitudeTauC;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "magnitude.m";
    magnitude: MagnitudeEngine;

MagnitudeTauC: module
{
    PATH: con "/dis/magnitude_tauc.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    compute_tau_c: fn(u: array of real, v: array of real, dt: real): real;
    estimate_mtc:  fn(tau_c_s: real): real;
};

PI: con 3.141592653589793;

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

sqrt_approx(x: real): real
{
    if (x <= 0.0) return 0.0;
    val := x;
    if (x > 1.0) val = x * 0.5;
    for (i := 0; i < 8; i++) {
        val = 0.5 * (val + x / val);
    }
    return val;
}

log10_approx(x: real): real
{
    if (x <= 1e-12) return -12.0;
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
    y := (val - 1.0) / (val + 1.0);
    y2 := y * y;
    ln_val := 2.0 * y * (1.0 + y2 / 3.0 + (y2 * y2) / 5.0 + (y2 * y2 * y2) / 7.0);
    ln_x := ln_val + real k * 0.6931471805599453;
    return ln_x / 2.302585092994046;
}

compute_tau_c(u: array of real, v: array of real, dt: real): real
{
    if (u == nil || v == nil || dt <= 0.0) return 0.5;
    n := len u;
    if (len v < n) n = len v;
    if (n < 5) return 0.5;

    sum_v2 := 0.0;
    sum_u2 := 0.0;

    for (i := 0; i < n; i++) {
        sum_v2 += v[i] * v[i] * dt;
        sum_u2 += u[i] * u[i] * dt;
    }

    if (sum_u2 < 1e-12 || sum_v2 < 1e-12) return 0.5;

    r := sum_v2 / sum_u2;
    tau_c := (2.0 * PI) / sqrt_approx(r);

    if (tau_c < 0.05) tau_c = 0.05;
    if (tau_c > 10.0) tau_c = 10.0;

    return tau_c;
}

estimate_mtc(tau_c_s: real): real
{
    tc := tau_c_s;
    if (tc < 0.05) tc = 0.05;

    # Kanamori & Allen relation: log10(tau_c) = 0.29 * M - 1.30
    # => M = (log10(tau_c) + 1.30) / 0.29
    log_tc := log10_approx(tc);
    m_est := (log_tc + 1.30) / 0.29;

    if (m_est < 1.0) m_est = 1.0;
    if (m_est > 9.5) m_est = 9.5;

    return m_est;
}
