# rupture_fault.b: Planar Fault Geometry and Distance Metrics in Limbo
implement RuptureFault;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "rupture.m";
    rupture: RuptureKinematics;

FaultPlane: adt {
    strike_deg: real;
    dip_deg:    real;
    rake_deg:   real;
    length_km:  real;
    width_km:   real;
    ztor_km:    real; # Depth to top of rupture
    hypo_along_strike_km: real;
    hypo_down_dip_km:     real;
};

RuptureFault: module
{
    PATH: con "/dis/rupture_fault.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    create_fault: fn(strike: real, dip: real, rake: real, length_km: real, width_km: real, ztor_km: real): ref FaultPlane;
    calc_rjb_and_rrup: fn(fp: ref FaultPlane, hypo_lat: real, hypo_lon: real, hypo_z: real,
                          site_lat: real, site_lon: real): (real, real);
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

create_fault(strike: real, dip: real, rake: real, length_km: real, width_km: real, ztor_km: real): ref FaultPlane
{
    fp := ref FaultPlane;
    fp.strike_deg = strike;
    fp.dip_deg = dip;
    fp.rake_deg = rake;
    fp.length_km = (length_km > 1.0 ? length_km : 10.0);
    fp.width_km = (width_km > 1.0 ? width_km : 8.0);
    fp.ztor_km = (ztor_km >= 0.0 ? ztor_km : 1.0);
    fp.hypo_along_strike_km = fp.length_km * 0.5; # Centered nucleation
    fp.hypo_down_dip_km = fp.width_km * 0.8;      # Nucleate in lower third
    return fp;
}

calc_rjb_and_rrup(fp: ref FaultPlane, hypo_lat: real, hypo_lon: real, hypo_z: real,
                  site_lat: real, site_lon: real): (real, real)
{
    dlat := (site_lat - hypo_lat) * KM_PER_DEG;
    mid_lat := (hypo_lat + site_lat) * 0.5;
    cos_lat := 1.0 - (mid_lat * PI / 180.0) * (mid_lat * PI / 180.0) * 0.5;
    if (cos_lat < 0.1) cos_lat = 0.1;
    dlon := (site_lon - hypo_lon) * KM_PER_DEG * cos_lat;

    epi_dist := sqrt_approx(dlat * dlat + dlon * dlon);

    # Approximate Joyner-Boore distance Rjb
    # Point source distance minus half rupture dimension projection
    half_l := (fp != nil ? fp.length_km * 0.5 : 5.0);
    rjb := epi_dist - half_l * 0.6;
    if (rjb < 0.0) rjb = 0.0;

    # Closest 3D distance to rupture plane Rrup
    eff_z := (fp != nil ? fp.ztor_km : hypo_z);
    if (hypo_z > eff_z && hypo_z < eff_z + 10.0) eff_z = hypo_z;
    rrup := sqrt_approx(rjb * rjb + eff_z * eff_z);

    return (rjb, rrup);
}
