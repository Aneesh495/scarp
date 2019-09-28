# shakemap_grid.b: 2D Spatial Grid Rasterization in Limbo
implement ShakeMapGrid;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "shakemap.m";
    shakemap: ShakeMapEngine;

ShakeMapGrid: module
{
    PATH: con "/dis/shakemap_grid.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    estimate_vs30_from_topo: fn(lat: real, lon: real): real;
    populate_grid:           fn(hypo_lat: real, hypo_lon: real, hypo_z: real,
                                mw: real,
                                lat_min: real, lat_max: real,
                                lon_min: real, lon_max: real,
                                step_deg: real): list of ref Scarp->ShakeMapCell;
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

estimate_vs30_from_topo(lat: real, lon: real): real
{
    # Proxy model: higher latitudes / inland mountains have steeper gradients
    # coastal plains and central valleys have softer sediments
    base_vs := 450.0;
    # Synthetic variation based on coordinates
    var_factor := (lat - 34.0) * 40.0 + (lon + 118.0) * 30.0;
    vs := base_vs + var_factor;
    if (vs < 220.0) vs = 220.0; # Basin sediments
    if (vs > 850.0) vs = 850.0; # Crystalline mountain rock
    return vs;
}

populate_grid(hypo_lat: real, hypo_lon: real, hypo_z: real,
              mw: real,
              lat_min: real, lat_max: real,
              lon_min: real, lon_max: real,
              step_deg: real): list of ref Scarp->ShakeMapCell
{
    cells: list of ref Scarp->ShakeMapCell = nil;
    if (step_deg <= 0.0) step_deg = 0.1;

    for (lat := lat_min; lat <= lat_max; lat += step_deg) {
        for (lon := lon_min; lon <= lon_max; lon += step_deg) {
            dlat := (lat - hypo_lat) * KM_PER_DEG;
            mid_lat := (hypo_lat + lat) * 0.5;
            cos_lat := 1.0 - (mid_lat * PI / 180.0) * (mid_lat * PI / 180.0) * 0.5;
            if (cos_lat < 0.1) cos_lat = 0.1;
            dlon := (lon - hypo_lon) * KM_PER_DEG * cos_lat;

            epi_dist := sqrt_approx(dlat * dlat + dlon * dlon);
            r_rup := sqrt_approx(epi_dist * epi_dist + hypo_z * hypo_z);
            if (r_rup < 1.0) r_rup = 1.0;

            vs30 := estimate_vs30_from_topo(lat, lon);

            cell := ref Scarp->ShakeMapCell;
            cell.lat = lat;
            cell.lon = lon;

            # Attenuation approximation for grid cells
            pga := (mw * 12.0) / (1.0 + 0.08 * r_rup);
            pgv := (mw * 8.0) / (1.0 + 0.06 * r_rup);

            if (pga < 0.1) pga = 0.1;
            if (pga > 200.0) pga = 200.0;

            cell.pga_pct_g = pga;
            cell.pgv_cms = pgv;
            cell.psa_03s = pga * 1.7;
            cell.psa_10s = pga * 0.85;
            cell.psa_30s = pga * 0.22;

            # S-wave arrival travel time: r_rup / 3.5 km/s
            cell.tti_seconds = r_rup / 3.5;

            # MMI estimate
            cell.mmi = 3.0 + (mw - 4.5) * 1.1 - 1.5 * (r_rup / 50.0);
            if (cell.mmi < 1.0) cell.mmi = 1.0;
            if (cell.mmi > 10.0) cell.mmi = 10.0;

            cells = cell :: cells;
        }
    }

    return cells;
}
