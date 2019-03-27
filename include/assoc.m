# assoc.m: Phase Association and Event Candidate Binding Interface

PhaseAssoc: module
{
    PATH: con "/dis/assoc.dis";

    # Candidate Event Cluster
    EventCluster: adt {
        cluster_id:  string;
        first_pick_us: big;
        picks:       list of ref Scarp->PhasePick;
        station_set: list of string;
        is_active:   int;

        add_pick: fn(c: self ref EventCluster, p: ref Scarp->PhasePick): int;
        station_count: fn(c: self ref EventCluster): int;
    };

    # Equal Differential Time (EDT) evaluation
    edt_residual: fn(p1: ref Scarp->PhasePick, p2: ref Scarp->PhasePick,
                     s1: ref Scarp->Station, s2: ref Scarp->Station,
                     test_lat: real, test_lon: real, test_depth_km: real,
                     vp_kms: real): real;

    # Cluster association engine
    assoc_pick: fn(pick: ref Scarp->PhasePick, station: ref Scarp->Station,
                   clusters: list of ref EventCluster,
                   max_dt_s: real, vp_kms: real): ref EventCluster;

    # Ghost pick rejection (spurious spikes / electronic noise)
    filter_ghost_picks: fn(picks: list of ref Scarp->PhasePick, min_neighbors: int): list of ref Scarp->PhasePick;
};
