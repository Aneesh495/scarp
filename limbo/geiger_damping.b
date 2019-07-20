# geiger_damping.b: Adaptive Levenberg-Marquardt Damping in Limbo
implement GeigerDamping;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "geiger.m";
    geiger: GeigerLocator;

DampingState: adt {
    lambda:        real;
    nu:            real;
    min_lambda:    real;
    max_lambda:    real;
    consecutive_up: int;
};

GeigerDamping: module
{
    PATH: con "/dis/geiger_damping.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    create_state:  fn(init_lambda: real, nu: real): ref DampingState;
    update_lambda: fn(st: ref DampingState, residual_decreased: int): real;
    apply_marquardt_damping: fn(AtA: array of array of real, lambda: real);
};

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

create_state(init_lambda: real, nu: real): ref DampingState
{
    st := ref DampingState;
    st.lambda = (init_lambda > 0.0 ? init_lambda : 0.01);
    st.nu = (nu > 1.0 ? nu : 2.5);
    st.min_lambda = 1e-6;
    st.max_lambda = 100.0;
    st.consecutive_up = 0;
    return st;
}

update_lambda(st: ref DampingState, residual_decreased: int): real
{
    if (st == nil) return 0.01;

    if (residual_decreased != 0) {
        # Successful step: decrease damping to approach Gauss-Newton quadratic rate
        st.lambda /= st.nu;
        if (st.lambda < st.min_lambda) st.lambda = st.min_lambda;
        st.consecutive_up = 0;
    } else {
        # Unsuccessful step: increase damping to approach gradient descent step
        st.lambda *= st.nu;
        if (st.lambda > st.max_lambda) st.lambda = st.max_lambda;
        st.consecutive_up++;
    }

    return st.lambda;
}

apply_marquardt_damping(AtA: array of array of real, lambda: real)
{
    if (AtA == nil) return;
    n := len AtA;
    for (i := 0; i < n; i++) {
        diag := AtA[i][i];
        if (diag < 0.0) diag = -diag;
        if (diag < 1e-6) diag = 1.0;
        AtA[i][i] += lambda * diag;
    }
}
