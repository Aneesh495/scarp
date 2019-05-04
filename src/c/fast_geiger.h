/*
 * fast_geiger.h: Damped Gauss-Newton Non-Linear Hypocenter Inversion
 *
 * Implements Geiger's method with Levenberg-Marquardt adaptive damping,
 * Huber robust weighting, 1D ray tracing, and 95% confidence error ellipsoids.
 */

#ifndef SCARP_FAST_GEIGER_H
#define SCARP_FAST_GEIGER_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define GEIGER_MAX_STATIONS 256
#define GEIGER_MAX_LAYERS   16

/* 1D Crustal Velocity Model Layer */
typedef struct {
    double top_depth_km;
    double vp_kms;
    double vs_kms;
} FastVelocityLayer;

typedef struct {
    size_t             num_layers;
    FastVelocityLayer  layers[GEIGER_MAX_LAYERS];
} FastVelocityModel;

/* Station Pick Observation */
typedef struct {
    double station_lat;
    double station_lon;
    double station_elev_km;
    double arrival_time_s; /* Seconds since epoch reference */
    int    phase_type;     /* 1 = P, 2 = S */
    double weight;         /* Prior observation weight in [0.0, 1.0] */
} FastPickObs;

/* Inversion Parameters */
typedef struct {
    size_t max_iterations;
    double initial_lambda;
    double lambda_factor;
    double tolerance_rms_s;
    double min_depth_km;
    double max_depth_km;
    bool   use_huber_weights;
    double huber_k;
} FastGeigerConfig;

/* Hypocenter Inversion Output */
typedef struct {
    double lat;
    double lon;
    double depth_km;
    double origin_time_s;
    double rms_residual_s;
    size_t iterations_used;
    bool   converged;
    double error_semimajor_km;
    double error_semiminor_km;
    double error_depth_km;
    double strike_deg;
    double azimuthal_gap_deg;
    double covariance[4][4];
} FastHypoResult;

/* Default velocity model constructor (California crust / AK135 hybrid) */
void fast_geiger_default_vmodel(FastVelocityModel* vm);

/* Travel time and partial derivatives calculation */
void fast_geiger_travel_time(const FastVelocityModel* vm, int phase,
                             double hypo_lat, double hypo_lon, double hypo_depth_km,
                             double sta_lat, double sta_lon, double sta_elev_km,
                             double* out_tt, double* out_dtdlat, double* out_dtdlon, double* out_dtdz);

/* Execute Geiger Inversion */
int fast_geiger_solve(const FastPickObs* picks, size_t num_picks,
                      const FastVelocityModel* vm,
                      const FastGeigerConfig* cfg,
                      FastHypoResult* out_result);

#ifdef __cplusplus
}
#endif

#endif /* SCARP_FAST_GEIGER_H */
