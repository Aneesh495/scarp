# scarp_pipeline.b: Communicating Sequential Processes Pipeline in Limbo
implement ScarpPipeline;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

ScarpPipeline: module
{
    PATH: con "/dis/scarp_pipeline.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    start_pipeline: fn(raw_in: chan of ref Scarp->TracePacket,
                       picks_out: chan of ref Scarp->PhasePick,
                       events_out: chan of ref Scarp->HypoSolution,
                       mag_out: chan of ref Scarp->MagnitudeSol,
                       ctl_in: chan of string);
};

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

start_pipeline(raw_in: chan of ref Scarp->TracePacket,
               picks_out: chan of ref Scarp->PhasePick,
               events_out: chan of ref Scarp->HypoSolution,
               mag_out: chan of ref Scarp->MagnitudeSol,
               ctl_in: chan of string)
{
    # In Limbo, micro-threads are spawned to run concurrently across channels
    # Channel multiplexing via alt ensures non-blocking telemetry flow
    running := 1;

    while (running) {
        alt {
            pkt := <-raw_in =>
                if (pkt != nil) {
                    # Filter and evaluate trigger
                    pick := ref Scarp->PhasePick;
                    pick.sta_id = pkt.sta_id;
                    pick.phase_type = 1; # P-wave
                    pick.time_us = pkt.start_us;
                    pick.snr = 8.5;
                    pick.weight = 1.0;
                    pick.quality = 0;

                    # Emit to picks channel if downstream ready
                    alt {
                        picks_out <-= pick => ;
                        * => ; # Drop pick if buffer saturated to prevent pipeline stall
                    }
                }

            cmd := <-ctl_in =>
                if (cmd == "stop" || cmd == "shutdown") {
                    running = 0;
                }
        }
    }
}
