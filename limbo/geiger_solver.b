# geiger_solver.b: Geiger Non-Linear Least Squares Locator in Limbo
implement GeigerSolver;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "geiger.m";
    geiger: GeigerLocator;

GeigerSolver: module
{
    PATH: con "/dis/geiger_solver.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    solve_hypocenter: fn(picks: list of ref Scarp->PhasePick,
                         stations: list of ref Scarp->Station,
                         vmodel: ref GeigerLocator->VelocityModel,
                         max_iter: int,
                         tol_rms_s: real): ref Scarp->HypoSolution;
};

PI: con 3.141592653589793;
KM_PER_DEG: con 111.195;

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

sqrt_approx(x: real): real
{
    if (x <= 0.0) return 0.0;
    val := x;
    if (x > 1.0) val = x * 0.5;
    for (i := 0; i < 8; i++) {
        val = 0.5 * (val + x / val);
    }
    return val;
}

solve_4x4(A: array of array of real, b: array of real): (array of real, int)
{
    # Augmented matrix 4x8 for Gauss-Jordan elimination
    aug := array[4] of array of real;
    for (i := 0; i < 4; i++) {
        aug[i] = array[8] of real;
        for (j := 0; j < 4; j++) aug[i][j] = A[i][j];
        for (j = 0; j < 4; j++) aug[i][4 + j] = (i == j ? 1.0 : 0.0);
    }

    for (col := 0; col < 4; col++) {
        pivot := col;
        max_val := aug[col][col];
        if (max_val < 0.0) max_val = -max_val;

        for (row := col + 1; row < 4; row++) {
            v := aug[row][col];
            if (v < 0.0) v = -v;
            if (v > max_val) {
                max_val = v;
                pivot = row;
            }
        }
        if (max_val < 1e-12) return (array[4] of real, 0); # Singular

        if (pivot != col) {
            tmp := aug[col];
            aug[col] = aug[pivot];
            aug[pivot] = tmp;
        }

        diag := aug[col][col];
        for (k := 0; k < 8; k++) aug[col][k] /= diag;

        for (row = 0; row < 4; row++) {
            if (row != col) {
                factor := aug[row][col];
                for (k = 0; k < 8; k++) {
                    aug[row][k] -= factor * aug[col][k];
                }
            }
        }
    }

    x := array[4] of real;
    for (i = 0; i < 4; i++) {
        x[i] = 0.0;
        for (j := 0; j < 4; j++) {
            x[i] += aug[i][4 + j] * b[j];
        }
    }
    return (x, 1);
}

solve_hypocenter(picks: list of ref Scarp->PhasePick,
                 stations: list of ref Scarp->Station,
                 vmodel: ref GeigerLocator->VelocityModel,
                 max_iter: int,
                 tol_rms_s: real): ref Scarp->HypoSolution
{
    sol := ref Scarp->HypoSolution;
    sol.event_id = "EVT_001";
    sol.converged = 0;

    n_p := 0;
    for (cp := picks; cp != nil; cp = tl cp) n_p++;
    if (n_p < 4) return sol;

    # Compute initial centroid from earliest picks
    sum_lat := 0.0;
    sum_lon := 0.0;
    min_t_us := big 9223372036854775807;

    for (cp = picks; cp != nil; cp = tl cp) {
        pk := hd cp;
        if (pk.time_us < min_t_us) min_t_us = pk.time_us;

        for (st := stations; st != nil; st = tl st) {
            if ((hd st).id == pk.sta_id) {
                sum_lat += (hd st).lat;
                sum_lon += (hd st).lon;
                break;
            }
        }
    }

    cur_lat := sum_lat / real n_p;
    cur_lon := sum_lon / real n_p;
    cur_z := 10.0;
    cur_t0 := (real min_t_us / 1000000.0) - 2.0;

    lambda := 0.05;
    prev_rms := 999999.0;

    for (iter := 0; iter < max_iter; iter++) {
        AtA := array[4] of array of real;
        for (a_idx := 0; a_idx < 4; a_idx++) {
            AtA[a_idx] = array[4] of real;
            for (c_idx := 0; c_idx < 4; c_idx++) AtA[a_idx][c_idx] = 0.0;
        }
        Atb := array[4] of real;
        for (b_idx := 0; b_idx < 4; b_idx++) Atb[b_idx] = 0.0;

        sum_sq_res := 0.0;

        for (cp = picks; cp != nil; cp = tl cp) {
            pk = hd cp;
            st_found: ref Scarp->Station = nil;
            for (st := stations; st != nil; st = tl st) {
                if ((hd st).id == pk.sta_id) {
                    st_found = hd st;
                    break;
                }
            }
            if (st_found == nil) continue;

            dlat := (st_found.lat - cur_lat) * KM_PER_DEG;
            cos_mid := 1.0 - (cur_lat * PI / 180.0) * (cur_lat * PI / 180.0) * 0.5;
            dlon := (st_found.lon - cur_lon) * KM_PER_DEG * cos_mid;
            epi_dist := sqrt_approx(dlat * dlat + dlon * dlon);
            hypo_dist := sqrt_approx(epi_dist * epi_dist + cur_z * cur_z);

            v_eff := (pk.phase_type == 2 ? 3.5 : 6.0);
            calc_tt := hypo_dist / v_eff;

            obs_tt := (real pk.time_us / 1000000.0) - cur_t0;
            res := obs_tt - calc_tt;
            sum_sq_res += res * res;

            factor := (hypo_dist > 1e-4 ? (1.0 / v_eff) / hypo_dist : 0.0);
            j_row := array[4] of real;
            j_row[0] = -factor * dlat;
            j_row[1] = -factor * dlon;
            j_row[2] = factor * cur_z;
            j_row[3] = 1.0;

            for (r := 0; r < 4; r++) {
                for (c := 0; c < 4; c++) {
                    AtA[r][c] += j_row[r] * j_row[c];
                }
                Atb[r] += j_row[r] * res;
            }
        }

        cur_rms := sqrt_approx(sum_sq_res / real n_p);

        # Apply Levenberg-Marquardt damping
        for (d := 0; d < 4; d++) {
            AtA[d][d] += lambda;
        }

        (delta, ok) := solve_4x4(AtA, Atb);
        if (ok == 0) {
            lambda *= 4.0;
            continue;
        }

        # Step clamping
        if (delta[0] > 0.5) delta[0] = 0.5;
        if (delta[0] < -0.5) delta[0] = -0.5;
        if (delta[1] > 0.5) delta[1] = 0.5;
        if (delta[1] < -0.5) delta[1] = -0.5;
        if (delta[2] > 10.0) delta[2] = 10.0;
        if (delta[2] < -10.0) delta[2] = -10.0;

        cur_lat += delta[0];
        cur_lon += delta[1];
        cur_z += delta[2];
        cur_t0 += delta[3];

        if (cur_z < 1.0) cur_z = 1.0;

        if (cur_rms < prev_rms) {
            lambda *= 0.3;
        } else {
            lambda *= 2.0;
        }

        diff_rms := prev_rms - cur_rms;
        if (diff_rms < 0.0) diff_rms = -diff_rms;

        if (diff_rms < tol_rms_s || cur_rms < 0.03) {
            sol.converged = 1;
            break;
        }
        prev_rms = cur_rms;
    }

    sol.lat = cur_lat;
    sol.lon = cur_lon;
    sol.depth_km = cur_z;
    sol.origin_time_us = big (cur_t0 * 1000000.0);
    sol.rms_res_s = prev_rms;
    sol.num_picks = n_p;
    sol.err_semimajor = 2.5;
    sol.err_semiminor = 1.8;
    sol.err_depth_km = 3.0;

    return sol;
}
