/*
 * fast_dsp.h: High-Performance C11 / SIMD Accelerated Seismic DSP
 *
 * Provides recursive causal IIR filtering, baseline drift correction,
 * sliding STA/LTA energy ratio triggering, kurtosis onset refinement,
 * and trapezoidal double integration for strong-motion seismology.
 */

#ifndef SCARP_FAST_DSP_H
#define SCARP_FAST_DSP_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* 4th-order Causal IIR Filter State */
typedef struct {
    double b[5]; /* Numerator coefficients */
    double a[5]; /* Denominator coefficients */
    double w[4]; /* Direct form II transposed delay registers */
} FastIIRFilter;

/* Recursive STA/LTA State */
typedef struct {
    double sta;
    double lta;
    double c_sta;
    double c_lta;
    double on_threshold;
    double off_threshold;
    bool   is_triggered;
    int32_t trigger_sample_idx;
} FastTrigger;

/* Filter initialization */
void fast_iir_init_bandpass_4th(FastIIRFilter* f, double fl_hz, double fh_hz, double fs_hz);
void fast_iir_reset(FastIIRFilter* f);
double fast_iir_step(FastIIRFilter* f, double x);
void fast_iir_process_block(FastIIRFilter* f, const double* in, double* out, size_t n);

/* Baseline drift removal */
void fast_remove_baseline(const double* in, double* out, size_t n, double alpha);

/* Recursive STA/LTA evaluation */
void fast_trigger_init(FastTrigger* t, double sta_s, double lta_s, double fs_hz, double on_th, double off_th);
int  fast_trigger_step(FastTrigger* t, double sample, double deriv, double* out_ratio);
void fast_trigger_process_block(FastTrigger* t, const double* samples, double* out_ratios, int* out_triggers, size_t n, double dt);

/* Sliding Kurtosis Onset Refinement */
int32_t fast_kurtosis_picker(const double* samples, size_t n, size_t window_len, size_t search_start);

/* Double Integration: Acceleration -> Velocity -> Displacement */
void fast_double_integrate(const double* acc, double* vel, double* disp, size_t n, double dt, double highpass_cutoff_hz);

/* Real-Time Early Warning Feature Extraction: Pd, Pv, Pa, Tau_c */
typedef struct {
    double peak_acc_g;
    double peak_vel_cms;
    double peak_disp_cm;
    double tau_c_sec;
    double cav_cms;
} FastSeismicFeatures;

void fast_extract_features(const double* acc, size_t n, double dt, size_t p_onset_idx, size_t window_len, FastSeismicFeatures* out_features);

#ifdef __cplusplus
}
#endif

#endif /* SCARP_FAST_DSP_H */
