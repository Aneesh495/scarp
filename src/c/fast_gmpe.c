/*
 * fast_gmpe.c: Vectorized NGA-West2 Ground Motion Model Implementation
 */

#include "fast_gmpe.h"
#include <math.h>
#include <string.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static inline double deg2rad(double deg) {
    return deg * (M_PI / 180.0);
}

static void calc_geo_dist(double lat1, double lon1, double lat2, double lon2, double* out_dist_km) {
    double phi1 = deg2rad(lat1);
    double phi2 = deg2rad(lat2);
    double dphi = deg2rad(lat2 - lat1);
    double dlam = deg2rad(lon2 - lon1);

    double a = sin(dphi / 2.0) * sin(dphi / 2.0) +
               cos(phi1) * cos(phi2) * sin(dlam / 2.0) * sin(dlam / 2.0);
    if (a < 0.0) a = 0.0;
    if (a > 1.0) a = 1.0;
    double c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a));
    *out_dist_km = 6371.0 * c;
}

double fast_mmi_from_pga_pgv(double pga_pct_g, double pgv_cms) {
    /* Wald et al. (1999) relationship between instrumental metrics and MMI */
    double mmi_pga = 1.0;
    if (pga_pct_g > 0.0) {
        double log_pga = log10(pga_pct_g);
        if (log_pga <= 0.6) {
            mmi_pga = 2.20 * log_pga + 1.00;
        } else {
            mmi_pga = 3.66 * log_pga - 1.66;
        }
    }

    double mmi_pgv = 1.0;
    if (pgv_cms > 0.0) {
        double log_pgv = log10(pgv_cms);
        if (log_pgv <= 0.7) {
            mmi_pgv = 2.10 * log_pgv + 3.40;
        } else {
            mmi_pgv = 3.47 * log_pgv + 2.35;
        }
    }

    /* Weighted blend: PGA dominates for low intensities, PGV for destructive shaking */
    double mmi;
    if (mmi_pgv < 5.0) {
        mmi = 0.7 * mmi_pga + 0.3 * mmi_pgv;
    } else {
        mmi = 0.2 * mmi_pga + 0.8 * mmi_pgv;
    }

    if (mmi < 1.0) mmi = 1.0;
    if (mmi > 10.0) mmi = 10.0;
    return mmi;
}

void fast_gmpe_eval_point(const FastSourceParams* src,
                          double site_lat, double site_lon, double site_vs30_ms,
                          double current_time_s,
                          FastIntensityMeasures* out_im) {
    if (!src || !out_im) return;
    memset(out_im, 0, sizeof(FastIntensityMeasures));

    double epi_dist_km = 0.0;
    calc_geo_dist(src->hypo_lat, src->hypo_lon, site_lat, site_lon, &epi_dist_km);

    double z_km = src->hypo_depth_km > 0.5 ? src->hypo_depth_km : 0.5;
    double r_rup = sqrt(epi_dist_km * epi_dist_km + z_km * z_km);

    double mw = src->mw;
    double vs30 = site_vs30_ms > 100.0 ? site_vs30_ms : 760.0;

    /* NGA-West2 Functional Form (Boore et al. BSSA14 style) */
    /* 1. Magnitude scaling: e0 + e1*(M - Mh) + e2*(M - Mh)^2 */
    double mh = 6.0;
    double dm = mw - mh;
    double f_mag_pga = -0.55 + (mw <= mh ? (0.80 * dm + 0.10 * dm * dm) : (0.45 * dm));
    double f_mag_pgv = 1.20 + (mw <= mh ? (1.05 * dm + 0.08 * dm * dm) : (0.70 * dm));

    /* 2. Geometrical spreading and anelastic attenuation */
    double h = 4.5; /* Pseudo-depth */
    double r_eff = sqrt(r_rup * r_rup + h * h);
    double c1_pga = -1.15;
    double c2_pga = 0.12;
    double c3_pga = -0.0065;

    double f_dist_pga = (c1_pga + c2_pga * (mw - 4.5)) * log(r_eff / 1.0) + c3_pga * (r_eff - 1.0);
    double f_dist_pgv = (-1.05 + 0.10 * (mw - 4.5)) * log(r_eff / 1.0) - 0.0035 * (r_eff - 1.0);

    /* 3. Site amplification term: ln(VS30 / 760) */
    double v_ref = 760.0;
    double f_site_pga = -0.45 * log(vs30 / v_ref);
    double f_site_pgv = -0.65 * log(vs30 / v_ref);

    /* Natural logarithm of median expected motions */
    double ln_pga = f_mag_pga + f_dist_pga + f_site_pga;
    double ln_pgv = f_mag_pgv + f_dist_pgv + f_site_pgv;

    /* PGA in % of 1g, PGV in cm/s */
    double pga_pct_g = exp(ln_pga) * 100.0;
    double pgv_cms = exp(ln_pgv);

    if (pga_pct_g < 0.001) pga_pct_g = 0.001;
    if (pga_pct_g > 300.0) pga_pct_g = 300.0; /* Clamped physical ceiling */

    if (pgv_cms < 0.001) pgv_cms = 0.001;
    if (pgv_cms > 250.0) pgv_cms = 250.0;

    out_im->pga_pct_g = pga_pct_g;
    out_im->pgv_cms = pgv_cms;

    /* Spectral Accelerations (0.3s, 1.0s, 3.0s) */
    out_im->psa_03s = pga_pct_g * (1.8 + 0.1 * (mw - 5.0));
    out_im->psa_10s = pga_pct_g * (0.8 + 0.25 * (mw - 5.0));
    out_im->psa_30s = pga_pct_g * (0.2 + 0.15 * (mw - 5.0));

    out_im->mmi = fast_mmi_from_pga_pgv(pga_pct_g, pgv_cms);

    /* S-wave arrival time and Time-to-Impact (TTI) */
    double vs_avg = 3.5; /* km/s */
    double s_travel_time = r_rup / vs_avg;
    double elapsed_since_origin = current_time_s - src->origin_time_s;
    out_im->tti_s = s_travel_time - elapsed_since_origin;
}

size_t fast_gmpe_eval_grid(const FastSourceParams* src,
                           double lat_min, double lat_max,
                           double lon_min, double lon_max,
                           double grid_step_deg,
                           double default_vs30_ms,
                           double current_time_s,
                           double* out_lats, double* out_lons,
                           FastIntensityMeasures* out_ims,
                           size_t max_cells) {
    if (!src || !out_lats || !out_lons || !out_ims || max_cells == 0 || grid_step_deg <= 0.0) return 0;

    size_t cell_idx = 0;
    for (double lat = lat_min; lat <= lat_max && cell_idx < max_cells; lat += grid_step_deg) {
        for (double lon = lon_min; lon <= lon_max && cell_idx < max_cells; lon += grid_step_deg) {
            out_lats[cell_idx] = lat;
            out_lons[cell_idx] = lon;
            fast_gmpe_eval_point(src, lat, lon, default_vs30_ms, current_time_s, &out_ims[cell_idx]);
            cell_idx++;
        }
    }
    return cell_idx;
}
