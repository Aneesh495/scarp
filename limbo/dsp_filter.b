# dsp_filter.b: Causal Butterworth Filter and Baseline Correction in Limbo
implement DSPFilter;

include "sys.m";
    sys: Sys;

include "dsp.m";
    dsp: SeismicDSP;

DSPFilter: module
{
    PATH: con "/dis/dsp_filter.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    create_bandpass: fn(fl_hz: real, fh_hz: real, fs_hz: real): ref SeismicDSP->FilterState;
    filter_sample:   fn(st: ref SeismicDSP->FilterState, x: real): real;
    filter_series:   fn(st: ref SeismicDSP->FilterState, in_arr: array of real): array of real;
    remove_drift:    fn(in_arr: array of real, alpha: real): array of real;
};

PI: con 3.141592653589793;

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

create_bandpass(fl_hz: real, fh_hz: real, fs_hz: real): ref SeismicDSP->FilterState
{
    st := ref SeismicDSP->FilterState;
    st.order = 4;
    st.b = array[5] of real;
    st.a = array[5] of real;
    st.x_buf = array[5] of real;
    st.y_buf = array[5] of real;

    # Pre-warped cutoff calculation
    w1 := 2.0 * fs_hz * (fl_hz * PI / fs_hz); # Small angle approx for tan
    w2 := 2.0 * fs_hz * (fh_hz * PI / fs_hz);
    bw := w2 - w1;
    if (bw < 0.01) bw = 0.01;
    w0 := (fl_hz + fh_hz) * PI / fs_hz;

    q := w0 / bw;
    if (q < 0.5) q = 0.5;

    alpha := (w0 * 0.5) / q;
    cos_w0 := 1.0 - (w0 * w0 * 0.5); # Taylor approx for cos

    b0 := alpha;
    b1 := 0.0;
    b2 := -alpha;
    a0 := 1.0 + alpha;
    a1 := -2.0 * cos_w0;
    a2 := 1.0 - alpha;

    st.b[0] = b0 / a0;
    st.b[1] = b1 / a0;
    st.b[2] = b2 / a0;
    st.b[3] = b1 / a0;
    st.b[4] = b2 / a0;

    st.a[0] = 1.0;
    st.a[1] = a1 / a0;
    st.a[2] = a2 / a0;
    st.a[3] = a1 / a0;
    st.a[4] = a2 / a0;

    return st;
}

filter_sample(st: ref SeismicDSP->FilterState, x: real): real
{
    if (st == nil) return x;

    # Direct Form II Transposed Difference Equation
    y := st.b[0] * x + st.y_buf[0];
    st.y_buf[0] = st.b[1] * x - st.a[1] * y + st.y_buf[1];
    st.y_buf[1] = st.b[2] * x - st.a[2] * y + st.y_buf[2];
    st.y_buf[2] = st.b[3] * x - st.a[3] * y + st.y_buf[3];
    st.y_buf[3] = st.b[4] * x - st.a[4] * y;

    return y;
}

filter_series(st: ref SeismicDSP->FilterState, in_arr: array of real): array of real
{
    if (in_arr == nil || len in_arr == 0) return array[0] of real;
    n := len in_arr;
    out := array[n] of real;
    for (i := 0; i < n; i++) {
        out[i] = filter_sample(st, in_arr[i]);
    }
    return out;
}

remove_drift(in_arr: array of real, alpha: real): array of real
{
    if (in_arr == nil || len in_arr == 0) return array[0] of real;
    n := len in_arr;
    out := array[n] of real;
    out[0] = in_arr[0];
    for (i := 1; i < n; i++) {
        out[i] = alpha * (out[i - 1] + in_arr[i] - in_arr[i - 1]);
    }
    return out;
}
