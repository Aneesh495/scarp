# magnitude_energy.b: Seismic Moment and Radiated Energy Budget in Limbo
implement MagnitudeEnergy;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "magnitude.m";
    magnitude: MagnitudeEngine;

EnergyBudget: adt {
    mw:             real;
    moment_nm:      real; # Seismic Moment M0 (Newton-meters)
    energy_joules:  real; # Radiated seismic energy Es (Joules)
    tnt_equivalent: real; # Metric tons of TNT equivalent
    rupture_area_km2: real; # Estimated fault rupture area
};

MagnitudeEnergy: module
{
    PATH: con "/dis/magnitude_energy.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    calc_budget: fn(mw: real): ref EnergyBudget;
};

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

pow10_approx(x: real): real
{
    # 10^x = e^(x * 2.30258509)
    # Decompose x into integer k and fraction f
    k := int x;
    if (real k > x) k--;
    f := x - real k;

    # e^(f * 2.302585) using Taylor series
    u := f * 2.302585092994046;
    e_f := 1.0 + u * (1.0 + u * 0.5 * (1.0 + u / 3.0 * (1.0 + u * 0.25)));

    res := e_f;
    if (k > 0) {
        for (i := 0; i < k; i++) res *= 10.0;
    } else if (k < 0) {
        for (i = 0; i < -k; i++) res /= 10.0;
    }
    return res;
}

calc_budget(mw: real): ref EnergyBudget
{
    eb := ref EnergyBudget;
    eb.mw = mw;

    # Seismic Moment: log10(M0) = 1.5 * Mw + 9.05 (Hanks & Kanamori 1979)
    log_m0 := 1.5 * mw + 9.05;
    # Prevent overflow in 64-bit float by capping at M9.5
    if (log_m0 > 23.0) log_m0 = 23.0;
    eb.moment_nm = pow10_approx(log_m0);

    # Radiated Energy: log10(Es) = 1.5 * Mw + 4.8 (Joules)
    log_es := 1.5 * mw + 4.8;
    if (log_es > 19.0) log_es = 19.0;
    eb.energy_joules = pow10_approx(log_es);

    # 1 metric ton TNT = 4.184e9 Joules
    eb.tnt_equivalent = eb.energy_joules / 4.184e9;

    # Wells & Coppersmith (1994) Rupture Area scaling: log10(Area) = Mw - 4.0
    log_area := mw - 4.0;
    if (log_area < 0.0) log_area = 0.0;
    eb.rupture_area_km2 = pow10_approx(log_area);

    return eb;
}
