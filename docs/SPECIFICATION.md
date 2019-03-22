# scarp Technical Specification

This document details the interface contracts, numerical types, binary protocols,
and data structure invariants governing the scarp system.

## 1. Primary Abstract Data Types (Limbo ADTs)

### 1.1 Station Record
```limbo
Station: adt {
    id:       string;      # Network.Station code (e.g. "CI.PAS")
    lat:      real;        # Latitude in decimal degrees [-90.0, 90.0]
    lon:      real;        # Longitude in decimal degrees [-180.0, 180.0]
    elev:     real;        # Elevation above sea level in meters
    vs30:     real;        # Time-averaged shear wave velocity top 30m (m/s)
    gain:     real;        # Sensor counts per (m/s^2)
    sample_rate: real;     # Sampling rate in Hertz (e.g. 100.0)
    enabled:  int;         # 1 if active, 0 if disabled
};
```

### 1.2 Waveform Sample Buffer
```limbo
WaveformSample: adt {
    timestamp: big;        # Microseconds since Unix epoch UTC
    sta_id:    string;     # Station identifier
    chan:      string;     # Component code ("HNZ", "HNN", "HNE")
    val:       real;       # Calibrated ground motion (m/s^2)
};

TraceWindow: adt {
    sta_id:    string;
    chan:      string;
    start_us:  big;
    rate:      real;
    samples:   array of real;
};
```

### 1.3 Trigger Pick
```limbo
PhasePick: adt {
    sta_id:     string;
    phase:      string;    # "P" or "S"
    time_us:    big;       # Microseconds since epoch
    snr:        real;      # Signal to noise ratio at trigger
    kurtosis:   real;      # 4th moment onset metric
    amplitude:  real;      # Peak raw amplitude in trigger window
    weight:     real;      # Uncertainty weight in [0.0, 1.0]
    quality:    int;       # Integer quality flag (0=best, 4=poor)
};
```

### 1.4 Hypocenter Solution
```limbo
HypoSolution: adt {
    event_id:      string;
    origin_time_us: big;   # Origin time in microseconds UTC
    lat:           real;   # Latitude in degrees
    lon:           real;   # Longitude in degrees
    depth_km:      real;   # Focal depth in kilometers
    rms_residual:  real;   # Root mean square travel-time residual (seconds)
    num_stations:  int;    # Station count used in inversion
    gap_deg:       real;   # Maximum azimuthal gap in degrees [0, 360]
    semimajor_km:  real;   # 95% confidence ellipse semi-major axis (km)
    semiminor_km:  real;   # 95% confidence ellipse semi-minor axis (km)
    strike_deg:    real;   # Error ellipse azimuth (degrees)
    depth_err_km:  real;   # Vertical depth uncertainty (km)
};
```

### 1.5 Magnitude Estimate
```limbo
MagnitudeEstimate: adt {
    event_id:      string;
    mag_type:      string; # "Mpd", "Mtc", "Mw_comb"
    magnitude:     real;   # Estimated moment magnitude
    uncertainty:   real;   # Standard deviation sigma
    station_count: int;    # Number of reporting stations
    tau_c_median:  real;   # Median characteristic period (s)
    pd_median:     real;   # Median peak displacement (cm)
    energy_joules: real;   # Radiated seismic energy log10(E) = 4.8 + 1.5*M
};
```

### 1.6 ShakeMap Grid Cell
```limbo
ShakeMapCell: adt {
    lat:           real;
    lon:           real;
    pga_pct_g:     real;   # Peak ground acceleration (% of gravity)
    pgv_cms:       real;   # Peak ground velocity (cm/s)
    psa_03s:       real;   # 0.3s Spectral acceleration (%g)
    psa_10s:       real;   # 1.0s Spectral acceleration (%g)
    psa_30s:       real;   # 3.0s Spectral acceleration (%g)
    mmi:           real;   # Instrumental Modified Mercalli Intensity
    warning_tti_s: real;   # Time to S-wave arrival (seconds, negative if passed)
};
```

## 2. Inversion Constraints and Convergence Tolerances

The Gauss-Newton hypocenter solver must satisfy the following invariants:
1. Max Iterations: 50 iterations.
2. Step Size Norm Threshold: $||\Delta \mathbf{m}||_2 < 10^{-4}\text{ km}$.
3. Depth Floor: $z \ge 1.0\text{ km}$ (air quakes clamped to minimum physical depth).
4. Residual Tolerance: Convergence halted when $\Delta \text{RMS} < 10^{-5}\text{ s}$.
5. Levenberg-Marquardt Parameter $\lambda$: Initialized to $10^{-2}$; scaled by
   factor 5.0 upon residual increase, and factor 0.2 upon residual decrease.

## 3. MiniSEED Telemetry Invariants

MiniSEED record format follows SEED standard version 2.4:
- Fixed section of Data Header (48 bytes):
  - Sequence number: 6 ASCII digits.
  - Quality indicator: 'D', 'R', 'Q', or 'M'.
  - Station code: 5 ASCII characters (space padded).
  - Location code: 2 ASCII characters.
  - Channel code: 3 ASCII characters.
  - Network code: 2 ASCII characters.
  - Record start time: BTIME structure (10 bytes).
  - Number of samples: 2 bytes (unsigned 16-bit integer).
  - Sample rate factor and multiplier: 2 bytes each (signed 16-bit).
  - Number of blockettes: 1 byte.
  - Time correction: 4 bytes.
  - Beginning of data: 2 bytes.
  - Beginning of first blockette: 2 bytes.
- Steim-2 difference compression frames (64 bytes each, 16 32-bit words).

## 4. Styx / 9P Message Format Specifications

Styx messages conform to 9P2000 standard over byte streams:
- Message length: 4-byte little-endian unsigned integer (including length prefix).
- Message type: 1-byte opcode.
- Tag: 2-byte transaction identifier.
- Message payloads:
  - `Tversion` (type 100), `Rversion` (type 101)
  - `Tauth` (type 102), `Rauth` (type 103)
  - `Tattach` (type 104), `Rattach` (type 105)
  - `Twalk` (type 110), `Rwalk` (type 111)
  - `Topen` (type 112), `Ropen` (type 113)
  - `Tread` (type 116), `Rread` (type 117)
  - `Twrite` (type 118), `Rwrite` (type 119)
  - `Tclunk` (type 120), `Rclunk` (type 121)
