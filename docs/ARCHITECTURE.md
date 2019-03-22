# System Architecture of scarp

scarp is a high-throughput seismic early warning (EEW) engine, distributed
waveform telemetry processor, and real-time earthquake rupture kinematic
inversion system. The core architectural heart is written in Limbo, utilizing
Communicating Sequential Processes (CSP) micro-threads, typed buffered channels,
and a synthetic Plan 9 / Inferno Styx (9P2000) file server interface. High-rate
numerical operations are accelerated through C11 SIMD primitives.

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
|  - Associator |  Styx / IPC  |  - Steim-2 Bit  |   ctypes     |  - Benchmarking |
|  - ShakeMap   |              |  - Vector GMPE  |              |  - Test Runner  |
+---------------+              +-----------------+              +-----------------+
```

## 1. Concurrency and Process Model

The architecture decouples telemetry ingestion, signal triggering, phase
association, hypocenter inversion, magnitude estimation, and alert broadcast
into independent concurrent stages linked by typed channels.

```
[Seismic Feeds] (100-200 Hz 3-Component Streams)
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

### 1.1 Channel Types and Buffering Semantics

All communication between stages occurs over typed channels:
- `chan of RawPacket`: Ingests packetized MiniSEED records from station sockets.
- `chan of FilteredTrace`: Carries causal bandpass-filtered velocity samples.
- `chan of TriggerPick`: Carries validated P-wave and S-wave arrival picks.
- `chan of AssociatedEvent`: Carries bound clusters of multi-station picks.
- `chan of HypoSolution`: Emits converged hypocenter, origin time, and covariance.
- `chan of MagnitudeSol`: Carries real-time moment magnitude estimates.
- `chan of RuptureField`: Carries finite-fault line source and directivity models.
- `chan of ShakeGrid`: Dispatches interpolated ground motion fields and MMI contours.

Channels use bounded ring buffers. If downstream processing stalls, non-blocking
channel selection (`alt`) sheds non-critical telemetry frames while preserving
all trigger picks and hypocenter updates.

## 2. Mathematical Foundations

### 2.1 Causal Digital Signal Processing

Continuous acceleration records $a[n]$ are sampled at $f_s \in [50, 200]\text{ Hz}$.
DC bias and baseline wander are eliminated via a recursive high-pass filter:

$$y[n] = \alpha (y[n-1] + x[n] - x[n-1])$$

where $\alpha = \frac{2\pi f_c / f_s}{1 + 2\pi f_c / f_s}$.

Bandpass filtering employs a 4th-order causal Butterworth filter with low cutoff
$f_L = 0.075\text{ Hz}$ and high cutoff $f_H = 3.0\text{ Hz}$.

Trigger detection evaluates the instantaneous Short-Term Average to Long-Term
Average ratio (STA/LTA):

$$\text{STA}[n] = (1 - C_{\text{sta}}) \cdot \text{STA}[n-1] + C_{\text{sta}} \cdot C F[n]$$
$$\text{LTA}[n] = (1 - C_{\text{lta}}) \cdot \text{LTA}[n-1] + C_{\text{lta}} \cdot C F[n]$$

where $C F[n] = a[n]^2 + k \cdot \dot{a}[n]^2$ is the characteristic energy function.
Trigger onset occurs when $R[n] = \frac{\text{STA}[n]}{\text{LTA}[n]} \ge \eta_{\text{on}}$,
typically configured with $\eta_{\text{on}} \in [4.0, 8.0]$.

### 2.2 Microsecond Onset Refinement via Sliding Kurtosis

To refine the precise P-wave arrival index within the trigger window, scarp
computes the 4th-order statistical sample kurtosis over a sliding window of length $W$:

$$\text{Kurt}[k] = \frac{\frac{1}{W}\sum_{j=k-W+1}^k (x[j] - \bar{x})^4}{\left(\frac{1}{W}\sum_{j=k-W+1}^k (x[j] - \bar{x})^2\right)^2}$$

The pick time $t_P$ corresponds to the inflection point where the kurtosis
gradient $\frac{d\text{Kurt}}{dt}$ achieves its maximum value.

### 2.3 Equal Differential Time (EDT) Association

For stations $i$ and $j$ observing picks at times $t_i$ and $t_j$, the differential
travel time residual for a trial hypocenter $\mathbf{x} = (x, y, z)$ is:

$$r_{ij}(\mathbf{x}) = (t_i - t_j) - (T_i(\mathbf{x}) - T_j(\mathbf{x}))$$

The EDT probability density function surfaces spatial intersections of hyperbolic
surfaces without requiring an estimated origin time $t_0$:

$$P_{\text{EDT}}(\mathbf{x}) = \exp\left( -\frac{1}{2}\sum_{i=1}^{N-1}\sum_{j=i+1}^N \frac{r_{ij}(\mathbf{x})^2}{\sigma_{ij}^2} \right)$$

### 2.4 Geiger's Method with Damped Gauss-Newton Inversion

Given a trial hypocenter $\mathbf{m}_k = (x_k, y_k, z_k, t_{0,k})^T$, the observed
arrival time residual vector is:

$$\mathbf{r}_k = \mathbf{t}_{\text{obs}} - \mathbf{T}(\mathbf{m}_k)$$

Linearizing via Taylor expansion yields:

$$\mathbf{A} \Delta \mathbf{m} = \mathbf{r}_k$$

where the Jacobian elements are:

$$A_{i,1} = \frac{\partial T_i}{\partial x}, \quad A_{i,2} = \frac{\partial T_i}{\partial y}, \quad A_{i,3} = \frac{\partial T_i}{\partial z}, \quad A_{i,4} = 1$$

To handle ill-conditioned station geometry, Levenberg-Marquardt damping is applied:

$$(\mathbf{A}^T \mathbf{W} \mathbf{A} + \lambda \mathbf{I}) \Delta \mathbf{m} = \mathbf{A}^T \mathbf{W} \mathbf{r}_k$$

The weighting matrix $\mathbf{W}$ incorporates Huber M-estimation to down-weight
outliers and pick timing uncertainties.

### 2.5 Real-Time Magnitude Estimation ($P_d$ and $\tau_c$)

Within the initial 3 seconds following the P-wave pick, scarp computes:

1. Peak Ground Displacement $P_d$:
   $$M_{pd} = a \cdot \log_{10}(P_d) + b \cdot \log_{10}(R) + c$$
   where $R$ is hypocentral distance in kilometers.

2. Characteristic Period $\tau_c$:
   $$r = \frac{\int_0^{\tau} \dot{u}(t)^2 dt}{\int_0^{\tau} u(t)^2 dt}, \quad \tau_c = \frac{2\pi}{\sqrt{r}}$$
   $$M_{tc} = \alpha \cdot \log_{10}(\tau_c) + \beta$$

3. Multi-Station Bayesian Pooling:
   Station estimates are combined using inverse-variance weights adjusted for
   local site amplification shear wave velocity $V_{S30}$.

### 2.6 Finite-Fault Rupture Kinematics and Directivity

For larger earthquakes ($M_w \ge 6.0$), point-source assumptions fail. scarp
tracks rupture propagation along a bilateral or unilateral fault trace:

$$C_d = \frac{1}{1 - \frac{v_r}{v_s} \cos\theta}$$

where $v_r \approx 0.85 v_s$ is rupture velocity and $\theta$ is the angle
between the rupture propagation vector and the ray path to the site. Sites
located in the forward rupture direction experience compressed duration and
substantially amplified peak ground acceleration (PGA).

### 2.7 ShakeMap Intensity Synthesis

Ground Motion Prediction Equations (GMPEs / GMMs) compute median expected motion
and total aleatory standard deviation $\sigma$:

$$\ln Y = f_{\text{mag}}(M_w) + f_{\text{dist}}(R_{\text{rup}}, M_w) + f_{\text{site}}(V_{S30}) + \epsilon$$

Calculated metrics:
- Peak Ground Acceleration (PGA) in $\%g$.
- Peak Ground Velocity (PGV) in $\text{cm/s}$.
- Pseudo-Spectral Acceleration (PSA) at $T = 0.3\text{ s}, 1.0\text{ s}, 3.0\text{ s}$.
- Instrumental Modified Mercalli Intensity (MMI I to X+).

## 3. Styx / 9P Synthetic File System

Following Inferno architecture, scarp exposes all internal state via a synthetic
file tree mountable over TCP or local pipes:

```
/dev/scarp/
  |-- ctl          # Command interface (text commands for config and thresholds)
  |-- status       # JSON status snapshot (uptime, event count, thread states)
  |-- feed         # Binary or ASCII waveform input stream
  |-- picks        # Live streaming event stream of arrival picks
  |-- events       # Real-time hypocenter and magnitude solutions
  |-- shakemap     # GeoJSON or grid raster of interpolated ground motions
  |-- stations     # Station inventory and VS30 geology metadata
  `-- stats        # Performance counters and latency statistics
```

Standard Styx 9P2000 protocol messages (`Tversion`, `Tattach`, `Twalk`, `Topen`,
`Tread`, `Twrite`, `Tclunk`) allow external applications to monitor, configure,
and consume seismic telemetry without proprietary drivers.
