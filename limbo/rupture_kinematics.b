# rupture_kinematics.b: Kinematic Rupture Propagation and Isochrones in Limbo
implement RuptureKinematics;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "rupture.m";
    rupture: RuptureKinematics;

SubFaultElement: adt {
    xi_along_strike_km: real;
    t_rupture_s:        real;
    slip_m:             real;
    rise_time_s:        real;
};

RuptureKinematics: module
{
    PATH: con "/dis/rupture_kinematics.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    calc_isochrone_time: fn(hypo_lat: real, hypo_lon: real, hypo_depth_km: real,
                            rupture_dist_km: real, vr_kms: real,
                            site_lat: real, site_lon: real, vs_kms: real): real;

    discretize_line_source: fn(total_length_km: real, vr_kms: real, num_nodes: int): array of ref SubFaultElement;
};

PI: con 3.141592653589793;
KM_PER_DEG: con 111.195;

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

calc_isochrone_time(hypo_lat: real, hypo_lon: real, hypo_depth_km: real,
                    rupture_dist_km: real, vr_kms: real,
                    site_lat: real, site_lon: real, vs_kms: real): real
{
    if (vr_kms <= 0.0) vr_kms = 3.0;
    if (vs_kms <= 0.0) vs_kms = 3.5;

    # Time for rupture front to reach point on fault
    t_rup := rupture_dist_km / vr_kms;

    # Travel time for S-wave from fault point to site
    dlat := (site_lat - hypo_lat) * KM_PER_DEG;
    mid_lat := (hypo_lat + site_lat) * 0.5;
    cos_lat := 1.0 - (mid_lat * PI / 180.0) * (mid_lat * PI / 180.0) * 0.5;
    if (cos_lat < 0.1) cos_lat = 0.1;
    dlon := (site_lon - hypo_lon) * KM_PER_DEG * cos_lat;

    epi_dist := sqrt_approx(dlat * dlat + dlon * dlon);
    dz := hypo_depth_km;
    if (dz < 0.5) dz = 0.5;
    hypo_dist := sqrt_approx(epi_dist * epi_dist + dz * dz);

    t_wave := hypo_dist / vs_kms;

    return t_rup + t_wave;
}

discretize_line_source(total_length_km: real, vr_kms: real, num_nodes: int): array of ref SubFaultElement
{
    if (num_nodes <= 0) num_nodes = 10;
    if (vr_kms <= 0.0) vr_kms = 3.0;

    d_xi := total_length_km / real num_nodes;
    elements := array[num_nodes] of ref SubFaultElement;

    for (i := 0; i < num_nodes; i++) {
        elem := ref SubFaultElement;
        elem.xi_along_strike_km = (real i + 0.5) * d_xi;
        elem.t_rupture_s = elem.xi_along_strike_km / vr_kms;
        elem.slip_m = 1.2; # Nominal initial uniform slip
        elem.rise_time_s = 0.8;
        elements[i] = elem;
    }

    return elements;
}
