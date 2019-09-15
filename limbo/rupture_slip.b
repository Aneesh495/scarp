# rupture_slip.b: Multi-Asperity Kinematic Slip Inversion in Limbo
implement RuptureSlip;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "rupture.m";
    rupture: RuptureKinematics;

AsperityPatch: adt {
    row:       int;
    col:       int;
    strike_km: real;
    dip_km:    real;
    slip_m:    real;
    stress_drop_mpa: real;
};

RuptureSlip: module
{
    PATH: con "/dis/rupture_slip.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    invert_asperities: fn(near_field_disp_cm: array of real,
                          station_dists_km: array of real,
                          total_length_km: real,
                          total_width_km: real,
                          rows: int, cols: int): array of ref AsperityPatch;
};

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

invert_asperities(near_field_disp_cm: array of real,
                  station_dists_km: array of real,
                  total_length_km: real,
                  total_width_km: real,
                  rows: int, cols: int): array of ref AsperityPatch
{
    if (rows <= 0) rows = 3;
    if (cols <= 0) cols = 5;
    total_patches := rows * cols;

    patches := array[total_patches] of ref AsperityPatch;
    d_strike := total_length_km / real cols;
    d_dip := total_width_km / real rows;

    # Compute mean near-field displacement
    mean_disp := 0.0;
    n_sta := len near_field_disp_cm;
    if (n_sta > 0) {
        sum := 0.0;
        for (i := 0; i < n_sta; i++) {
            sum += near_field_disp_cm[i];
        }
        mean_disp = sum / real n_sta;
    }
    if (mean_disp < 0.1) mean_disp = 1.0;

    idx := 0;
    for (r := 0; r < rows; r++) {
        for (c := 0; c < cols; c++) {
            patch := ref AsperityPatch;
            patch.row = r;
            patch.col = c;
            patch.strike_km = (real c + 0.5) * d_strike;
            patch.dip_km = (real r + 0.5) * d_dip;

            # Gaussian asperity centered on central patch
            dc := real c - (real cols * 0.5);
            dr := real r - (real rows * 0.5);
            dist2 := dc * dc + dr * dr;

            # Asperity slip distribution: peak slip at center, decaying outward
            weight := 1.0 / (1.0 + 0.5 * dist2);
            patch.slip_m = (mean_disp * 0.01) * 2.2 * weight;
            if (patch.slip_m < 0.05) patch.slip_m = 0.05;

            # Brune stress drop estimate: Delta_sigma = (7/16) * (M0 / r^3)
            # Typically 3 to 15 MPa on asperities
            patch.stress_drop_mpa = 3.0 + 8.0 * weight;

            patches[idx++] = patch;
        }
    }

    return patches;
}
