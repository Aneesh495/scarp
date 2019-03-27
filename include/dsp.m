# dsp.m: Seismic Digital Signal Processing Module Interface

SeismicDSP: module
{
    PATH: con "/dis/dsp.dis";

    # Butterworth 2nd and 4th order filter state
    FilterState: adt {
        order: int;
        a:     array of real;
        b:     array of real;
        x_buf: array of real;
        y_buf: array of real;

        create: fn(order: int, fl_hz: real, fh_hz: real, fs_hz: real): ref FilterState;
        filter_sample: fn(s: self ref FilterState, x: real): real;
        filter_array: fn(s: self ref FilterState, input: array of real): array of real;
        reset: fn(s: self ref FilterState);
    };

    # Recursive STA/LTA Detector State
    TriggerState: adt {
        sta:          real;
        lta:          real;
        c_sta:        real;    # Decay constant for short-term window
        c_lta:        real;    # Decay constant for long-term window
        on_thresh:    real;    # Trigger threshold (e.g. 5.0)
        off_thresh:   real;    # Detrigger threshold (e.g. 1.5)
        is_triggered: int;
        trigger_idx:  int;

        create: fn(sta_len_s: real, lta_len_s: real, fs_hz: real, on_th: real, off_th: real): ref TriggerState;
        process_sample: fn(s: self ref TriggerState, x: real, dx: real): int;
        ratio: fn(s: self ref TriggerState): real;
        reset: fn(s: self ref TriggerState);
    };

    # Kurtosis Onset Refiner
    kurtosis_gradient_pick: fn(samples: array of real, win_len: int, start_idx: int) : int;

    # Baseline correction and high-pass filtering
    remove_baseline_drift: fn(samples: array of real, alpha: real): array of real;

    # Integration from acceleration to velocity and displacement
    trapezoidal_integrate: fn(samples: array of real, dt: real, fl_hz: real): array of real;

    # Peak Ground Velocity / Displacement extraction
    extract_peak_metrics: fn(acc: array of real, dt: real, win_len: int): (real, real, real);
};
