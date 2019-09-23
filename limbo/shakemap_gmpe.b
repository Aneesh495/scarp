# shakemap_gmpe.b: Ground Motion Prediction Equations (GMPE) in Limbo
implement ShakeMapGMPE;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "shakemap.m";
    shakemap: ShakeMapEngine;

IntensityBundle: adt {
    pga_pct_g: real;
    pgv_cms:   real;
    psa_03s:   real;
    psa_10s:   real;
    psa_30s:   real;
};

ShakeMapGMPE: module
{
    PATH: con "/dis/shakemap_gmpe.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    calc_gmpe: fn(mw: real, r_rup_km: real, vs30_ms: real, mechanism: int): ref IntensityBundle;
};

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

ln_approx(x: real): real
{
    if (x <= 1e-12) return -27.6;
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
    return ln_val + real k * 0.6931471805599453;
}

exp_approx(x: real): real
{
    # Exponent approximation for [-15, 10]
    val := x;
    if (val < -15.0) return 0.0;
    if (val > 8.0) val = 8.0;

    # Decompose into integer and fraction
    k := int val;
    if (real k > val) k--;
    f := val - real k;

    # e^f via Taylor expansion
    e_f := 1.0 + f * (1.0 + f * 0.5 * (1.0 + f / 3.0 * (1.0 + f * 0.25)));

    res := e_f;
    e1 := 2.718281828459045;
    if (k > 0) {
        for (i := 0; i < k; i++) res *= e1;
    } else if (k < 0) {
        for (i = 0; i < -k; i++) res /= e1;
    }
    return res;
}

calc_gmpe(mw: real, r_rup_km: real, vs30_ms: real, mechanism: int): ref IntensityBundle
{
    ib := ref IntensityBundle;

    r := r_rup_km;
    if (r < 1.0) r = 1.0;
    vs := vs30_ms;
    if (vs < 150.0) vs = 150.0;
    if (vs > 1800.0) vs = 1800.0;

    # 1. Magnitude Scaling (BSSA14 style)
    mh := 6.0;
    dm := mw - mh;
    f_mag_pga := -0.55 + (mw <= mh ? (0.80 * dm + 0.10 * dm * dm) : (0.45 * dm));
    f_mag_pgv := 1.20 + (mw <= mh ? (1.05 * dm + 0.08 * dm * dm) : (0.70 * dm));

    # 2. Geometrical Spreading and Anelastic Attenuation
    # Effective pseudo-depth h = 4.5 km
    r_eff := r + 4.5;
    f_dist_pga := (-1.15 + 0.12 * (mw - 4.5)) * ln_approx(r_eff) - 0.0065 * r;
    f_dist_pgv := (-1.05 + 0.10 * (mw - 4.5)) * ln_approx(r_eff) - 0.0035 * r;

    # 3. Site Amplification
    f_site_pga := -0.45 * ln_approx(vs / 760.0);
    f_site_pgv := -0.65 * ln_approx(vs / 760.0);

    # 4. Focal mechanism adjustment (Reverse faults radiate ~20% higher PGA)
    mech_adj := 0.0;
    if (mechanism == 2) {
        mech_adj = 0.18; # Reverse faulting
    } else if (mechanism == 1) {
        mech_adj = -0.10; # Normal faulting
    }

    ln_pga := f_mag_pga + f_dist_pga + f_site_pga + mech_adj;
    ln_pgv := f_mag_pgv + f_dist_pgv + f_site_pgv + mech_adj;

    # Convert to %g and cm/s
    ib.pga_pct_g = exp_approx(ln_pga) * 100.0;
    ib.pgv_cms = exp_approx(ln_pgv);

    if (ib.pga_pct_g < 0.01) ib.pga_pct_g = 0.01;
    if (ib.pga_pct_g > 300.0) ib.pga_pct_g = 300.0;

    if (ib.pgv_cms < 0.01) ib.pgv_cms = 0.01;
    if (ib.pgv_cms > 250.0) ib.pgv_cms = 250.0;

    # Spectral accelerations
    ib.psa_03s = ib.pga_pct_g * 1.8;
    ib.psa_10s = ib.pga_pct_g * 0.9;
    ib.psa_30s = ib.pga_pct_g * 0.25;

    return ib;
}
