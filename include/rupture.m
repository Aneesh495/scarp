# rupture.m: Finite-Fault Rupture Kinematics and Directivity Interface

RuptureKinematics: module
{
    PATH: con "/dis/rupture.dis";

    # Kinematic Segment
    FaultSegment: adt {
        lat_start: real;
        lon_start: real;
        lat_end:   real;
        lon_end:   real;
        strike:    real;
        dip:       real;
        rake:      real;
        slip_m:    real;
    };

    # Compute Doppler Directivity Factor: Cd = 1 / (1 - (vr/vs)*cos(theta))
    calc_directivity_factor: fn(hypo_lat: real, hypo_lon: real,
                                fault_strike_deg: real,
                                site_lat: real, site_lon: real,
                                v_rupture_kms: real, v_shear_kms: real): real;

    # Isochrone Arrival Time
    calc_isochrone_time: fn(hypo_lat: real, hypo_lon: real, hypo_depth_km: real,
                            rupture_dist_km: real, vr_kms: real,
                            site_lat: real, site_lon: real, vs_kms: real): real;
};
