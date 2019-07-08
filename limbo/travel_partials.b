# travel_partials.b: Analytical Travel-Time Partial Derivatives in Limbo
implement TravelPartials;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "geiger.m";
    geiger: GeigerLocator;

JacobianRow: adt {
    dtdlat: real;
    dtdlon: real;
    dtdz:   real;
    dtdt0:  real;
};

TravelPartials: module
{
    PATH: con "/dis/travel_partials.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    calc_partials: fn(hypo_lat: real, hypo_lon: real, hypo_z_km: real,
                      sta_lat: real, sta_lon: real,
                      v_eff_kms: real): ref JacobianRow;
};

PI: con 3.141592653589793;
KM_PER_DEG_LAT: con 111.195;

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

calc_partials(hypo_lat: real, hypo_lon: real, hypo_z_km: real,
              sta_lat: real, sta_lon: real,
              v_eff_kms: real): ref JacobianRow
{
    if (v_eff_kms <= 0.0) v_eff_kms = 6.0;

    dlat := (sta_lat - hypo_lat) * KM_PER_DEG_LAT;
    mid_lat := (hypo_lat + sta_lat) * 0.5;
    cos_lat := 1.0 - (mid_lat * PI / 180.0) * (mid_lat * PI / 180.0) * 0.5;
    if (cos_lat < 0.1) cos_lat = 0.1;
    dlon := (sta_lon - hypo_lon) * KM_PER_DEG_LAT * cos_lat;

    epi_dist := sqrt_approx(dlat * dlat + dlon * dlon);
    dz := hypo_z_km;
    if (dz < 0.1) dz = 0.1;
    hypo_dist := sqrt_approx(epi_dist * epi_dist + dz * dz);

    row := ref JacobianRow;
    row.dtdt0 = 1.0;

    if (hypo_dist > 1e-4) {
        # dt/dx = -dlat / (v * D)
        # dt/dy = -dlon / (v * D)
        # dt/dz = dz / (v * D)
        dtdD := 1.0 / v_eff_kms;
        factor := dtdD / hypo_dist;

        row.dtdlat = -factor * dlat;
        row.dtdlon = -factor * dlon;
        row.dtdz   = factor * dz;
    } else {
        row.dtdlat = 0.0;
        row.dtdlon = 0.0;
        row.dtdz   = 1.0 / v_eff_kms;
    }

    return row;
}
