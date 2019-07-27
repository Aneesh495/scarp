# geiger_depth.b: Depth-Freezing and Air-Quake Penalty Constraints in Limbo
implement GeigerDepth;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "geiger.m";
    geiger: GeigerLocator;

GeigerDepth: module
{
    PATH: con "/dis/geiger_depth.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    should_freeze_depth: fn(min_sta_dist_km: real, current_depth_km: real, num_stations: int): int;
    apply_air_quake_penalty: fn(depth_km: real, min_allowed_depth_km: real): (real, real);
    clamp_depth_update: fn(current_z: real, delta_z: real, min_z: real, max_z: real): real;
};

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

should_freeze_depth(min_sta_dist_km: real, current_depth_km: real, num_stations: int): int
{
    # Rule 1: If station network is too sparse (< 5 stations), depth resolution is weak
    if (num_stations < 5) return 1;

    # Rule 2: If the closest station is farther than 2x the focal depth, trade-off with t0 is severe
    if (min_sta_dist_km > (2.0 * current_depth_km) && min_sta_dist_km > 30.0) {
        return 1;
    }

    return 0;
}

apply_air_quake_penalty(depth_km: real, min_allowed_depth_km: real): (real, real)
{
    if (depth_km >= min_allowed_depth_km) {
        return (0.0, 0.0); # In valid physical zone; no penalty
    }

    # Barrier penalty function: P(z) = k * (z_min - z)^2
    dz := min_allowed_depth_km - depth_km;
    k_penalty := 50.0;

    penalty_val := 0.5 * k_penalty * dz * dz;
    gradient_val := -k_penalty * dz; # Directs search back toward positive depth

    return (penalty_val, gradient_val);
}

clamp_depth_update(current_z: real, delta_z: real, min_z: real, max_z: real): real
{
    # Clamp step size to avoid numerical oscillation
    step := delta_z;
    if (step > 15.0) step = 15.0;
    if (step < -15.0) step = -15.0;

    new_z := current_z + step;
    if (new_z < min_z) new_z = min_z;
    if (new_z > max_z) new_z = max_z;

    return new_z;
}
