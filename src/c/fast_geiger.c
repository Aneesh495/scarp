/*
 * fast_geiger.c: Damped Gauss-Newton Hypocenter Inversion Implementation
 */

#include "fast_geiger.h"
#include <math.h>
#include <string.h>
#include <stdlib.h>
#include <float.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#define KM_PER_DEG_LAT 111.195

void fast_geiger_default_vmodel(FastVelocityModel* vm) {
    if (!vm) return;
    vm->num_layers = 4;
    /* Layer 0: Sedimentary upper crust */
    vm->layers[0].top_depth_km = 0.0;
    vm->layers[0].vp_kms = 5.50;
    vm->layers[0].vs_kms = 3.18;
    /* Layer 1: Mid crust */
    vm->layers[1].top_depth_km = 5.5;
    vm->layers[1].vp_kms = 6.30;
    vm->layers[1].vs_kms = 3.64;
    /* Layer 2: Lower crust (Conrad) */
    vm->layers[2].top_depth_km = 16.0;
    vm->layers[2].vp_kms = 6.70;
    vm->layers[2].vs_kms = 3.87;
    /* Layer 3: Upper Mantle (Moho) */
    vm->layers[3].top_depth_km = 32.0;
    vm->layers[3].vp_kms = 8.00;
    vm->layers[3].vs_kms = 4.62;
}

static inline double deg2rad(double deg) {
    return deg * (M_PI / 180.0);
}

static inline double rad2deg(double rad) {
    return rad * (180.0 / M_PI);
}

/* Great-circle distance and azimuth using spherical law of cosines / Haversine */
static void geo_distance_and_azimuth(double lat1, double lon1, double lat2, double lon2,
                                     double* out_dist_km, double* out_az_deg) {
    double phi1 = deg2rad(lat1);
    double phi2 = deg2rad(lat2);
    double dphi = deg2rad(lat2 - lat1);
    double dlam = deg2rad(lon2 - lon1);

    double a = sin(dphi / 2.0) * sin(dphi / 2.0) +
               cos(phi1) * cos(phi2) * sin(dlam / 2.0) * sin(dlam / 2.0);
    if (a < 0.0) a = 0.0;
    if (a > 1.0) a = 1.0;
    double c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a));
    double dist = 6371.0 * c;
    if (out_dist_km) *out_dist_km = dist;

    if (out_az_deg) {
        double y = sin(dlam) * cos(phi2);
        double x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(dlam);
        double az = rad2deg(atan2(y, x));
        if (az < 0.0) az += 360.0;
        *out_az_deg = az;
    }
}

void fast_geiger_travel_time(const FastVelocityModel* vm, int phase,
                             double hypo_lat, double hypo_lon, double hypo_depth_km,
                             double sta_lat, double sta_lon, double sta_elev_km,
                             double* out_tt, double* out_dtdlat, double* out_dtdlon, double* out_dtdz) {
    double epicentral_dist_km = 0.0;
    double az_deg = 0.0;
    geo_distance_and_azimuth(hypo_lat, hypo_lon, sta_lat, sta_lon, &epicentral_dist_km, &az_deg);

    double dz = hypo_depth_km + sta_elev_km;
    if (dz < 0.1) dz = 0.1;

    double hypocentral_dist_km = sqrt(epicentral_dist_km * epicentral_dist_km + dz * dz);

    /* Effective velocity lookup from layered model */
    double v_eff = (phase == 2) ? 3.50 : 6.00;
    if (vm && vm->num_layers > 0) {
        /* Find layer containing hypocenter */
        size_t lyr = 0;
        for (size_t l = 0; l < vm->num_layers; l++) {
            if (hypo_depth_km >= vm->layers[l].top_depth_km) {
                lyr = l;
            }
        }
        v_eff = (phase == 2) ? vm->layers[lyr].vs_kms : vm->layers[lyr].vp_kms;
    }

    double tt = hypocentral_dist_km / v_eff;
    if (out_tt) *out_tt = tt;

    /* Partial derivatives: dt/dx = (x - x_sta) / (v * D) */
    double dtdD = 1.0 / v_eff;
    double az_rad = deg2rad(az_deg);

    /* Epicentral distance derivatives with respect to hypocenter latitude and longitude */
    double km_per_deg_lon = KM_PER_DEG_LAT * cos(deg2rad(hypo_lat));
    if (km_per_deg_lon < 1.0) km_per_deg_lon = 1.0;

    double ddist_dlat = -cos(az_rad) * KM_PER_DEG_LAT;
    double ddist_dlon = -sin(az_rad) * km_per_deg_lon;

    double factor = (hypocentral_dist_km > 1e-6) ? (dtdD / hypocentral_dist_km) : 0.0;

    if (out_dtdlat) *out_dtdlat = factor * epicentral_dist_km * ddist_dlat;
    if (out_dtdlon) *out_dtdlon = factor * epicentral_dist_km * ddist_dlon;
    if (out_dtdz)   *out_dtdz   = factor * dz;
}

/* Invert 4x4 symmetric positive-definite matrix via Cholesky or Gaussian elimination */
static bool solve_4x4(const double A[4][4], const double b[4], double x[4], double out_inv[4][4]) {
    double aug[4][8];
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) aug[i][j] = A[i][j];
        for (int j = 0; j < 4; j++) aug[i][4 + j] = (i == j) ? 1.0 : 0.0;
    }

    /* Forward elimination with partial pivoting */
    for (int col = 0; col < 4; col++) {
        int pivot = col;
        double max_val = fabs(aug[col][col]);
        for (int row = col + 1; row < 4; row++) {
            if (fabs(aug[row][col]) > max_val) {
                max_val = fabs(aug[row][col]);
                pivot = row;
            }
        }
        if (max_val < 1e-14) return false; /* Singular */

        if (pivot != col) {
            for (int k = 0; k < 8; k++) {
                double tmp = aug[col][k];
                aug[col][k] = aug[pivot][k];
                aug[pivot][k] = tmp;
            }
        }

        double diag = aug[col][col];
        for (int k = 0; k < 8; k++) aug[col][k] /= diag;

        for (int row = 0; row < 4; row++) {
            if (row != col) {
                double factor = aug[row][col];
                for (int k = 0; k < 8; k++) {
                    aug[row][k] -= factor * aug[col][k];
                }
            }
        }
    }

    if (out_inv) {
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                out_inv[i][j] = aug[i][4 + j];
            }
        }
    }

    /* Solve A x = b via inverse */
    for (int i = 0; i < 4; i++) {
        x[i] = 0.0;
        for (int j = 0; j < 4; j++) {
            x[i] += aug[i][4 + j] * b[j];
        }
    }

    return true;
}

int fast_geiger_solve(const FastPickObs* picks, size_t num_picks,
                      const FastVelocityModel* vm,
                      const FastGeigerConfig* cfg,
                      FastHypoResult* out_result) {
    if (!picks || num_picks < 4 || !out_result) return -1;
    memset(out_result, 0, sizeof(FastHypoResult));

    /* Configuration defaults */
    size_t max_iter = (cfg && cfg->max_iterations > 0) ? cfg->max_iterations : 35;
    double lambda = (cfg && cfg->initial_lambda > 0.0) ? cfg->initial_lambda : 0.01;
    double tol_rms = (cfg && cfg->tolerance_rms_s > 0.0) ? cfg->tolerance_rms_s : 0.005;
    double min_z = (cfg && cfg->min_depth_km > 0.0) ? cfg->min_depth_km : 1.0;
    double max_z = (cfg && cfg->max_depth_km > 0.0) ? cfg->max_depth_km : 700.0;
    bool huber = cfg ? cfg->use_huber_weights : true;
    double huber_k = (cfg && cfg->huber_k > 0.0) ? cfg->huber_k : 1.5;

    /* Initial guess: centroid of earliest reporting stations */
    double mean_lat = 0.0;
    double mean_lon = 0.0;
    double min_t = DBL_MAX;

    for (size_t i = 0; i < num_picks; i++) {
        mean_lat += picks[i].station_lat;
        mean_lon += picks[i].station_lon;
        if (picks[i].arrival_time_s < min_t) {
            min_t = picks[i].arrival_time_s;
        }
    }
    mean_lat /= num_picks;
    mean_lon /= num_picks;

    double cur_lat = mean_lat;
    double cur_lon = mean_lon;
    double cur_z = 10.0; /* Initial trial depth: 10 km */
    double cur_t0 = min_t - 2.0; /* Trial origin time */

    double prev_rms = DBL_MAX;
    bool converged = false;
    double inv_normal[4][4];
    memset(inv_normal, 0, sizeof(inv_normal));

    for (size_t iter = 0; iter < max_iter; iter++) {
        double AtA[4][4] = {{0}};
        double Atb[4] = {0};
        double sum_sq_res = 0.0;
        double total_weight = 0.0;

        double residuals[GEIGER_MAX_STATIONS];
        double jacobian[GEIGER_MAX_STATIONS][4];
        double weights[GEIGER_MAX_STATIONS];

        for (size_t i = 0; i < num_picks; i++) {
            double calc_tt = 0.0;
            double dlat = 0.0, dlon = 0.0, dz = 0.0;
            fast_geiger_travel_time(vm, picks[i].phase_type,
                                   cur_lat, cur_lon, cur_z,
                                   picks[i].station_lat, picks[i].station_lon, picks[i].station_elev_km,
                                   &calc_tt, &dlat, &dlon, &dz);

            double obs_tt = picks[i].arrival_time_s - cur_t0;
            double res = obs_tt - calc_tt;
            residuals[i] = res;

            jacobian[i][0] = dlat;
            jacobian[i][1] = dlon;
            jacobian[i][2] = dz;
            jacobian[i][3] = 1.0;

            weights[i] = picks[i].weight > 0.0 ? picks[i].weight : 1.0;
        }

        /* Calculate RMS residual */
        double var_est = 0.0;
        for (size_t i = 0; i < num_picks; i++) {
            var_est += residuals[i] * residuals[i];
        }
        double sigma = sqrt(var_est / num_picks);
        if (sigma < 1e-4) sigma = 1e-4;

        /* Huber M-estimator weight adjustments */
        for (size_t i = 0; i < num_picks; i++) {
            double w = weights[i];
            if (huber) {
                double abs_r = fabs(residuals[i]);
                if (abs_r > huber_k * sigma) {
                    w *= (huber_k * sigma) / abs_r;
                }
            }
            sum_sq_res += w * residuals[i] * residuals[i];
            total_weight += w;

            for (int r = 0; r < 4; r++) {
                for (int c = 0; c < 4; c++) {
                    AtA[r][c] += w * jacobian[i][r] * jacobian[i][c];
                }
                Atb[r] += w * jacobian[i][r] * residuals[i];
            }
        }

        double cur_rms = sqrt(sum_sq_res / (total_weight > 0.0 ? total_weight : 1.0));

        /* Add Levenberg-Marquardt damping */
        for (int d = 0; d < 4; d++) {
            AtA[d][d] += lambda * (AtA[d][d] > 1e-6 ? AtA[d][d] : 1.0);
        }

        double delta_m[4] = {0};
        if (!solve_4x4(AtA, Atb, delta_m, inv_normal)) {
            lambda *= 5.0;
            continue;
        }

        /* Apply updates with physical clamping */
        double step_lat = delta_m[0];
        double step_lon = delta_m[1];
        double step_z = delta_m[2];
        double step_t0 = delta_m[3];

        /* Clamp maximum step per iteration to avoid divergence */
        if (step_lat > 0.5) step_lat = 0.5;
        if (step_lat < -0.5) step_lat = -0.5;
        if (step_lon > 0.5) step_lon = 0.5;
        if (step_lon < -0.5) step_lon = -0.5;
        if (step_z > 15.0) step_z = 15.0;
        if (step_z < -15.0) step_z = -15.0;
        if (step_t0 > 5.0) step_t0 = 5.0;
        if (step_t0 < -5.0) step_t0 = -5.0;

        cur_lat += step_lat;
        cur_lon += step_lon;
        cur_z += step_z;
        cur_t0 += step_t0;

        if (cur_z < min_z) cur_z = min_z;
        if (cur_z > max_z) cur_z = max_z;

        out_result->iterations_used = iter + 1;
        out_result->rms_residual_s = cur_rms;

        if (cur_rms < prev_rms) {
            lambda *= 0.2;
            if (lambda < 1e-6) lambda = 1e-6;
        } else {
            lambda *= 2.5;
        }

        if (fabs(prev_rms - cur_rms) < tol_rms || cur_rms < 0.02) {
            converged = true;
            break;
        }
        prev_rms = cur_rms;
    }

    out_result->lat = cur_lat;
    out_result->lon = cur_lon;
    out_result->depth_km = cur_z;
    out_result->origin_time_s = cur_t0;
    out_result->converged = converged;

    /* Compute covariance matrix: C = sigma^2 * (A^T A)^(-1) */
    double s2 = out_result->rms_residual_s * out_result->rms_residual_s;
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            out_result->covariance[i][j] = s2 * inv_normal[i][j];
        }
    }

    /* Horizontal error ellipse extraction */
    double c00 = out_result->covariance[0][0] * KM_PER_DEG_LAT * KM_PER_DEG_LAT;
    double c11 = out_result->covariance[1][1] * KM_PER_DEG_LAT * KM_PER_DEG_LAT;
    double c01 = out_result->covariance[0][1] * KM_PER_DEG_LAT * KM_PER_DEG_LAT;

    double trace = c00 + c11;
    double det = c00 * c11 - c01 * c01;
    double disc = sqrt(fmax(0.0, trace * trace * 0.25 - det));

    double eig1 = fmax(0.0, trace * 0.5 + disc);
    double eig2 = fmax(0.0, trace * 0.5 - disc);

    out_result->error_semimajor_km = 1.96 * sqrt(eig1);
    out_result->error_semiminor_km = 1.96 * sqrt(eig2);
    out_result->error_depth_km = 1.96 * sqrt(fmax(0.0, out_result->covariance[2][2]));
    out_result->strike_deg = rad2deg(0.5 * atan2(2.0 * c01, c00 - c11));
    if (out_result->strike_deg < 0.0) out_result->strike_deg += 180.0;

    /* Compute azimuthal gap */
    double azimuths[GEIGER_MAX_STATIONS];
    for (size_t i = 0; i < num_picks; i++) {
        double dist_k, az_k;
        geo_distance_and_azimuth(cur_lat, cur_lon, picks[i].station_lat, picks[i].station_lon, &dist_k, &az_k);
        azimuths[i] = az_k;
    }
    /* Simple bubble sort for azimuths */
    for (size_t i = 0; i < num_picks - 1; i++) {
        for (size_t j = 0; j < num_picks - i - 1; j++) {
            if (azimuths[j] > azimuths[j + 1]) {
                double tmp = azimuths[j];
                azimuths[j] = azimuths[j + 1];
                azimuths[j + 1] = tmp;
            }
        }
    }
    double max_gap = (360.0 - azimuths[num_picks - 1]) + azimuths[0];
    for (size_t i = 0; i < num_picks - 1; i++) {
        double g = azimuths[i + 1] - azimuths[i];
        if (g > max_gap) max_gap = g;
    }
    out_result->azimuthal_gap_deg = max_gap;

    return 0;
}
