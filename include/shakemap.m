# shakemap.m: Ground Motion Prediction and ShakeMap Grid Interface

ShakeMapEngine: module
{
    PATH: con "/dis/shakemap.dis";

    # Ground Motion Prediction Equation (GMPE) Evaluation
    # Evaluates log-normal median PGA (%g), PGV (cm/s), and Spectral Accelerations
    eval_gmpe: fn(mag: real, r_rup_km: real, vs30_ms: real,
                  mechanism: int): (real, real, real, real, real);

    # Instrumental MMI Mapping (Wald et al.)
    pga_to_mmi: fn(pga_pct_g: real): real;
    pgv_to_mmi: fn(pgv_cms: real): real;
    combined_mmi: fn(pga_pct_g: real, pgv_cms: real): real;

    # Grid Interpolation
    generate_grid: fn(hypo: ref Scarp->HypoSolution,
                      mag: ref Scarp->MagnitudeSol,
                      lat_min: real, lat_max: real,
                      lon_min: real, lon_max: real,
                      grid_step_deg: real,
                      default_vs30: real): list of ref Scarp->ShakeMapCell;
};
