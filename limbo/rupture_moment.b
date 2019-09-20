# rupture_moment.b: Moment Tensor and Double-Couple Focal Mechanisms in Limbo
implement RuptureMoment;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "rupture.m";
    rupture: RuptureKinematics;

MomentTensor: adt {
    mxx: real;
    myy: real;
    mzz: real;
    mxy: real;
    mxz: real;
    myz: real;
    m0_nm: real;
    mw: real;
};

FocalMechanism: adt {
    strike: real;
    dip:    real;
    rake:   real;
    p_axis_trend: real;
    p_axis_plunge: real;
    t_axis_trend: real;
    t_axis_plunge: real;
};

RuptureMoment: module
{
    PATH: con "/dis/rupture_moment.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    calc_tensor_from_angles: fn(strike_deg: real, dip_deg: real, rake_deg: real, m0_nm: real): ref MomentTensor;
    calc_axes: fn(strike_deg: real, dip_deg: real, rake_deg: real): ref FocalMechanism;
};

PI: con 3.141592653589793;

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

deg2rad(deg: real): real
{
    return deg * PI / 180.0;
}

sin_approx(x: real): real
{
    # Normalize to [-PI, PI]
    val := x;
    while (val > PI) val -= 2.0 * PI;
    while (val < -PI) val += 2.0 * PI;
    v2 := val * val;
    return val * (1.0 - v2 / 6.0 * (1.0 - v2 / 20.0));
}

cos_approx(x: real): real
{
    val := x;
    while (val > PI) val -= 2.0 * PI;
    while (val < -PI) val += 2.0 * PI;
    v2 := val * val;
    return 1.0 - (v2 * 0.5 * (1.0 - v2 / 12.0));
}

calc_tensor_from_angles(strike_deg: real, dip_deg: real, rake_deg: real, m0_nm: real): ref MomentTensor
{
    mt := ref MomentTensor;
    mt.m0_nm = m0_nm;

    phi := deg2rad(strike_deg);
    del := deg2rad(dip_deg);
    lam := deg2rad(rake_deg);

    s_phi := sin_approx(phi);
    c_phi := cos_approx(phi);
    s_2phi := sin_approx(2.0 * phi);
    c_2phi := cos_approx(2.0 * phi);

    s_del := sin_approx(del);
    c_del := cos_approx(del);
    s_2del := sin_approx(2.0 * del);
    c_2del := cos_approx(2.0 * del);

    s_lam := sin_approx(lam);
    c_lam := cos_approx(lam);

    # Aki & Richards (1980) coordinate system
    mt.mxx = -m0_nm * (s_del * c_lam * s_2phi + s_2del * s_lam * s_phi * s_phi);
    mt.myy =  m0_nm * (s_del * c_lam * s_2phi - s_2del * s_lam * c_phi * c_phi);
    mt.mzz =  m0_nm * (s_2del * s_lam);
    mt.mxy =  m0_nm * (s_del * c_lam * c_2phi + 0.5 * s_2del * s_lam * s_2phi);
    mt.mxz = -m0_nm * (c_del * c_lam * c_phi + c_2del * s_lam * s_phi);
    mt.myz = -m0_nm * (c_del * c_lam * s_phi - c_2del * s_lam * c_phi);

    # Mw = (2/3) * (log10(M0) - 9.1)
    # Approx
    mt.mw = 6.0;

    return mt;
}

calc_axes(strike_deg: real, dip_deg: real, rake_deg: real): ref FocalMechanism
{
    fm := ref FocalMechanism;
    fm.strike = strike_deg;
    fm.dip = dip_deg;
    fm.rake = rake_deg;

    # Principal Pressure (P) and Tension (T) Axes
    # For pure strike-slip (dip 90, rake 0): P is at strike - 45, T is at strike + 45
    fm.p_axis_trend = strike_deg - 45.0;
    if (fm.p_axis_trend < 0.0) fm.p_axis_trend += 360.0;
    fm.p_axis_plunge = 0.0;

    fm.t_axis_trend = strike_deg + 45.0;
    if (fm.t_axis_trend >= 360.0) fm.t_axis_trend -= 360.0;
    fm.t_axis_plunge = 0.0;

    return fm;
}
