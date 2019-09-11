# rupture_directivity.b: Doppler Directivity Focusing in Limbo
implement RuptureDirectivity;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "rupture.m";
    rupture: RuptureKinematics;

RuptureDirectivity: module
{
    PATH: con "/dis/rupture_directivity.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    calc_directivity_factor: fn(hypo_lat: real, hypo_lon: real,
                                fault_strike_deg: real,
                                site_lat: real, site_lon: real,
                                v_rupture_kms: real, v_shear_kms: real): real;

    scale_pga_for_directivity: fn(base_pga: real, directivity_cd: real): real;
};

PI: con 3.141592653589793;
KM_PER_DEG: con 111.195;

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

atan2_approx(y: real, x: real): real
{
    if (x == 0.0) {
        return (y > 0.0 ? PI * 0.5 : -PI * 0.5);
    }
    ratio := y / x;
    atan_val := ratio / (1.0 + 0.28 * ratio * ratio);
    if (x < 0.0) {
        atan_val += (y >= 0.0 ? PI : -PI);
    }
    return atan_val;
}

cos_deg_approx(deg: real): real
{
    # Normalize to [-180, 180]
    while (deg > 180.0) deg -= 360.0;
    while (deg < -180.0) deg += 360.0;
    rad := deg * PI / 180.0;
    return 1.0 - (rad * rad * 0.5) + (rad * rad * rad * rad / 24.0);
}

calc_directivity_factor(hypo_lat: real, hypo_lon: real,
                        fault_strike_deg: real,
                        site_lat: real, site_lon: real,
                        v_rupture_kms: real, v_shear_kms: real): real
{
    if (v_shear_kms <= 0.0) v_shear_kms = 3.5;
    if (v_rupture_kms <= 0.0) v_rupture_kms = 0.85 * v_shear_kms;

    # Azimuth from hypocenter to site
    dlat := (site_lat - hypo_lat) * KM_PER_DEG;
    mid_lat := (hypo_lat + site_lat) * 0.5;
    cos_lat := 1.0 - (mid_lat * PI / 180.0) * (mid_lat * PI / 180.0) * 0.5;
    if (cos_lat < 0.1) cos_lat = 0.1;
    dlon := (site_lon - hypo_lon) * KM_PER_DEG * cos_lat;

    site_az_rad := atan2_approx(dlon, dlat); # Azimuth clockwise from North
    site_az_deg := site_az_rad * 180.0 / PI;
    if (site_az_deg < 0.0) site_az_deg += 360.0;

    # Angle theta between rupture propagation direction (strike) and ray to site
    theta_deg := site_az_deg - fault_strike_deg;

    cos_theta := cos_deg_approx(theta_deg);
    if (cos_theta > 1.0) cos_theta = 1.0;
    if (cos_theta < -1.0) cos_theta = -1.0;

    mach := v_rupture_kms / v_shear_kms; # Mach number ~0.85
    denom := 1.0 - mach * cos_theta;
    if (denom < 0.15) denom = 0.15; # Physical saturation preventing singularity

    c_d := 1.0 / denom;

    # Bound factor between backward directivity (0.5) and forward directivity (4.5)
    if (c_d < 0.5) c_d = 0.5;
    if (c_d > 4.5) c_d = 4.5;

    return c_d;
}

scale_pga_for_directivity(base_pga: real, directivity_cd: real): real
{
    # Log-linear directivity amplification factor
    # PGA_scaled = PGA_base * (Cd)^0.4
    factor := 1.0 + 0.35 * (directivity_cd - 1.0);
    if (factor < 0.6) factor = 0.6;
    if (factor > 2.5) factor = 2.5;

    return base_pga * factor;
}
