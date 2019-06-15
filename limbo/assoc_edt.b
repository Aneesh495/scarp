# assoc_edt.b: Equal Differential Time Multi-Station Associator in Limbo
implement AssocEDT;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "assoc.m";
    assoc: PhaseAssoc;

AssocEDT: module
{
    PATH: con "/dis/assoc_edt.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    calc_differential_residual: fn(t_i_s: real, t_j_s: real,
                                   s_i_lat: real, s_i_lon: real,
                                   s_j_lat: real, s_j_lon: real,
                                   test_lat: real, test_lon: real,
                                   test_z_km: real, vp_kms: real): real;

    eval_edt_likelihood: fn(picks: list of ref Scarp->PhasePick,
                            stations: list of ref Scarp->Station,
                            test_lat: real, test_lon: real,
                            test_z_km: real, vp_kms: real): real;
};

PI: con 3.141592653589793;
KM_PER_DEG: con 111.195;

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

distance_km(lat1: real, lon1: real, lat2: real, lon2: real): real
{
    dlat := (lat2 - lat1) * KM_PER_DEG;
    mid_lat := (lat1 + lat2) * 0.5;
    cos_lat := 1.0 - (mid_lat * PI / 180.0) * (mid_lat * PI / 180.0) * 0.5;
    if (cos_lat < 0.1) cos_lat = 0.1;
    dlon := (lon2 - lon1) * KM_PER_DEG * cos_lat;
    return sqrt_approx(dlat * dlat + dlon * dlon);
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

calc_differential_residual(t_i_s: real, t_j_s: real,
                           s_i_lat: real, s_i_lon: real,
                           s_j_lat: real, s_j_lon: real,
                           test_lat: real, test_lon: real,
                           test_z_km: real, vp_kms: real): real
{
    if (vp_kms <= 0.0) vp_kms = 6.0;

    d_i_epi := distance_km(s_i_lat, s_i_lon, test_lat, test_lon);
    d_j_epi := distance_km(s_j_lat, s_j_lon, test_lat, test_lon);

    d_i_hypo := sqrt_approx(d_i_epi * d_i_epi + test_z_km * test_z_km);
    d_j_hypo := sqrt_approx(d_j_epi * d_j_epi + test_z_km * test_z_km);

    tt_i := d_i_hypo / vp_kms;
    tt_j := d_j_hypo / vp_kms;

    observed_dt := t_i_s - t_j_s;
    calc_dt := tt_i - tt_j;

    residual := observed_dt - calc_dt;
    if (residual < 0.0) residual = -residual;
    return residual;
}

eval_edt_likelihood(picks: list of ref Scarp->PhasePick,
                    stations: list of ref Scarp->Station,
                    test_lat: real, test_lon: real,
                    test_z_km: real, vp_kms: real): real
{
    if (picks == nil || stations == nil) return 0.0;

    # Convert lists to arrays for indexed pair comparison
    n_p := 0;
    cur_p := picks;
    while (cur_p != nil) {
        n_p++;
        cur_p = tl cur_p;
    }
    if (n_p < 3) return 0.0;

    p_arr := array[n_p] of ref Scarp->PhasePick;
    cur_p = picks;
    for (idx := 0; idx < n_p; idx++) {
        p_arr[idx] = hd cur_p;
        cur_p = tl cur_p;
    }

    sum_res_sq := 0.0;
    pair_count := 0;

    for (i := 0; i < n_p - 1; i++) {
        for (j := i + 1; j < n_p; j++) {
            # Find station matching p_arr[i] and p_arr[j]
            s_i: ref Scarp->Station = nil;
            s_j: ref Scarp->Station = nil;

            for (st_list := stations; st_list != nil; st_list = tl st_list) {
                st := hd st_list;
                if (st.id == p_arr[i].sta_id) s_i = st;
                if (st.id == p_arr[j].sta_id) s_j = st;
            }

            if (s_i != nil && s_j != nil) {
                t_i := real (p_arr[i].time_us) / 1000000.0;
                t_j := real (p_arr[j].time_us) / 1000000.0;

                res := calc_differential_residual(t_i, t_j,
                                                  s_i.lat, s_i.lon,
                                                  s_j.lat, s_j.lon,
                                                  test_lat, test_lon,
                                                  test_z_km, vp_kms);
                sum_res_sq += res * res;
                pair_count++;
            }
        }
    }

    if (pair_count == 0) return 0.0;
    rms := sqrt_approx(sum_res_sq / real pair_count);

    # Gaussian likelihood: exp(-rms^2 / (2 * sigma^2)) with sigma = 0.5s
    arg := -(rms * rms) / 0.5;
    if (arg < -20.0) return 0.0;

    # Exp approximation: (1 + arg/32)^32
    base := 1.0 + arg / 32.0;
    if (base < 0.0) return 0.0;
    likelihood := 1.0;
    for (k := 0; k < 32; k++) {
        likelihood *= base;
    }
    return likelihood;
}
