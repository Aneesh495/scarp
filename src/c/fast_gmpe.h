/*
 * fast_gmpe.h: Vectorized NGA-West2 Ground Motion Model and ShakeMap Evaluator
 *
 * Implements NGA-West2 empirical ground motion models (BSSA14 / CB14),
 * non-linear site amplification (VS30), instrumental MMI mapping,
 * and high-throughput 2D spatial grid rasterization.
 */

#ifndef SCARP_FAST_GMPE_H
#define SCARP_FAST_GMPE_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Earthquake Source Parameters */
typedef struct {
    double mw;              /* Moment magnitude (e.g. 6.5) */
    double hypo_lat;        /* Degrees North */
    double hypo_lon;        /* Degrees East */
    double hypo_depth_km;   /* Focal depth in km */
    int    fault_mechanism; /* 0 = Strike-slip, 1 = Normal, 2 = Reverse/Thrust */
    double dip_deg;         /* Fault dip angle degrees */
    double origin_time_s;   /* Origin time reference */
} FastSourceParams;

/* Ground Motion Intensity Measures */
typedef struct {
    double pga_pct_g;       /* Peak ground acceleration (% of 1g) */
    double pgv_cms;         /* Peak ground velocity (cm/s) */
    double psa_03s;         /* 0.3s Spectral acceleration (%g) */
    double psa_10s;         /* 1.0s Spectral acceleration (%g) */
    double psa_30s;         /* 3.0s Spectral acceleration (%g) */
    double mmi;             /* Modified Mercalli Intensity [1.0, 10.0] */
    double tti_s;           /* S-wave Time to Impact (seconds) */
} FastIntensityMeasures;

/* Evaluate single point Ground Motion Model */
void fast_gmpe_eval_point(const FastSourceParams* src,
                          double site_lat, double site_lon, double site_vs30_ms,
                          double current_time_s,
                          FastIntensityMeasures* out_im);

/* Wald et al. Instrumental MMI conversion */
double fast_mmi_from_pga_pgv(double pga_pct_g, double pgv_cms);

/*
 * Vectorized 2D grid evaluation over a regular bounding box.
 * Returns the total number of cells populated.
 */
size_t fast_gmpe_eval_grid(const FastSourceParams* src,
                           double lat_min, double lat_max,
                           double lon_min, double lon_max,
                           double grid_step_deg,
                           double default_vs30_ms,
                           double current_time_s,
                           double* out_lats, double* out_lons,
                           FastIntensityMeasures* out_ims,
                           size_t max_cells);

#ifdef __cplusplus
}
#endif

#endif /* SCARP_FAST_GMPE_H */
