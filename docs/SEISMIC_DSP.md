# Seismic Digital Signal Processing in scarp

This monograph details the causal signal processing pipeline implemented in
scarp for continuous 100 Hz to 200 Hz strong-motion accelerometer and broadband
velocity telemetry.

## 1. Baseline Drift and Recursive High-Pass Filtering

Continuous integration of acceleration waveforms $a(t)$ to obtain ground velocity
$v(t)$ and displacement $u(t)$ is inherently sensitive to sensor tilt, thermal
transients, and analog-to-digital converter (ADC) DC bias. A constant baseline
offset $a_0$ integrates into a linear velocity ramp $v(t) = a_0 t$ and a quadratic
displacement drift $u(t) = \frac{1}{2} a_0 t^2$.

scarp eliminates baseline wander through a recursive single-pole causal high-pass filter:

$$y[n] = \alpha (y[n-1] + x[n] - x[n-1])$$

where the feedback coefficient $\alpha$ is parameterized by the cutoff frequency
$f_c$ (typically $0.075\text{ Hz}$) and sampling frequency $f_s$:

$$\alpha = \frac{1}{1 + 2\pi f_c \Delta t}$$

For $f_s = 100\text{ Hz}$ and $f_c = 0.075\text{ Hz}$, $\alpha \approx 0.9953$.

## 2. 4th-Order Causal Butterworth Bandpass Filter

To isolate the dominant frequency band containing P-wave onset energy while
rejecting high-frequency cultural machinery noise and microseismic oceanic noise,
waveforms pass through a 4th-order Butterworth bandpass filter ($0.075\text{ Hz} \le f \le 3.0\text{ Hz}$).

The analog transfer function prototype:

$$H(s) = \frac{s^2 \omega_0^2}{(s^2 + \frac{\omega_0}{Q} s + \omega_0^2)^2}$$

is mapped to the discrete z-domain via the Bilinear Transform:

$$s = 2 f_s \frac{1 - z^{-1}}{1 + z^{-1}}$$

The difference equation is executed using Direct Form II Transposed to minimize
numerical roundoff noise and register pressure:

$$y[n] = b_0 x[n] + w_0[n-1]$$
$$w_0[n] = b_1 x[n] - a_1 y[n] + w_1[n-1]$$
$$w_1[n] = b_2 x[n] - a_2 y[n] + w_2[n-1]$$
$$w_2[n] = b_3 x[n] - a_3 y[n] + w_3[n-1]$$
$$w_3[n] = b_4 x[n] - a_4 y[n]$$

## 3. Recursive STA/LTA Energy Ratio Detector

The Short-Term Average to Long-Term Average (STA/LTA) detector continuously computes
the ratio of instantaneous seismic energy to background ambient noise.

The Characteristic Function evaluates squared amplitude and its temporal derivative:

$$C F[n] = x[n]^2 + k \cdot \left(\frac{x[n] - x[n-1]}{\Delta t}\right)^2$$

where $k = 0.1\text{ s}^2$ weights high-frequency onset impulsiveness.

Recursive exponential moving averages eliminate sliding window buffer overhead:

$$\text{STA}[n] = (1 - C_{\text{sta}}) \cdot \text{STA}[n-1] + C_{\text{sta}} \cdot C F[n]$$
$$\text{LTA}[n] = (1 - C_{\text{lta}}) \cdot \text{LTA}[n-1] + C_{\text{lta}} \cdot C F[n]$$

where $C_{\text{sta}} = \frac{1}{N_{\text{sta}}}$ ($N_{\text{sta}} = 0.5\text{ s} \times f_s$)
and $C_{\text{lta}} = \frac{1}{N_{\text{lta}}}$ ($N_{\text{lta}} = 5.0\text{ s} \times f_s$).

A trigger onset is declared when the ratio satisfies:

$$R[n] = \frac{\text{STA}[n]}{\text{LTA}[n]} \ge \eta_{\text{on}} \quad (\eta_{\text{on}} = 5.0)$$

Detriggering occurs when the ratio subsides below $\eta_{\text{off}} = 1.5$.

## 4. Sliding Kurtosis Higher-Order Statistics Picker

While STA/LTA detects the presence of an energy burst, the 4th-order sample kurtosis
provides microsecond-level precision for the true P-wave onset.

For a sliding window of length $W$:

$$\text{Kurt}[k] = \frac{\frac{1}{W} \sum_{j=k-W+1}^k (x[j] - \bar{x})^4}{\left(\frac{1}{W} \sum_{j=k-W+1}^k (x[j] - \bar{x})^2\right)^2}$$

Gaussian background noise yields $\text{Kurt} \approx 3.0$. The arrival of the coherent
seismic wavefront causes a steep transient jump in kurtosis. The precise pick index
$k_{\text{pick}}$ corresponds to the maximum discrete gradient:

$$k_{\text{pick}} = \arg\max_k (\text{Kurt}[k] - \text{Kurt}[k-1])$$
