# scarp.m: Master Seismic Early Warning Engine Module Interface

Scarp: module
{
    PATH: con "/dis/scarp.dis";

    # Constants
    MAX_STATIONS:   con 512;
    MAX_TRACE_SAMP: con 4096;
    SAMPLE_RATE_HZ: con 100.0;
    SPEED_OF_LIGHT: con 299792.458; # km/s

    # Station Metadata
    Station: adt {
        id:          string;   # Network.Station (e.g. CI.PAS)
        lat:         real;     # Degrees North
        lon:         real;     # Degrees East
        elev_m:      real;     # Elevation in meters
        vs30_ms:     real;     # Shear wave velocity top 30m
        sample_rate: real;     # Hz (typically 100.0)
        enabled:     int;      # 1 if active, 0 otherwise

        distance_to: fn(s: self ref Station, lat: real, lon: real): real;
        azimuth_to:  fn(s: self ref Station, lat: real, lon: real): real;
    };

    # Single-channel calibrated waveform sample
    WaveformSample: adt {
        timestamp_us: big;     # Microseconds since epoch
        sta_id:       string;
        channel:      string;  # HNZ, HNN, HNE
        val:          real;    # Acceleration in m/s^2
    };

    # Multi-component waveform trace packet
    TracePacket: adt {
        sta_id:       string;
        start_us:     big;
        num_samples:  int;
        sample_rate:  real;
        z_acc:        array of real;
        n_acc:        array of real;
        e_acc:        array of real;
    };

    # Trigger Arrival Pick
    PhasePick: adt {
        sta_id:       string;
        phase_type:   int;     # 1 = P-wave, 2 = S-wave
        time_us:      big;     # Arrival time microseconds
        snr:          real;    # Signal-to-noise ratio
        kurtosis:     real;    # Kurtosis gradient onset metric
        peak_amp:     real;    # Peak amplitude in trigger window
        weight:       real;    # Inversion weight [0.0, 1.0]
        quality:      int;     # Quality class 0-4
    };

    # Hypocenter Solution
    HypoSolution: adt {
        event_id:       string;
        origin_time_us: big;
        lat:            real;
        lon:            real;
        depth_km:       real;
        rms_res_s:      real;
        num_picks:      int;
        azimuthal_gap:  real;
        err_semimajor:  real;  # 95% confidence semi-major km
        err_semiminor:  real;  # 95% confidence semi-minor km
        err_depth_km:   real;  # Vertical uncertainty km
        converged:      int;   # 1 if converged, 0 if diverged
    };

    # Real-Time Magnitude
    MagnitudeSol: adt {
        event_id:       string;
        mag_mw:         real;  # Combined moment magnitude
        mag_mpd:        real;  # Pd-based magnitude
        mag_mtc:        real;  # Tau_c-based magnitude
        uncertainty:    real;  # 1-sigma standard error
        num_stations:   int;
        energy_joules:  real;  # Radiated energy
        p_window_s:     real;  # Elapsed P-wave window (1.0 to 3.0 s)
    };

    # Finite Fault Rupture Kinematics
    RuptureModel: adt {
        event_id:       string;
        strike_deg:     real;  # Strike angle degrees [0, 360]
        dip_deg:        real;  # Dip angle degrees [0, 90]
        rake_deg:       real;  # Rake angle degrees [-180, 180]
        length_km:      real;  # Rupture length
        width_km:       real;  # Rupture down-dip width
        v_rupture_kms:  real;  # Rupture front velocity (~3.0 km/s)
        directivity_az: real;  # Azimuth of forward rupture directivity
    };

    # ShakeMap Grid Cell
    ShakeMapCell: adt {
        lat:            real;
        lon:            real;
        pga_pct_g:      real;  # Peak ground acceleration (%g)
        pgv_cms:        real;  # Peak ground velocity (cm/s)
        psa_03s:        real;  # 0.3s Spectral Acceleration (%g)
        psa_10s:        real;  # 1.0s Spectral Acceleration (%g)
        psa_30s:        real;  # 3.0s Spectral Acceleration (%g)
        mmi:            real;  # Modified Mercalli Intensity [1.0, 10.0]
        tti_seconds:    real;  # Time-to-impact S-wave (negative if arrived)
    };

    # Engine initialization and lifecycle
    init: fn(ctxt: ref Sys->FD, argv: list of string);
};
