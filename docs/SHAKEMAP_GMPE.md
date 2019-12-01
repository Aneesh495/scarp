# ShakeMap and Ground Motion Modeling in scarp

This monograph documents the Ground Motion Prediction Equations (GMPEs / GMMs),
topographic proxy site response, Instrumental Modified Mercalli Intensity (MMI),
and real-time Time-To-Impact (TTI) alert perimeter algorithms implemented in scarp.

## 1. NGA-West2 Empirical Ground Motion Prediction Equations

scarp implements the functional forms of the NGA-West2 models (Boore et al. BSSA14
and Campbell & Bozorgnia CB14) to compute expected median ground shaking:

$$\ln Y = f_{\text{mag}}(M_w) + f_{\text{dist}}(R_{\text{rup}}, M_w) + f_{\text{site}}(V_{S30}) + f_{\text{mech}}$$

where $Y$ represents:
- Peak Ground Acceleration (PGA) in $\%g$
- Peak Ground Velocity (PGV) in $\text{cm/s}$
- Pseudo-Spectral Acceleration (PSA) at periods $T = 0.3\text{ s}, 1.0\text{ s}, 3.0\text{ s}$

### 1.1 Magnitude Scaling Function $f_{\text{mag}}(M_w)$

$$\begin{aligned}
f_{\text{mag}}(M_w) &= e_0 + e_1 (M_w - M_h) + e_2 (M_w - M_h)^2 \quad &\text{for } M_w \le M_h \\
&= e_0 + e_3 (M_w - M_h) \quad &\text{for } M_w > M_h
\end{aligned}$$

with hinge magnitude $M_h = 6.0$.

### 1.2 Distance Attenuation Function $f_{\text{dist}}(R_{\text{rup}}, M_w)$

$$f_{\text{dist}} = (c_1 + c_2 (M_w - M_{\text{ref}})) \ln\left( \frac{\sqrt{R_{\text{rup}}^2 + h^2}}{R_{\text{ref}}} \right) + c_3 \sqrt{R_{\text{rup}}^2 + h^2}$$

with pseudo-depth $h = 4.5\text{ km}$, reference distance $R_{\text{ref}} = 1.0\text{ km}$,
and reference magnitude $M_{\text{ref}} = 4.5$.

### 1.3 Site Response Function $f_{\text{site}}(V_{S30})$

$$f_{\text{site}} = \gamma \ln\left( \frac{V_{S30}}{V_{\text{ref}}} \right)$$

with reference velocity $V_{\text{ref}} = 760\text{ m/s}$ (B/C boundary rock).

## 2. Instrumental Modified Mercalli Intensity (MMI) Mapping

To translate engineering parameters into perceived shaking and damage severity,
scarp applies the empirical relationships developed by Wald et al. (1999) and Worden et al. (2012):

For low ground motions ($\text{MMI} \le 5.0$, human perception regime):

$$\text{MMI}_{\text{PGA}} = 2.20 \log_{10}(\text{PGA}) + 1.00 \quad (\text{for } \log_{10}(\text{PGA}) \le 0.6)$$
$$\text{MMI}_{\text{PGA}} = 3.66 \log_{10}(\text{PGA}) - 1.66 \quad (\text{for } \log_{10}(\text{PGA}) > 0.6)$$

For high ground motions ($\text{MMI} > 5.0$, structural damage regime):

$$\text{MMI}_{\text{PGV}} = 2.10 \log_{10}(\text{PGV}) + 3.40 \quad (\text{for } \log_{10}(\text{PGV}) \le 0.7)$$
$$\text{MMI}_{\text{PGV}} = 3.47 \log_{10}(\text{PGV}) + 2.35 \quad (\text{for } \log_{10}(\text{PGV}) > 0.7)$$

The composite instrumental intensity combines both metrics:

$$\text{MMI} = \begin{cases} 0.7 \text{MMI}_{\text{PGA}} + 0.3 \text{MMI}_{\text{PGV}} & \text{if } \text{MMI}_{\text{PGV}} < 5.0 \\ 0.2 \text{MMI}_{\text{PGA}} + 0.8 \text{MMI}_{\text{PGV}} & \text{if } \text{MMI}_{\text{PGV}} \ge 5.0 \end{cases}$$

## 3. S-Wave Wavefront Isochrone and Time-To-Impact (TTI) Countdown

For a site located at 3D hypocentral distance $R_{\text{hypo}}$, the S-wave arrival time is:

$$t_{\text{arr}, S} = t_0 + \frac{R_{\text{hypo}}}{v_s}$$

Given the current epoch timestamp $t_{\text{now}}$, the Time-To-Impact is:

$$\text{TTI} = t_{\text{arr}, S} - t_{\text{now}} = \frac{R_{\text{hypo}}}{v_s} - (t_{\text{now}} - t_0)$$

Warning status:
- $\text{TTI} > 0$: Warning active. The alert payload broadcasts the remaining countdown
  seconds along with expected local MMI and PGA.
- $\text{TTI} \le 0$: Strong shaking underway or past.
- Blind Zone: Sites within radius $R_{\text{blind}} = v_s \cdot t_{\text{latency}}$
  cannot receive warning before S-wave arrival. scarp's sub-second pipeline latency
  minimizes $R_{\text{blind}}$ to $< 15\text{ km}$.
