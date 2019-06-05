# dsp_kurtosis.b: Sliding Kurtosis Higher-Order Statistics Picker in Limbo
implement DSPKurtosis;

include "sys.m";
    sys: Sys;

include "dsp.m";
    dsp: SeismicDSP;

DSPKurtosis: module
{
    PATH: con "/dis/dsp_kurtosis.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    compute_kurtosis: fn(samples: array of real, win_len: int): array of real;
    refine_onset:     fn(samples: array of real, win_len: int, start_idx: int): int;
};

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

compute_kurtosis(samples: array of real, win_len: int): array of real
{
    if (samples == nil || len samples == 0 || win_len < 4) {
        return array[0] of real;
    }
    n := len samples;
    kurt := array[n] of real;

    for (i := 0; i < n; i++) {
        if (i < win_len) {
            kurt[i] = 3.0; # Gaussian baseline
            continue;
        }

        # Compute mean
        sum := 0.0;
        start := i - win_len;
        for (j := start; j < i; j++) {
            sum += samples[j];
        }
        mean := sum / real win_len;

        # Compute 2nd and 4th central moments
        m2 := 0.0;
        m4 := 0.0;
        for (j = start; j < i; j++) {
            diff := samples[j] - mean;
            d2 := diff * diff;
            m2 += d2;
            m4 += d2 * d2;
        }
        m2 = m2 / real win_len;
        m4 = m4 / real win_len;

        if (m2 > 1e-12) {
            kurt[i] = m4 / (m2 * m2);
        } else {
            kurt[i] = 3.0;
        }
    }

    return kurt;
}

refine_onset(samples: array of real, win_len: int, start_idx: int): int
{
    if (samples == nil || len samples == 0) return -1;
    n := len samples;
    if (start_idx >= n) return -1;

    kurt := compute_kurtosis(samples, win_len);
    if (len kurt == 0) return start_idx;

    max_grad := -1.0;
    best_idx := start_idx;

    search_end := start_idx + (win_len * 3);
    if (search_end > n) search_end = n;

    for (i := start_idx + 1; i < search_end; i++) {
        grad := kurt[i] - kurt[i - 1];
        if (grad > max_grad) {
            max_grad = grad;
            best_idx = i;
        }
    }

    return best_idx;
}
