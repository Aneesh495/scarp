# scarp

A high-throughput seismic early warning, distributed waveform telemetry processor, and real-time earthquake rupture kinematic inversion engine in Limbo with C11 SIMD acceleration and Styx/9P synthetic filesystem architecture.

![Test Suite](https://img.shields.io/badge/tests-7%20passed-brightgreen.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Limbo: Inferno](https://img.shields.io/badge/Limbo-Inferno%20CSP-purple.svg)
![C11: POSIX](https://img.shields.io/badge/C11-SIMD%20Fastpath-orange.svg)
![Protocol: 9P2000](https://img.shields.io/badge/Protocol-Styx%209P2000-teal.svg)

```
       +-----------------------------------------------------------------+
       |                              scarp                              |
       |     High-Throughput Seismic Early Warning & Inversion Engine    |
       +-----------------------------------------------------------------+
                                        |
       +--------------------------------+--------------------------------+
       |                                |                                |
       v                                v                                v
+---------------+              +-----------------+              +-----------------+
|  Limbo Core   |              |  C Acceleration |              |  Python & Tools |
|  - CSP Actors |              |  - SIMD Filters |              |  - Unified CLI  |
|  - 9P / Styx  | <==========> |  - Fast Geiger  | <==========> |  - Web Server   |
|  - Associator |  Styx / IPC  |  - Steim-2 Bit  |    ctypes    |  - Benchmarking |
|  - ShakeMap   |              |  - Vector GMPE  |              |  - Test Runner  |
+---------------+              +-----------------+              +-----------------+
```

---

## 1. Overview and Core Philosophy

`scarp` is an operational-grade earthquake early warning (EEW) and finite-fault kinematic inversion engine designed for sub-second alert latency. The core architectural heart is written in Limbo, utilizing Communicating Sequential Processes (CSP) micro-threads, typed buffered channels, and a Plan 9 / Inferno Styx (9P2000) synthetic file system interface.

When destructive earthquakes occur, primary compressional waves ($P$-waves) travel through the Earth's crust at approximately $6.0\text{ km/s}$, followed by destructive shear waves ($S$-waves) and surface waves traveling at $3.5\text{ km/s}$. Electronic telemetry travels at near the speed of light ($300,000\text{ km/s}$). By detecting P-waves within milliseconds of arrival at near-source stations, `scarp` computes the hypocenter, inverts for moment magnitude ($M_w$), evaluates finite-fault directivity Doppler shifts, and synthesizes 2D Ground Motion Prediction fields (ShakeMap) to deliver vital warning countdowns to urban centers before destructive shaking arrives.

---

## 2. System Architecture and Concurrency Model

All processing stages run as decoupled communicating sequential processes linked by typed channels:

```
[Seismic Feeds] (100-200 Hz 3-Component MiniSEED Streams)
       |
       v
[Station Ingest Worker] (chan of WaveformPacket)
       |
       v
[Causal DSP & Trigger Filter] (STA/LTA, recursive energy ratio, kurtosis)
       |
       v
[Phase Associator] (chan of TriggerPick)
       |  (Equal Differential Time clustering, ghost pick rejection)
       v
[Event Hypocenter Locator] (chan of EventCandidate)
       |  (Damped Gauss-Newton non-linear least squares, AK135 travel times)
       v
[Magnitude & Rupture Estimator] (chan of HypocenterSol)
       |  (Pd / tau_c scaling, Bayesian pooling, directivity factor)
       v
[ShakeMap & Alert Dispatcher] (chan of ShakeMapGrid)
       |
       +---> [Styx 9P File Server] (/dev/scarp/events, /dev/scarp/shakemap)
       +---> [OASIS CAP / QuakeML Broadcaster] (Emergency Warning Feeds)
       +---> [Interactive Web Workbench] (WebSocket / HTTP Telemetry)
```

---

## 3. Mathematical Foundations

### 3.1 Causal Digital Signal Processing and Kurtosis Onset
Continuous acceleration records $a[n]$ are filtered through a 4th-order causal Butterworth bandpass filter ($0.075\text{ Hz} \le f \le 3.0\text{ Hz}$). Real-time triggering evaluates recursive Short-Term Average to Long-Term Average (STA/LTA) energy ratios:

$$\text{STA}[n] = (1 - C_{\text{sta}}) \cdot \text{STA}[n-1] + C_{\text{sta}} \cdot C F[n]$$
$$\text{LTA}[n] = (1 - C_{\text{lta}}) \cdot \text{LTA}[n-1] + C_{\text{lta}} \cdot C F[n]$$

Arrival onset refinement evaluates the sliding 4th-order sample kurtosis:

$$\text{Kurt}[k] = \frac{\frac{1}{W} \sum_{j=k-W+1}^k (x[j] - \bar{x})^4}{\left(\frac{1}{W} \sum_{j=k-W+1}^k (x[j] - \bar{x})^2\right)^2}$$

The P-wave arrival pick corresponds to the maximum discrete kurtosis gradient $\arg\max_k (\text{Kurt}[k] - \text{Kurt}[k-1])$.

### 3.2 Non-Linear Hypocenter Inversion (Geiger's Method)
Given observation picks $t_{\text{obs}, i}$ and travel-time functions $T_i(\mathbf{m})$, the system solves the linearized normal equations with Levenberg-Marquardt damping and Huber M-estimation:

$$(\mathbf{A}^T \mathbf{W} \mathbf{A} + \lambda \mathbf{I}) \Delta \mathbf{m} = \mathbf{A}^T \mathbf{W} \mathbf{r}$$

where $A_{i, 1} = \frac{\partial T_i}{\partial x}$, $A_{i, 2} = \frac{\partial T_i}{\partial y}$, $A_{i, 3} = \frac{\partial T_i}{\partial z}$, $A_{i, 4} = 1.0$.

### 3.3 Real-Time Magnitude Scaling ($P_d$ and $\tau_c$)
From the initial 3 seconds of the P-wave window:
- Peak Ground Displacement $P_d$:
  $$M_{pd} = \frac{\log_{10}(P_d) + 1.35 \log_{10}(R) + 4.34}{0.82}$$
- Characteristic Period $\tau_c$:
  $$\tau_c = \frac{2\pi}{\sqrt{r}}, \quad r = \frac{\int_0^\tau v(t)^2 dt}{\int_0^\tau u(t)^2 dt}, \quad M_{tc} = \frac{\log_{10}(\tau_c) + 1.30}{0.29}$$

### 3.4 Azimuthal Doppler Directivity
For unilateral finite-fault rupture at velocity $v_r \approx 0.85 v_s$:

$$C_d = \frac{1}{1 - \frac{v_r}{v_s} \cos\theta}$$

where $\theta$ is the angle between fault strike and target azimuth. Forward directivity ($\theta \to 0^\circ$) amplifies peak ground acceleration by $C_d^{0.35} \approx 1.6\times$ to $2.5\times$.

---

## 4. Repository Layout

```
scarp/
|-- Makefile                    # Master build, test, and benchmark targets
|-- LICENSE                     # MIT License
|-- README.md                   # System documentation and architecture monograph
|-- include/                    # Limbo module declarations (.m)
|   |-- sys.m                   # Inferno system interface
|   |-- scarp.m                 # Master seismic ADTs and channel types
|   |-- dsp.m                   # Causal IIR and STA/LTA specifications
|   |-- assoc.m                 # Phase associator and EDT specifications
|   |-- geiger.m                # Geiger non-linear inversion interfaces
|   |-- magnitude.m             # Pd and tau_c magnitude scaling interfaces
|   |-- rupture.m               # Kinematic fault and directivity interfaces
|   |-- shakemap.m              # Ground Motion Prediction Equation interfaces
|   |-- styx.m                  # Plan 9 / Inferno Styx 9P2000 message types
|   |-- styxlib.m               # Styx connection and fid pool interfaces
|   `-- protocol.m              # OASIS CAP, QuakeML, and GeoJSON interfaces
|-- limbo/                      # Pure Limbo implementations (.b)
|   |-- telemetry_buf.b         # Lock-free circular ring buffer
|   |-- dsp_filter.b            # Butterworth 4th-order causal bandpass filter
|   |-- dsp_trigger.b           # Recursive STA/LTA energy ratio detector
|   |-- dsp_kurtosis.b          # Sliding kurtosis onset picker
|   |-- dsp_integral.b          # Highpass-filtered trapezoidal double integration
|   |-- assoc_edt.b             # Equal Differential Time multi-station associator
|   |-- assoc_cluster.b         # Spatial-temporal graph-clique phase clusterer
|   |-- assoc_ghost.b           # Outlier rejection and false pick filter
|   |-- travel_time.b           # 1D layered crustal ray tracer
|   |-- travel_partials.b       # Analytical Jacobian partial derivatives
|   |-- geiger_solver.b         # Gauss-Newton non-linear least squares solver
|   |-- geiger_damping.b        # Levenberg-Marquardt adaptive damping
|   |-- geiger_depth.b          # Depth-freezing and air-quake penalty function
|   |-- geiger_covar.b          # Covariance matrix and 95% error ellipsoid
|   |-- geiger_robust.b         # Huber M-estimator robust IRLS reweighting
|   |-- magnitude_pd.b          # Real-time peak displacement magnitude scaling
|   |-- magnitude_tauc.b        # Characteristic period tau_c frequency scaling
|   |-- magnitude_site.b        # Station VS30 site amplification calibration
|   |-- magnitude_bayes.b       # Bayesian multi-station evidence fusion
|   |-- magnitude_energy.b      # Gutenberg-Richter radiated seismic energy budget
|   |-- rupture_fault.b         # Planar fault geometry and distance metrics
|   |-- rupture_kinematics.b    # Kinematic rupture propagation and isochrones
|   |-- rupture_directivity.b   # Azimuthal Doppler directivity factor
|   |-- rupture_slip.b          # Multi-asperity kinematic slip inversion
|   |-- rupture_moment.b        # Moment tensor and double-couple focal mechanisms
|   |-- shakemap_gmpe.b         # NGA-West2 Ground Motion Prediction Equations
|   |-- shakemap_grid.b         # 2D spatial grid interpolation with topo proxy
|   |-- shakemap_mmi.b          # Instrumental Modified Mercalli Intensity mapping
|   |-- shakemap_tti.b          # S-wave wavefront and time-to-impact countdown
|   |-- protocol_mseed.b        # MiniSEED fixed header parser and Steim-2 reader
|   |-- protocol_export.b       # OASIS CAP v1.2, QuakeML, and GeoJSON exporters
|   |-- styx_server.b           # 9P2000 Styx protocol dispatcher
|   |-- styx_vfs.b              # Synthetic /dev/scarp file tree hierarchy
|   |-- scarp_pipeline.b        # CSP multi-stage actor pipeline
|   `-- scarp_supervisor.b      # Backpressure watchdog and load-shedding
|-- src/c/                      # C11 SIMD acceleration and Dis VM interpreter
|   |-- dis_vm.h / dis_vm.c     # Dis bytecode virtual machine and CSP channels
|   |-- fast_dsp.h / fast_dsp.c # SIMD 64-bit recursive IIR and STA/LTA
|   |-- fast_geiger.h / .c      # Accelerated damped Gauss-Newton solver
|   |-- fast_gmpe.h / .c        # Vectorized NGA-West2 2D grid rasterizer
|   `-- steim2_decode.h / .c    # High-throughput Steim-2 decompression
|-- tools/                      # Tooling and unified CLI
|   |-- scarp_cli.py            # Master CLI orchestrator
|   `-- check_em_dashes.py      # Zero em dash enforcement gate
|-- web/                        # Zero-dependency interactive web workbench
|   |-- index.html              # Workbench dashboard and urgent alert banner
|   |-- style.css               # Terminal GIS dark aesthetic
|   `-- app.js                  # Waveform oscilloscope and ShakeMap visualizer
|-- benchmarks/                 # Structured performance benchmarks
|   |-- benchmark_suite.py      # Benchmark runner orchestrator
|   `-- benchmark_results.json  # Telemetry output
|-- examples/                   # Historic earthquake replay scenarios
|   |-- 01_napa_m60_replay/     # 2014 South Napa M6.0 earthquake replay
|   `-- 02_ridgecrest_m71_directivity/ # 2019 Ridgecrest M7.1 directivity
`-- tst/                        # Comprehensive test suites
    |-- test_dis_vm.py          # Dis VM opcode and channel synchronization tests
    |-- test_dsp.py             # Causal IIR, STA/LTA, and integration unit tests
    |-- test_geiger.py          # Geiger hypocenter inversion convergence tests
    |-- test_magnitude.py       # Pd, tau_c, and Bayesian pooling unit tests
    |-- test_shakemap.py        # GMPE attenuation and Wald MMI unit tests
    |-- test_regression.py      # Documented regression tests for resolved defects
    `-- test_fuzz.py            # Randomized timing jitter and waveform fuzzing
```

---

## 5. Quickstart

### 5.1 Prerequisites
- C Compiler: `clang` or `gcc` with C11 support and POSIX threads.
- Python: `python3` (3.10+).
- Operating System: macOS (Apple Silicon / Intel) or Linux (x86-64 / arm64).

### 5.2 Build and Verify
```sh
# 1. Run diagnostic checks
make doctor

# 2. Compile C11 SIMD acceleration library
make build

# 3. Execute comprehensive test suite (unit, regression, fuzz)
make test

# 4. Run performance benchmarks
make bench

# 5. Launch interactive web workbench
make web
```

Open `http://127.0.0.1:8765` in your browser to inspect live 100 Hz 3-component seismograms, observe expanding P and S wavefronts on the interactive GIS map, and test real-time warning countdowns across historic earthquake scenarios.

---

## 6. License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
