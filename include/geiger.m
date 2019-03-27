# geiger.m: Non-Linear Hypocenter Inversion Interface

GeigerLocator: module
{
    PATH: con "/dis/geiger.dis";

    # Crustal Velocity Model (1D Layered)
    VelocityModel: adt {
        num_layers: int;
        top_depth_km: array of real;
        vp_kms:       array of real;
        vs_kms:       array of real;

        create_default: fn(): ref VelocityModel;
        calc_travel_time: fn(m: self ref VelocityModel, phase: int,
                             source_depth_km: real, epicentral_dist_km: real): (real, real, real);
    };

    # Inversion Configuration
    SolverConfig: adt {
        max_iterations:  int;
        damping_lambda:  real;
        step_tolerance:  real;
        depth_floor_km:  real;
        use_huber_weights: int;
    };

    # Geiger Inversion Engine
    locate_event: fn(picks: list of ref Scarp->PhasePick,
                     stations: list of ref Scarp->Station,
                     vmodel: ref VelocityModel,
                     cfg: ref SolverConfig): ref Scarp->HypoSolution;
};
