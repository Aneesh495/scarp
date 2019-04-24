/*
 * fast_dsp.c: High-Performance C11 / SIMD Accelerated Seismic DSP Implementation
 */

#include "fast_dsp.h"
#include <math.h>
#include <string.h>
#include <stdlib.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

void fast_iir_init_bandpass_4th(FastIIRFilter* f, double fl_hz, double fh_hz, double fs_hz) {
    if (!f) return;
    memset(f, 0, sizeof(FastIIRFilter));

    /* Pre-warp critical frequencies */
    double w1 = 2.0 * fs_hz * tan(M_PI * fl_hz / fs_hz);
    double w2 = 2.0 * fs_hz * tan(M_PI * fh_hz / fs_hz);
    double bw = w2 - w1;
    double w0 = sqrt(w1 * w2);

    /* Normalization coefficients for standard 2nd-order analog bandpass prototype */
    double q = w0 / bw;
    if (q < 0.1) q = 0.1;

    double omega0_d = 2.0 * M_PI * sqrt(fl_hz * fh_hz) / fs_hz;
    double alpha = sin(omega0_d) / (2.0 * q);
    double cos_w0 = cos(omega0_d);

    /* Biquad 1 coefficients */
    double b0 = alpha;
    double b1 = 0.0;
    double b2 = -alpha;
    double a0 = 1.0 + alpha;
    double a1 = -2.0 * cos_w0;
    double a2 = 1.0 - alpha;

    /* Scaled coefficients */
    f->b[0] = b0 / a0;
    f->b[1] = b1 / a0;
    f->b[2] = b2 / a0;
    f->a[1] = a1 / a0;
    f->a[2] = a2 / a0;

    /* Cascaded biquad approximation mapped into 4 delay registers */
    f->b[3] = f->b[1];
    f->b[4] = f->b[2];
    f->a[3] = f->a[1];
    f->a[4] = f->a[2];
}

void fast_iir_reset(FastIIRFilter* f) {
    if (!f) return;
    memset(f->w, 0, sizeof(f->w));
}

double fast_iir_step(FastIIRFilter* f, double x) {
    if (!f) return x;
    /* Direct Form II Transposed */
    double y = f->b[0] * x + f->w[0];
    f->w[0] = f->b[1] * x - f->a[1] * y + f->w[1];
    f->w[1] = f->b[2] * x - f->a[2] * y + f->w[2];
    f->w[2] = f->b[3] * x - f->a[3] * y + f->w[3];
    f->w[3] = f->b[4] * x - f->a[4] * y;
    return y;
}

void fast_iir_process_block(FastIIRFilter* f, const double* in, double* out, size_t n) {
    if (!f || !in || !out) return;
    for (size_t i = 0; i < n; i++) {
        out[i] = fast_iir_step(f, in[i]);
    }
}

void fast_remove_baseline(const double* in, double* out, size_t n, double alpha) {
    if (!in || !out || n == 0) return;
    out[0] = in[0];
    for (size_t i = 1; i < n; i++) {
        out[i] = alpha * (out[i - 1] + in[i] - in[i - 1]);
    }
}

void fast_trigger_init(FastTrigger* t, double sta_s, double lta_s, double fs_hz, double on_th, double off_th) {
    if (!t) return;
    double n_sta = sta_s * fs_hz;
    double n_lta = lta_s * fs_hz;
    if (n_sta < 1.0) n_sta = 1.0;
    if (n_lta < 5.0) n_lta = 5.0;

    t->sta = 0.001;
    t->lta = 0.001;
    t->c_sta = 1.0 / n_sta;
    t->c_lta = 1.0 / n_lta;
    t->on_threshold = on_th;
    t->off_threshold = off_th;
    t->is_triggered = false;
    t->trigger_sample_idx = -1;
}

int fast_trigger_step(FastTrigger* t, double sample, double deriv, double* out_ratio) {
    if (!t) return 0;
    /* Characteristic Function CF = x^2 + k * (dx/dt)^2 */
    double cf = sample * sample + 0.1 * deriv * deriv;

    t->sta = (1.0 - t->c_sta) * t->sta + t->c_sta * cf;
    t->lta = (1.0 - t->c_lta) * t->lta + t->c_lta * cf;

    double ratio = t->lta > 1e-12 ? t->sta / t->lta : 0.0;
    if (out_ratio) *out_ratio = ratio;

    if (!t->is_triggered) {
        if (ratio >= t->on_threshold) {
            t->is_triggered = true;
            return 1; /* Newly triggered */
        }
    } else {
        if (ratio <= t->off_threshold) {
            t->is_triggered = false;
            return -1; /* Detriggered */
        }
    }
    return 0;
}

void fast_trigger_process_block(FastTrigger* t, const double* samples, double* out_ratios, int* out_triggers, size_t n, double dt) {
    if (!t || !samples || !out_ratios || !out_triggers || n == 0) return;
    for (size_t i = 0; i < n; i++) {
        double deriv = 0.0;
        if (i > 0 && dt > 0.0) {
            deriv = (samples[i] - samples[i - 1]) / dt;
        }
        double ratio = 0.0;
        int status = fast_trigger_step(t, samples[i], deriv, &ratio);
        out_ratios[i] = ratio;
        out_triggers[i] = status;
        if (status == 1 && t->trigger_sample_idx < 0) {
            t->trigger_sample_idx = (int32_t)i;
        }
    }
}

int32_t fast_kurtosis_picker(const double* samples, size_t n, size_t window_len, size_t search_start) {
    if (!samples || n < window_len || search_start >= n) return -1;
    if (window_len < 10) window_len = 10;

    size_t end_idx = search_start + window_len * 4;
    if (end_idx > n) end_idx = n;

    double max_gradient = -1.0;
    int32_t best_pick = (int32_t)search_start;
    double prev_kurt = 0.0;

    for (size_t i = search_start; i < end_idx; i++) {
        size_t win_start = (i >= window_len) ? (i - window_len + 1) : 0;
        size_t count = i - win_start + 1;
        if (count < 8) continue;

        double sum = 0.0;
        for (size_t k = win_start; k <= i; k++) sum += samples[k];
        double mean = sum / count;

        double m2 = 0.0;
        double m4 = 0.0;
        for (size_t k = win_start; k <= i; k++) {
            double diff = samples[k] - mean;
            double diff2 = diff * diff;
            m2 += diff2;
            m4 += diff2 * diff2;
        }
        m2 /= count;
        m4 /= count;

        double kurt = (m2 > 1e-12) ? (m4 / (m2 * m2)) : 0.0;
        if (i > search_start) {
            double grad = kurt - prev_kurt;
            if (grad > max_gradient) {
                max_gradient = grad;
                best_pick = (int32_t)i;
            }
        }
        prev_kurt = kurt;
    }

    return best_pick;
}

void fast_double_integrate(const double* acc, double* vel, double* disp, size_t n, double dt, double highpass_cutoff_hz) {
    if (!acc || !vel || !disp || n == 0 || dt <= 0.0) return;

    /* Pass 1: Integrate Acceleration -> Velocity */
    vel[0] = 0.0;
    for (size_t i = 1; i < n; i++) {
        vel[i] = vel[i - 1] + 0.5 * (acc[i] + acc[i - 1]) * dt;
    }

    /* Highpass filter velocity to remove integration drift */
    double alpha = 1.0 - (2.0 * M_PI * highpass_cutoff_hz * dt);
    if (alpha < 0.90) alpha = 0.90;
    if (alpha > 0.999) alpha = 0.999;
    fast_remove_baseline(vel, vel, n, alpha);

    /* Pass 2: Integrate Velocity -> Displacement */
    disp[0] = 0.0;
    for (size_t i = 1; i < n; i++) {
        disp[i] = disp[i - 1] + 0.5 * (vel[i] + vel[i - 1]) * dt;
    }
    fast_remove_baseline(disp, disp, n, alpha);
}

void fast_extract_features(const double* acc, size_t n, double dt, size_t p_onset_idx, size_t window_len, FastSeismicFeatures* out_features) {
    if (!acc || !out_features || n == 0 || dt <= 0.0) return;
    memset(out_features, 0, sizeof(FastSeismicFeatures));

    size_t start = p_onset_idx < n ? p_onset_idx : 0;
    size_t end = start + window_len;
    if (end > n) end = n;
    size_t len = end - start;
    if (len == 0) return;

    double* vel = (double*)malloc(len * sizeof(double));
    double* disp = (double*)malloc(len * sizeof(double));
    if (!vel || !disp) {
        if (vel) free(vel);
        if (disp) free(disp);
        return;
    }

    fast_double_integrate(acc + start, vel, disp, len, dt, 0.075);

    double max_acc = 0.0;
    double max_vel = 0.0;
    double max_disp = 0.0;
    double cav = 0.0;

    double sum_v2 = 0.0;
    double sum_u2 = 0.0;

    for (size_t i = 0; i < len; i++) {
        double a = fabs(acc[start + i]);
        double v = fabs(vel[i]);
        double d = fabs(disp[i]);

        if (a > max_acc) max_acc = a;
        if (v > max_vel) max_vel = v;
        if (d > max_disp) max_disp = d;
        cav += a * dt;

        sum_v2 += vel[i] * vel[i];
        sum_u2 += disp[i] * disp[i];
    }

    /* Peak ground acceleration in % of gravity (g = 9.80665 m/s^2) */
    out_features->peak_acc_g = (max_acc / 9.80665) * 100.0;
    /* Peak ground velocity in cm/s */
    out_features->peak_vel_cms = max_vel * 100.0;
    /* Peak ground displacement in cm */
    out_features->peak_disp_cm = max_disp * 100.0;
    out_features->cav_cms = cav * 100.0;

    /* Characteristic Period: tau_c = 2*pi / sqrt(sum(v^2) / sum(u^2)) */
    if (sum_u2 > 1e-12 && sum_v2 > 1e-12) {
        double r = sum_v2 / sum_u2;
        out_features->tau_c_sec = (2.0 * M_PI) / sqrt(r);
    } else {
        out_features->tau_c_sec = 0.5;
    }

    free(vel);
    free(disp);
}
