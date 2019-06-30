# travel_time.b: 1D Layered Ray Tracer and Travel-Time Evaluator in Limbo
implement TravelTime;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "geiger.m";
    geiger: GeigerLocator;

TravelTime: module
{
    PATH: con "/dis/travel_time.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    calc_travel_time: fn(vm: ref GeigerLocator->VelocityModel,
                         phase: int,
                         hypo_depth_km: real,
                         epicentral_dist_km: real): real;
};

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

calc_travel_time(vm: ref GeigerLocator->VelocityModel,
                 phase: int,
                 hypo_depth_km: real,
                 epicentral_dist_km: real): real
{
    dz := hypo_depth_km;
    if (dz < 0.1) dz = 0.1;
    dist_hypo := sqrt_approx(epicentral_dist_km * epicentral_dist_km + dz * dz);

    # Default average crustal velocity fallback
    v_eff := 6.0;
    if (phase == 2) v_eff = 3.5; # S-wave

    if (vm != nil && vm.num_layers > 0) {
        # Determine focal layer
        focal_layer := 0;
        for (l := 0; l < vm.num_layers; l++) {
            if (hypo_depth_km >= vm.top_depth_km[l]) {
                focal_layer = l;
            }
        }

        if (phase == 2) {
            v_eff = vm.vs_kms[focal_layer];
        } else {
            v_eff = vm.vp_kms[focal_layer];
        }
    }

    # Direct ray arrival time
    t_direct := dist_hypo / v_eff;

    # Check for Moho refracted arrival (Pn) if epicentral distance exceeds crossover
    if (vm != nil && vm.num_layers >= 4 && phase == 1 && epicentral_dist_km > 120.0) {
        # Moho depth and mantle P-velocity
        z_moho := vm.top_depth_km[3]; # 32 km
        v_mantle := vm.vp_kms[3];     # 8.0 km/s

        if (v_mantle > v_eff) {
            # Critical refraction time: T_refr = Delta / V_m + sum(h_i * sqrt(1/V_i^2 - 1/V_m^2))
            cos_ic := sqrt_approx(1.0 - (v_eff * v_eff) / (v_mantle * v_mantle));
            t_intercept := (2.0 * z_moho - hypo_depth_km) * cos_ic / v_eff;
            t_refract := (epicentral_dist_km / v_mantle) + t_intercept;

            if (t_refract < t_direct) {
                return t_refract;
            }
        }
    }

    return t_direct;
}
