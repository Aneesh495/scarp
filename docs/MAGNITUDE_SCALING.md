# Real-Time Magnitude Scaling in scarp

This monograph documents the real-time earthquake magnitude scaling relations,
source parameter physics, and Bayesian multi-station evidence pooling implemented in scarp.

## 1. Peak Ground Displacement ($P_d$) Scaling

In operational earthquake early warning, waiting for the entire waveform or the
destructive S-wave arrival introduces unacceptable latency. scarp estimates
moment magnitude $M_w$ using the peak ground displacement $P_d$ measured within
the first $1.0\text{ s}$ to $3.0\text{ s}$ of the P-wave onset.

Following Wu & Kanamori (2005) and Kuyuk & Allen (2013), the empirical scaling
law connects $P_d$ (measured in cm) to hypocentral distance $R$ (measured in km)
and moment magnitude $M_w$:

$$\log_{10}(P_d) = a \cdot M_w + b \cdot \log_{10}(R) + c$$

Calibrated regional coefficients for active tectonic margins (e.g. California / Japan):
- $a = 0.82$
- $b = -1.35$
- $c = -4.34$

Inverting for magnitude:

$$M_{pd} = \frac{\log_{10}(P_d) - b \cdot \log_{10}(R) - c}{a}$$

Site amplification corrections adjust $P_d$ to standard reference rock ($V_{S30} = 760\text{ m/s}$):

$$P_{d, \text{rock}} = \frac{P_{d, \text{observed}}}{\left( \frac{760}{V_{S30}} \right)^{0.35}}$$

## 2. Characteristic Period ($\tau_c$) Scaling

While $P_d$ depends on hypocentral distance $R$, the characteristic period $\tau_c$
reflects the average period of the initial P-wave signal and relates directly to
the physical dimension of the initial fault rupture patch.

The parameter $r$ evaluates the ratio of ground velocity power to displacement power:

$$r = \frac{\int_0^\tau \dot{u}(t)^2 dt}{\int_0^\tau u(t)^2 dt} = \frac{\int_0^\tau v(t)^2 dt}{\int_0^\tau u(t)^2 dt}$$

The characteristic period is defined as:

$$\tau_c = \frac{2\pi}{\sqrt{r}}$$

From source physics (Brune 1970 / Kanamori 2005), corner frequency $f_c$ scales
inversely with rupture radius $f_c \propto 1 / L$. Since $\tau_c \approx 1 / f_c$,
larger earthquakes emit lower-frequency initial waveforms:

$$\log_{10}(\tau_c) = \alpha \cdot M_w + \beta$$

with $\alpha \approx 0.29$ and $\beta \approx -1.30$. Inverting for magnitude:

$$M_{tc} = \frac{\log_{10}(\tau_c) - \beta}{\alpha}$$

## 3. Bayesian Multi-Station Evidence Fusion

Each reporting station $i$ provides independent estimates $M_{pd, i}$ and $M_{tc, i}$
with standard errors $\sigma_{pd} \approx 0.35$ and $\sigma_{tc} \approx 0.40$.

scarp combines these measurements with the regional Gutenberg-Richter background
prior $P(M) \propto 10^{-b M}$ ($b \approx 1.0$) centered at prior mean $\mu_0 = 4.5$
with prior variance $\sigma_0^2 = 1.0$:

$$M_{\text{comb}} = \frac{\sum_{i=1}^N \left( \frac{M_{pd, i}}{\sigma_{pd}^2} + \frac{M_{tc, i}}{\sigma_{tc}^2} \right) + \frac{\mu_0}{\sigma_0^2}}{\sum_{i=1}^N \left( \frac{1}{\sigma_{pd}^2} + \frac{1}{\sigma_{tc}^2} \right) + \frac{1}{\sigma_0^2}}$$

The combined posterior uncertainty is:

$$\sigma_{\text{comb}} = \left( \sum_{i=1}^N \left( \frac{1}{\sigma_{pd}^2} + \frac{1}{\sigma_{tc}^2} \right) + \frac{1}{\sigma_0^2} \right)^{-1/2}$$

As more stations report and the P-wave window expands from $1\text{ s}$ to $3\text{ s}$,
the combined magnitude estimate continuously converges to the true moment magnitude.
