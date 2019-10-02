# shakemap_mmi.b: Instrumental Modified Mercalli Intensity Mapping in Limbo
implement ShakeMapMMI;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

include "shakemap.m";
    shakemap: ShakeMapEngine;

IntensityDescriptor: adt {
    mmi_value: real;
    roman:     string;
    shaking:   string;
    damage:    string;
    hex_color: string;
};

ShakeMapMMI: module
{
    PATH: con "/dis/shakemap_mmi.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    calc_mmi:         fn(pga_pct_g: real, pgv_cms: real): real;
    get_descriptor:   fn(mmi: real): ref IntensityDescriptor;
};

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

log10_approx(x: real): real
{
    if (x <= 1e-12) return -12.0;
    val := x;
    k := 0;
    while (val > 2.0) {
        val *= 0.5;
        k++;
    }
    while (val < 0.5) {
        val *= 2.0;
        k--;
    }
    y := (val - 1.0) / (val + 1.0);
    y2 := y * y;
    ln_val := 2.0 * y * (1.0 + y2 / 3.0 + (y2 * y2) / 5.0 + (y2 * y2 * y2) / 7.0);
    return (ln_val + real k * 0.6931471805599453) / 2.302585092994046;
}

calc_mmi(pga_pct_g: real, pgv_cms: real): real
{
    mmi_pga := 1.0;
    if (pga_pct_g > 0.0) {
        log_pga := log10_approx(pga_pct_g);
        if (log_pga <= 0.6) {
            mmi_pga = 2.20 * log_pga + 1.00;
        } else {
            mmi_pga = 3.66 * log_pga - 1.66;
        }
    }

    mmi_pgv := 1.0;
    if (pgv_cms > 0.0) {
        log_pgv := log10_approx(pgv_cms);
        if (log_pgv <= 0.7) {
            mmi_pgv = 2.10 * log_pgv + 3.40;
        } else {
            mmi_pgv = 3.47 * log_pgv + 2.35;
        }
    }

    # Low intensities governed by acceleration (human perception)
    # High intensities governed by velocity (structural kinetic energy)
    mmi := 1.0;
    if (mmi_pgv < 5.0) {
        mmi = 0.7 * mmi_pga + 0.3 * mmi_pgv;
    } else {
        mmi = 0.2 * mmi_pga + 0.8 * mmi_pgv;
    }

    if (mmi < 1.0) mmi = 1.0;
    if (mmi > 10.0) mmi = 10.0;

    return mmi;
}

get_descriptor(mmi: real): ref IntensityDescriptor
{
    desc := ref IntensityDescriptor;
    desc.mmi_value = mmi;

    if (mmi < 1.5) {
        desc.roman = "I";
        desc.shaking = "Not felt";
        desc.damage = "None";
        desc.hex_color = "#ffffff";
    } else if (mmi < 2.5) {
        desc.roman = "II";
        desc.shaking = "Weak";
        desc.damage = "None";
        desc.hex_color = "#bfccff";
    } else if (mmi < 3.5) {
        desc.roman = "III";
        desc.shaking = "Weak";
        desc.damage = "None";
        desc.hex_color = "#99b3ff";
    } else if (mmi < 4.5) {
        desc.roman = "IV";
        desc.shaking = "Light";
        desc.damage = "None";
        desc.hex_color = "#80ffff";
    } else if (mmi < 5.5) {
        desc.roman = "V";
        desc.shaking = "Moderate";
        desc.damage = "Very light";
        desc.hex_color = "#7dff7d";
    } else if (mmi < 6.5) {
        desc.roman = "VI";
        desc.shaking = "Strong";
        desc.damage = "Light";
        desc.hex_color = "#ffff00";
    } else if (mmi < 7.5) {
        desc.roman = "VII";
        desc.shaking = "Very strong";
        desc.damage = "Moderate";
        desc.hex_color = "#ffaa00";
    } else if (mmi < 8.5) {
        desc.roman = "VIII";
        desc.shaking = "Severe";
        desc.damage = "Moderate/Heavy";
        desc.hex_color = "#ff5500";
    } else if (mmi < 9.5) {
        desc.roman = "IX";
        desc.shaking = "Violent";
        desc.damage = "Heavy";
        desc.hex_color = "#ff0000";
    } else {
        desc.roman = "X+";
        desc.shaking = "Extreme";
        desc.damage = "Very Heavy";
        desc.hex_color = "#cc0000";
    }

    return desc;
}
