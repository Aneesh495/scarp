# dsp_integral.b: Trapezoidal Double Integration and Peak Metrics in Limbo
implement DSPIntegral;

include "sys.m";
    sys: Sys;

include "dsp.m";
    dsp: SeismicDSP;

DSPIntegral: module
{
    PATH: con "/dis/dsp_integral.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    integrate_acc_to_vel: fn(acc: array of real, dt: real, fl_hz: real): array of real;
    integrate_vel_to_disp: fn(vel: array of real, dt: real, fl_hz: real): array of real;
    compute_peaks: fn(acc: array of real, dt: real, fl_hz: real): (real, real, real, real);
};

PI: con 3.141592653589793;

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

integrate_acc_to_vel(acc: array of real, dt: real, fl_hz: real): array of real
{
    if (acc == nil || len acc == 0 || dt <= 0.0) return array[0] of real;
    n := len acc;
    vel := array[n] of real;

    vel[0] = 0.0;
    for (i := 1; i < n; i++) {
        vel[i] = vel[i - 1] + 0.5 * (acc[i] + acc[i - 1]) * dt;
    }

    # High-pass filter to remove linear baseline drift
    alpha := 1.0 - (2.0 * PI * fl_hz * dt);
    if (alpha < 0.90) alpha = 0.90;
    if (alpha > 0.999) alpha = 0.999;

    for (i = 1; i < n; i++) {
        vel[i] = alpha * (vel[i - 1] + vel[i] - vel[i - 1]);
    }

    return vel;
}

integrate_vel_to_disp(vel: array of real, dt: real, fl_hz: real): array of real
{
    if (vel == nil || len vel == 0 || dt <= 0.0) return array[0] of real;
    n := len vel;
    disp := array[n] of real;

    disp[0] = 0.0;
    for (i := 1; i < n; i++) {
        disp[i] = disp[i - 1] + 0.5 * (vel[i] + vel[i - 1]) * dt;
    }

    alpha := 1.0 - (2.0 * PI * fl_hz * dt);
    if (alpha < 0.90) alpha = 0.90;
    if (alpha > 0.999) alpha = 0.999;

    for (i = 1; i < n; i++) {
        disp[i] = alpha * (disp[i - 1] + disp[i] - disp[i - 1]);
    }

    return disp;
}

compute_peaks(acc: array of real, dt: real, fl_hz: real): (real, real, real, real)
{
    if (acc == nil || len acc == 0) return (0.0, 0.0, 0.0, 0.0);
    n := len acc;

    vel := integrate_acc_to_vel(acc, dt, fl_hz);
    disp := integrate_vel_to_disp(vel, dt, fl_hz);

    max_a := 0.0;
    max_v := 0.0;
    max_d := 0.0;
    cav := 0.0;

    for (i := 0; i < n; i++) {
        a := acc[i];
        if (a < 0.0) a = -a;
        if (a > max_a) max_a = a;

        v := vel[i];
        if (v < 0.0) v = -v;
        if (v > max_v) max_v = v;

        d := disp[i];
        if (d < 0.0) d = -d;
        if (d > max_d) max_d = d;

        cav += a * dt;
    }

    # Units: pga (%g), pgv (cm/s), pd (cm), cav (cm/s)
    pga_pct_g := (max_a / 9.80665) * 100.0;
    pgv_cms := max_v * 100.0;
    pd_cm := max_d * 100.0;
    cav_cms := cav * 100.0;

    return (pga_pct_g, pgv_cms, pd_cm, cav_cms);
}
