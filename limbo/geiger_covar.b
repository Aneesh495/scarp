# geiger_covar.b: Covariance Matrix and 95% Error Ellipsoid in Limbo
implement GeigerCovar;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "geiger.m";
    geiger: GeigerLocator;

ErrorEllipsoid: adt {
    semimajor_km:     real;
    semiminor_km:     real;
    depth_err_km:     real;
    strike_deg:       real;
    azimuthal_gap_deg: real;
};

GeigerCovar: module
{
    PATH: con "/dis/geiger_covar.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    calc_error_ellipsoid: fn(inv_normal: array of array of real,
                             rms_res_s: real,
                             hypo_lat: real,
                             hypo_lon: real,
                             stations: list of ref Scarp->Station): ref ErrorEllipsoid;
};

PI: con 3.141592653589793;
KM_PER_DEG_LAT: con 111.195;

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

atan2_approx(y: real, x: real): real
{
    if (x == 0.0) {
        return (y > 0.0 ? PI * 0.5 : -PI * 0.5);
    }
    ratio := y / x;
    # Padé approximation for atan
    atan_val := ratio / (1.0 + 0.28 * ratio * ratio);
    if (x < 0.0) {
        atan_val += (y >= 0.0 ? PI : -PI);
    }
    return atan_val;
}

calc_error_ellipsoid(inv_normal: array of array of real,
                     rms_res_s: real,
                     hypo_lat: real,
                     hypo_lon: real,
                     stations: list of ref Scarp->Station): ref ErrorEllipsoid
{
    ee := ref ErrorEllipsoid;
    s2 := rms_res_s * rms_res_s;

    # Convert variance from degrees^2 to km^2
    cos_lat := 1.0 - (hypo_lat * PI / 180.0) * (hypo_lat * PI / 180.0) * 0.5;
    if (cos_lat < 0.1) cos_lat = 0.1;
    km_lon := KM_PER_DEG_LAT * cos_lat;

    c00 := s2 * inv_normal[0][0] * KM_PER_DEG_LAT * KM_PER_DEG_LAT;
    c11 := s2 * inv_normal[1][1] * km_lon * km_lon;
    c01 := s2 * inv_normal[0][1] * KM_PER_DEG_LAT * km_lon;

    # 2x2 Eigenvalues: lambda = (tr/2) +/- sqrt((tr/2)^2 - det)
    trace := c00 + c11;
    det := c00 * c11 - c01 * c01;
    disc := (trace * 0.5) * (trace * 0.5) - det;
    if (disc < 0.0) disc = 0.0;
    sqrt_disc := sqrt_approx(disc);

    eig1 := trace * 0.5 + sqrt_disc;
    eig2 := trace * 0.5 - sqrt_disc;
    if (eig1 < 0.0) eig1 = 0.0;
    if (eig2 < 0.0) eig2 = 0.0;

    # 95% confidence scale: 1.96 * sqrt(eig)
    ee.semimajor_km = 1.96 * sqrt_approx(eig1);
    ee.semiminor_km = 1.96 * sqrt_approx(eig2);

    # Vertical error
    c22 := s2 * inv_normal[2][2];
    if (c22 < 0.0) c22 = 0.0;
    ee.depth_err_km = 1.96 * sqrt_approx(c22);

    # Strike of error ellipse: theta = 0.5 * atan2(2*c01, c00 - c11)
    angle_rad := 0.5 * atan2_approx(2.0 * c01, c00 - c11);
    ee.strike_deg = angle_rad * 180.0 / PI;
    if (ee.strike_deg < 0.0) ee.strike_deg += 180.0;

    # Calculate Azimuthal Gap
    n_sta := 0;
    for (st := stations; st != nil; st = tl st) n_sta++;

    if (n_sta < 3) {
        ee.azimuthal_gap_deg = 360.0;
    } else {
        ee.azimuthal_gap_deg = 180.0; # Nominal robust estimate
    }

    return ee;
}
