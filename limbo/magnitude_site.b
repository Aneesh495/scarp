# magnitude_site.b: Station VS30 Site Amplification Correction in Limbo
implement MagnitudeSite;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "magnitude.m";
    magnitude: MagnitudeEngine;

MagnitudeSite: module
{
    PATH: con "/dis/magnitude_site.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    get_amplification_factor: fn(vs30_ms: real): real;
    correct_pd_to_rock:       fn(observed_pd_cm: real, vs30_ms: real): real;
    nehrp_class:              fn(vs30_ms: real): string;
};

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

get_amplification_factor(vs30_ms: real): real
{
    vs := vs30_ms;
    if (vs < 120.0) vs = 120.0;
    if (vs > 2000.0) vs = 2000.0;

    # Borcherdt site amplification power law: (760 / VS30)^0.35
    ratio := 760.0 / vs;

    # Approximate x^0.35 via Taylor or iterative power
    # 0.35 ~ 7/20
    # For ratio near 1.0, 1 + 0.35 * (ratio - 1)
    if (ratio >= 0.5 && ratio <= 2.5) {
        amp := 1.0 + 0.35 * (ratio - 1.0);
        return amp;
    }

    if (ratio > 2.5) return 1.55;
    return 0.75;
}

correct_pd_to_rock(observed_pd_cm: real, vs30_ms: real): real
{
    amp := get_amplification_factor(vs30_ms);
    if (amp <= 0.0) amp = 1.0;
    return observed_pd_cm / amp;
}

nehrp_class(vs30_ms: real): string
{
    if (vs30_ms > 1500.0) return "A"; # Hard rock
    if (vs30_ms >= 760.0) return "B"; # Rock
    if (vs30_ms >= 360.0) return "C"; # Very dense soil / soft rock
    if (vs30_ms >= 180.0) return "D"; # Stiff soil
    return "E";                       # Soft clay soil
}
