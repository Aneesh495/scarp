# magnitude.m: Real-Time Magnitude Scaling Interface

MagnitudeEngine: module
{
    PATH: con "/dis/magnitude.dis";

    # Pd scaling parameters: M = a*log10(Pd) + b*log10(R) + c
    PdModel: adt {
        a: real;
        b: real;
        c: real;

        estimate: fn(m: self ref PdModel, pd_cm: real, dist_km: real): real;
    };

    # Tau_c scaling parameters: M = alpha*log10(tau_c) + beta
    TauCModel: adt {
        alpha: real;
        beta:  real;

        estimate: fn(m: self ref TauCModel, tau_c_s: real): real;
    };

    # Characteristic period computation from velocity and displacement
    compute_tau_c: fn(u: array of real, v: array of real, dt: real, win_len: int): real;

    # Bayesian Station Evidence Fusion
    fuse_magnitudes: fn(event_id: string,
                        pd_estimates: array of real,
                        tc_estimates: array of real,
                        station_weights: array of real): ref Scarp->MagnitudeSol;
};
