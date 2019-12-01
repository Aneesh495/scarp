# Styx / 9P2000 Protocol Interface in scarp

This document details the Plan 9 / Inferno Styx (9P2000) synthetic file system
exposed by scarp, allowing external systems to monitor, configure, and stream
seismic telemetry without custom client libraries.

## 1. Overview of 9P2000 Architecture

In Plan 9 and Inferno, "everything is a file" and every service is exposed as a
hierarchical file tree served over the Styx / 9P protocol. Channels and files
share a unified namespace.

scarp runs a built-in Styx server listening on TCP (default port `9999`) or Unix
domain sockets, serving the `/dev/scarp/` synthetic filesystem.

```
/dev/scarp/
  |-- ctl          # Control channel for runtime parameters
  |-- status       # JSON status snapshot of active threads
  |-- feed         # High-rate binary or ASCII waveform input
  |-- picks        # Live stream of P-wave and S-wave arrival picks
  |-- events       # Real-time stream of declared earthquake events
  |-- shakemap     # GeoJSON or raster grid of ground motion fields
  |-- stations     # Station inventory and VS30 geological metadata
  `-- stats        # Pipeline throughput counters and latency metrics
```

## 2. File Node Specifications

### 2.1 `/dev/scarp/ctl` (Read/Write)
Accepts text commands for runtime configuration:
- `threshold <val>`: Sets the STA/LTA trigger threshold (e.g. `threshold 6.5`).
- `freeze_depth <on|off>`: Enables or disables depth freezing heuristic in Geiger locator.
- `model <ak135|california>`: Switches active crustal velocity model.
- `reset`: Clears active event clusters and resets circular ring buffers.
- Reading this file returns current configuration parameters in key-value format.

### 2.2 `/dev/scarp/feed` (Write-Only)
Accepts raw streaming seismic records in either 512-byte MiniSEED packets or
comma-separated ASCII format (`station,channel,timestamp_us,acceleration_mps2`).
Bytes written to `/dev/scarp/feed` are directly dispatched onto the Limbo
`raw_in` channel.

### 2.3 `/dev/scarp/picks` (Read-Only Stream)
An infinite streaming file emitting newline-delimited arrival picks as they are
detected by the Kurtosis onset picker:

```json
{"station":"CI.PAS","phase":"P","timestamp_us":1710000004820000,"snr":14.2,"weight":1.0}
{"station":"CI.USC","phase":"P","timestamp_us":1710000006120000,"snr":11.8,"weight":0.95}
```

### 2.4 `/dev/scarp/events` (Read-Only Stream)
Emits declared earthquakes upon hypocenter convergence and magnitude estimation:

```json
{
  "event_id": "EVT-2026-NAPA-60",
  "origin_time_us": 1710000000000000,
  "latitude": 38.215,
  "longitude": -122.312,
  "depth_km": 11.1,
  "magnitude_mw": 6.02,
  "rms_residual_s": 0.018,
  "stations_used": 6,
  "azimuthal_gap_deg": 52.0
}
```

### 2.5 `/dev/scarp/shakemap` (Read-Only)
Reads generate an RFC 7946 GeoJSON FeatureCollection containing interpolated
grid points and intensity contours.

## 3. Mounting `/dev/scarp/` in Inferno or Plan 9

Using standard Inferno / Plan 9 utilities:

```sh
# Connect and mount scarp Styx server onto /n/scarp
mount -c tcp!localhost!9999 /n/scarp

# Inspect active station inventory
cat /n/scarp/stations

# Monitor live P-wave triggers
cat /n/scarp/picks

# Adjust trigger threshold
echo "threshold 7.0" > /n/scarp/ctl
```
