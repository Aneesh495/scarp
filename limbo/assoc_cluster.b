# assoc_cluster.b: Spatial-Temporal Phase Clustering and Candidate Binding in Limbo
implement AssocCluster;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "assoc.m";
    assoc: PhaseAssoc;

ClusterState: adt {
    cluster_id:    string;
    first_time_us: big;
    last_time_us:  big;
    picks:         list of ref Scarp->PhasePick;
    station_count: int;
    is_declared:   int;
};

AssocCluster: module
{
    PATH: con "/dis/assoc_cluster.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    create_cluster: fn(id: string, initial_pick: ref Scarp->PhasePick): ref ClusterState;
    can_bind_pick:  fn(cl: ref ClusterState, p: ref Scarp->PhasePick,
                       s_cand: ref Scarp->Station,
                       stations: list of ref Scarp->Station,
                       v_apparent_kms: real, max_dt_s: real): int;
    add_pick:       fn(cl: ref ClusterState, p: ref Scarp->PhasePick);
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

create_cluster(id: string, initial_pick: ref Scarp->PhasePick): ref ClusterState
{
    cl := ref ClusterState;
    cl.cluster_id = id;
    cl.first_time_us = initial_pick.time_us;
    cl.last_time_us = initial_pick.time_us;
    cl.picks = initial_pick :: nil;
    cl.station_count = 1;
    cl.is_declared = 0;
    return cl;
}

can_bind_pick(cl: ref ClusterState, p: ref Scarp->PhasePick,
              s_cand: ref Scarp->Station,
              stations: list of ref Scarp->Station,
              v_apparent_kms: real, max_dt_s: real): int
{
    if (cl == nil || p == nil || s_cand == nil) return 0;
    if (v_apparent_kms <= 0.0) v_apparent_kms = 4.5; # Slower apparent velocity for safety

    # Check temporal window relative to cluster origin
    dt_us := p.time_us - cl.first_time_us;
    if (dt_us < big 0) dt_us = -dt_us;
    dt_s := real dt_us / 1000000.0;
    if (dt_s > max_dt_s) return 0;

    # Verify physical travel-time compatibility against existing cluster picks
    for (cur := cl.picks; cur != nil; cur = tl cur) {
        existing_pick := hd cur;
        if (existing_pick.sta_id == p.sta_id && existing_pick.phase_type == p.phase_type) {
            # Duplicate pick for same station and phase
            return 0;
        }

        # Find existing station metadata
        s_exist: ref Scarp->Station = nil;
        for (st := stations; st != nil; st = tl st) {
            if ((hd st).id == existing_pick.sta_id) {
                s_exist = hd st;
                break;
            }
        }

        if (s_exist != nil) {
            inter_dist := distance_km(s_cand.lat, s_cand.lon, s_exist.lat, s_exist.lon);
            max_moveout := (inter_dist / v_apparent_kms) + 2.5; # Margin for depth differences

            p_dt_us := p.time_us - existing_pick.time_us;
            if (p_dt_us < big 0) p_dt_us = -p_dt_us;
            moveout_s := real p_dt_us / 1000000.0;

            if (moveout_s > max_moveout) {
                return 0; # Incompatible moveout; separate event
            }
        }
    }

    return 1;
}

add_pick(cl: ref ClusterState, p: ref Scarp->PhasePick)
{
    if (cl == nil || p == nil) return;
    cl.picks = p :: cl.picks;
    cl.station_count++;
    if (p.time_us > cl.last_time_us) {
        cl.last_time_us = p.time_us;
    }
    if (p.time_us < cl.first_time_us) {
        cl.first_time_us = p.time_us;
    }
}
