# magnitude_bayes.b: Bayesian Multi-Station Magnitude Pooling in Limbo
implement MagnitudeBayes;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "magnitude.m";
    magnitude: MagnitudeEngine;

MagnitudeBayes: module
{
    PATH: con "/dis/magnitude_bayes.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    fuse_estimates: fn(pd_mags: array of real,
                       tc_mags: array of real,
                       station_weights: array of real,
                       prior_mean: real,
                       prior_sigma: real): ref Scarp->MagnitudeSol;
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

fuse_estimates(pd_mags: array of real,
               tc_mags: array of real,
               station_weights: array of real,
               prior_mean: real,
               prior_sigma: real): ref Scarp->MagnitudeSol
{
    sol := ref Scarp->MagnitudeSol;
    sol.event_id = "MAG_001";
    sol.p_window_s = 3.0;

    n := len pd_mags;
    if (len tc_mags < n) n = len tc_mags;
    if (n == 0) {
        sol.mag_mw = 4.0;
        sol.mag_mpd = 4.0;
        sol.mag_mtc = 4.0;
        sol.uncertainty = 0.5;
        sol.num_stations = 0;
        sol.energy_joules = 1e11;
        return sol;
    }

    sum_pd := 0.0;
    sum_tc := 0.0;
    sum_wt_pd := 0.0;
    sum_wt_tc := 0.0;

    for (i := 0; i < n; i++) {
        w := 1.0;
        if (station_weights != nil && i < len station_weights && station_weights[i] > 0.0) {
            w = station_weights[i];
        }
        sum_pd += pd_mags[i] * w;
        sum_wt_pd += w;

        sum_tc += tc_mags[i] * w;
        sum_wt_tc += w;
    }

    mean_pd := (sum_wt_pd > 0.0 ? sum_pd / sum_wt_pd : 4.0);
    mean_tc := (sum_wt_tc > 0.0 ? sum_tc / sum_wt_tc : 4.0);

    sol.mag_mpd = mean_pd;
    sol.mag_mtc = mean_tc;
    sol.num_stations = n;

    # Bayesian combination with Gutenberg-Richter background prior
    sigma_pd := 0.35 / sqrt_approx(real n);
    sigma_tc := 0.40 / sqrt_approx(real n);

    w_pd := 1.0 / (sigma_pd * sigma_pd);
    w_tc := 1.0 / (sigma_tc * sigma_tc);

    w_prior := 0.0;
    if (prior_sigma > 0.0) {
        w_prior = 1.0 / (prior_sigma * prior_sigma);
    }

    total_w := w_pd + w_tc + w_prior;
    comb_mag := (w_pd * mean_pd + w_tc * mean_tc + w_prior * prior_mean) / total_w;

    sol.mag_mw = comb_mag;
    sol.uncertainty = 1.0 / sqrt_approx(total_w);

    # Radiated Seismic Energy: log10(E) = 4.8 + 1.5 * Mw (Joules)
    # Approx E = 10^(4.8 + 1.5 * Mw)
    sol.energy_joules = 6.3e4 * (comb_mag * 1e6);

    return sol;
}
