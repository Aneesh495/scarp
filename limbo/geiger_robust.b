# geiger_robust.b: Huber M-Estimator Robust Outlier Suppression in Limbo
implement GeigerRobust;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "geiger.m";
    geiger: GeigerLocator;

GeigerRobust: module
{
    PATH: con "/dis/geiger_robust.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    calc_huber_weights: fn(residuals: array of real, prior_weights: array of real, k_factor: real): array of real;
    estimate_mad_sigma: fn(residuals: array of real): real;
};

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

estimate_mad_sigma(residuals: array of real): real
{
    if (residuals == nil || len residuals == 0) return 0.1;
    n := len residuals;

    # Compute Root-Mean-Square residual
    sum_sq := 0.0;
    for (i := 0; i < n; i++) {
        r := residuals[i];
        sum_sq += r * r;
    }

    sigma := sqrt_approx(sum_sq / real n);
    if (sigma < 0.01) sigma = 0.01;
    return sigma;
}

calc_huber_weights(residuals: array of real, prior_weights: array of real, k_factor: real): array of real
{
    if (residuals == nil || len residuals == 0) return array[0] of real;
    n := len residuals;
    weights := array[n] of real;

    if (k_factor <= 0.0) k_factor = 1.5;
    sigma := estimate_mad_sigma(residuals);
    threshold := k_factor * sigma;

    for (i := 0; i < n; i++) {
        abs_r := residuals[i];
        if (abs_r < 0.0) abs_r = -abs_r;

        pw := 1.0;
        if (prior_weights != nil && i < len prior_weights && prior_weights[i] > 0.0) {
            pw = prior_weights[i];
        }

        if (abs_r <= threshold) {
            weights[i] = pw; # Full weight
        } else {
            # Huber down-weighting: w = pw * (threshold / |r|)
            weights[i] = pw * (threshold / abs_r);
        }
    }

    return weights;
}
