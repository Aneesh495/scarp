# assoc_ghost.b: Outlier Rejection and Ghost Pick Filtering in Limbo
implement AssocGhost;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "assoc.m";
    assoc: PhaseAssoc;

AssocGhost: module
{
    PATH: con "/dis/assoc_ghost.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    is_isolated_pick: fn(target: ref Scarp->PhasePick,
                         all_picks: list of ref Scarp->PhasePick,
                         stations: list of ref Scarp->Station,
                         max_coincidence_s: real,
                         max_radius_km: real): int;

    filter_valid_picks: fn(raw_picks: list of ref Scarp->PhasePick,
                           stations: list of ref Scarp->Station,
                           min_snr: real): list of ref Scarp->PhasePick;
};

PI: con 3.141592653589793;
KM_PER_DEG: con 111.195;

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

distance_km(lat1: real, lon1: real, lat2: real, lon2: real): real
{
    dlat := (lat2 - lat1) * KM_PER_DEG;
    mid_lat := (lat1 + lat2) * 0.5;
    cos_lat := 1.0 - (mid_lat * PI / 180.0) * (mid_lat * PI / 180.0) * 0.5;
    if (cos_lat < 0.1) cos_lat = 0.1;
    dlon := (lon2 - lon1) * KM_PER_DEG * cos_lat;

    rad := dlat * dlat + dlon * dlon;
    if (rad <= 0.0) return 0.0;
    val := rad;
    for (i := 0; i < 6; i++) {
        val = 0.5 * (val + rad / val);
    }
    return val;
}

is_isolated_pick(target: ref Scarp->PhasePick,
                 all_picks: list of ref Scarp->PhasePick,
                 stations: list of ref Scarp->Station,
                 max_coincidence_s: real,
                 max_radius_km: real): int
{
    if (target == nil || all_picks == nil) return 1;

    # Find target station
    tgt_sta: ref Scarp->Station = nil;
    for (st := stations; st != nil; st = tl st) {
        if ((hd st).id == target.sta_id) {
            tgt_sta = hd st;
            break;
        }
    }
    if (tgt_sta == nil) return 1;

    neighbor_count := 0;
    for (cur := all_picks; cur != nil; cur = tl cur) {
        other := hd cur;
        if (other.sta_id == target.sta_id) continue;

        dt_us := other.time_us - target.time_us;
        if (dt_us < big 0) dt_us = -dt_us;
        dt_s := real dt_us / 1000000.0;

        if (dt_s <= max_coincidence_s) {
            # Find other station
            other_sta: ref Scarp->Station = nil;
            for (ost := stations; ost != nil; ost = tl ost) {
                if ((hd ost).id == other.sta_id) {
                    other_sta = hd ost;
                    break;
                }
            }

            if (other_sta != nil) {
                dist := distance_km(tgt_sta.lat, tgt_sta.lon, other_sta.lat, other_sta.lon);
                if (dist <= max_radius_km) {
                    neighbor_count++;
                }
            }
        }
    }

    # If supported by at least 2 neighboring stations, not isolated
    if (neighbor_count >= 2) return 0;
    return 1;
}

filter_valid_picks(raw_picks: list of ref Scarp->PhasePick,
                   stations: list of ref Scarp->Station,
                   min_snr: real): list of ref Scarp->PhasePick
{
    valid: list of ref Scarp->PhasePick = nil;
    for (cur := raw_picks; cur != nil; cur = tl cur) {
        p := hd cur;
        if (p.snr < min_snr) continue;

        if (is_isolated_pick(p, raw_picks, stations, 8.0, 150.0) == 0) {
            valid = p :: valid;
        }
    }
    return valid;
}
