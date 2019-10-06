# shakemap_tti.b: S-Wave Wavefront and Time-to-Impact Countdown in Limbo
implement ShakeMapTTI;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "shakemap.m";
    shakemap: ShakeMapEngine;

WarningTarget: adt {
    name:         string;
    lat:          real;
    lon:          real;
    distance_km:  real;
    tti_seconds:  real;
    expected_mmi: real;
    is_alerted:   int;
};

ShakeMapTTI: module
{
    PATH: con "/dis/shakemap_tti.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    calc_blind_zone_radius: fn(alert_latency_s: real, vs_kms: real): real;
    eval_target_warning:    fn(hypo: ref Scarp->HypoSolution,
                               mag: ref Scarp->MagnitudeSol,
                               target_name: string,
                               target_lat: real, target_lon: real,
                               current_time_us: big,
                               vs_kms: real): ref WarningTarget;
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

calc_blind_zone_radius(alert_latency_s: real, vs_kms: real): real
{
    if (vs_kms <= 0.0) vs_kms = 3.5;
    if (alert_latency_s < 0.0) alert_latency_s = 0.0;
    return alert_latency_s * vs_kms;
}

eval_target_warning(hypo: ref Scarp->HypoSolution,
                    mag: ref Scarp->MagnitudeSol,
                    target_name: string,
                    target_lat: real, target_lon: real,
                    current_time_us: big,
                    vs_kms: real): ref WarningTarget
{
    wt := ref WarningTarget;
    wt.name = target_name;
    wt.lat = target_lat;
    wt.lon = target_lon;

    if (hypo == nil) {
        wt.distance_km = 0.0;
        wt.tti_seconds = 0.0;
        wt.expected_mmi = 1.0;
        wt.is_alerted = 0;
        return wt;
    }

    if (vs_kms <= 0.0) vs_kms = 3.5;

    # Distance to target
    dlat := (target_lat - hypo.lat) * KM_PER_DEG;
    mid_lat := (hypo.lat + target_lat) * 0.5;
    cos_lat := 1.0 - (mid_lat * PI / 180.0) * (mid_lat * PI / 180.0) * 0.5;
    if (cos_lat < 0.1) cos_lat = 0.1;
    dlon := (target_lon - hypo.lon) * KM_PER_DEG * cos_lat;

    epi_dist := sqrt_approx(dlat * dlat + dlon * dlon);
    hypo_dist := sqrt_approx(epi_dist * epi_dist + hypo.depth_km * hypo.depth_km);
    wt.distance_km = epi_dist;

    # Time elapsed since earthquake origin
    elapsed_us := current_time_us - hypo.origin_time_us;
    elapsed_s := real elapsed_us / 1000000.0;

    # S-wave travel time to target
    s_arrival_s := hypo_dist / vs_kms;

    wt.tti_seconds = s_arrival_s - elapsed_s;

    # Expected Intensity calculation
    mw := (mag != nil ? mag.mag_mw : 5.0);
    wt.expected_mmi = 3.0 + (mw - 4.5) * 1.1 - 1.5 * (hypo_dist / 50.0);
    if (wt.expected_mmi < 1.0) wt.expected_mmi = 1.0;
    if (wt.expected_mmi > 10.0) wt.expected_mmi = 10.0;

    # Alert condition: warning is active if TTI > 0 and expected shaking is perceptible (MMI >= 3.0)
    if (wt.tti_seconds > 0.0 && wt.expected_mmi >= 3.0) {
        wt.is_alerted = 1;
    } else {
        wt.is_alerted = 0;
    }

    return wt;
}
