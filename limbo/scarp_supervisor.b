# scarp_supervisor.b: Channel Backpressure Watchdog and Supervisor in Limbo
implement ScarpSupervisor;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

SupervisorStats: adt {
    total_packets:     big;
    dropped_packets:   big;
    active_workers:    int;
    backpressure_mode: int;
    last_ping_ms:      int;
};

ScarpSupervisor: module
{
    PATH: con "/dis/scarp_supervisor.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    create_supervisor: fn(): ref SupervisorStats;
    check_watermark:   fn(st: ref SupervisorStats, queue_len: int, queue_cap: int): int;
    record_packet:     fn(st: ref SupervisorStats, dropped: int);
};

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

create_supervisor(): ref SupervisorStats
{
    st := ref SupervisorStats;
    st.total_packets = big 0;
    st.dropped_packets = big 0;
    st.active_workers = 4;
    st.backpressure_mode = 0;
    st.last_ping_ms = 0;
    return st;
}

check_watermark(st: ref SupervisorStats, queue_len: int, queue_cap: int): int
{
    if (st == nil || queue_cap <= 0) return 0;

    utilization := real queue_len / real queue_cap;

    # High watermark: 85% queue capacity
    if (utilization >= 0.85) {
        st.backpressure_mode = 1; # Enable load shedding
        return 1;
    }

    # Low watermark: 40% queue capacity to exit backpressure mode
    if (utilization <= 0.40) {
        st.backpressure_mode = 0;
        return 0;
    }

    return st.backpressure_mode;
}

record_packet(st: ref SupervisorStats, dropped: int)
{
    if (st == nil) return;
    st.total_packets += big 1;
    if (dropped != 0) {
        st.dropped_packets += big 1;
    }
}
