# dsp_trigger.b: Recursive STA/LTA Triggering with Dynamic Thresholds in Limbo
implement DSPTrigger;

include "sys.m";
    sys: Sys;

include "dsp.m";
    dsp: SeismicDSP;

DSPTrigger: module
{
    PATH: con "/dis/dsp_trigger.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    create_trigger: fn(sta_s: real, lta_s: real, fs_hz: real, on_th: real, off_th: real): ref SeismicDSP->TriggerState;
    step_trigger:   fn(st: ref SeismicDSP->TriggerState, x: real, dx: real): (int, real);
    process_window: fn(st: ref SeismicDSP->TriggerState, samples: array of real, dt: real): (array of real, array of int);
};

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

create_trigger(sta_s: real, lta_s: real, fs_hz: real, on_th: real, off_th: real): ref SeismicDSP->TriggerState
{
    st := ref SeismicDSP->TriggerState;

    n_sta := sta_s * fs_hz;
    n_lta := lta_s * fs_hz;
    if (n_sta < 1.0) n_sta = 1.0;
    if (n_lta < 5.0) n_lta = 5.0;

    st.sta = 0.001;
    st.lta = 0.001;
    st.c_sta = 1.0 / n_sta;
    st.c_lta = 1.0 / n_lta;
    st.on_thresh = on_th;
    st.off_thresh = off_th;
    st.is_triggered = 0;
    st.trigger_idx = -1;

    return st;
}

step_trigger(st: ref SeismicDSP->TriggerState, x: real, dx: real): (int, real)
{
    if (st == nil) return (0, 0.0);

    # Characteristic Function CF = x^2 + 0.1 * (dx/dt)^2
    cf := x * x + 0.1 * dx * dx;

    st.sta = (1.0 - st.c_sta) * st.sta + st.c_sta * cf;
    st.lta = (1.0 - st.c_lta) * st.lta + st.c_lta * cf;

    ratio := 0.0;
    if (st.lta > 1e-12) {
        ratio = st.sta / st.lta;
    }

    event := 0;
    if (st.is_triggered == 0) {
        if (ratio >= st.on_thresh) {
            st.is_triggered = 1;
            event = 1; # New trigger onset
        }
    } else {
        if (ratio <= st.off_thresh) {
            st.is_triggered = 0;
            event = -1; # Detrigger
        }
    }

    return (event, ratio);
}

process_window(st: ref SeismicDSP->TriggerState, samples: array of real, dt: real): (array of real, array of int)
{
    if (samples == nil || len samples == 0) {
        return (array[0] of real, array[0] of int);
    }
    n := len samples;
    ratios := array[n] of real;
    events := array[n] of int;

    for (i := 0; i < n; i++) {
        dx := 0.0;
        if (i > 0 && dt > 0.0) {
            dx = (samples[i] - samples[i - 1]) / dt;
        }
        (evt, r) := step_trigger(st, samples[i], dx);
        ratios[i] = r;
        events[i] = evt;
        if (evt == 1 && st.trigger_idx < 0) {
            st.trigger_idx = i;
        }
    }

    return (ratios, events);
}
