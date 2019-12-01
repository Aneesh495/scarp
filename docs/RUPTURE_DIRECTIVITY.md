# Finite-Fault Rupture Kinematics and Directivity in scarp

This monograph explores the kinematic line-source rupture model, Doppler directivity
amplification, and asperity slip inversion implemented in scarp.

## 1. Kinematic Line-Source Rupture

For moderate and large earthquakes ($M_w \ge 6.0$), the assumption of an idealized
point source breaks down. The rupture propagates along a fault surface of finite
length $L$ and width $W$.

In scarp's kinematic formulation, the rupture initiates at the hypocenter
$(\text{lat}_0, \text{lon}_0, z_0)$ and propagates along strike $\phi$ at rupture
velocity $v_r \approx 0.85 v_s$ (typically $2.8\text{ km/s}$ to $3.2\text{ km/s}$).

The rupture arrival time at a sub-fault patch located at coordinate $\xi$ along the fault is:

$$t_{\text{rup}}(\xi) = \frac{|\xi|}{v_r}$$

The seismic radiation emitted from sub-fault $\xi$ arrives at an observation station
$\mathbf{s} = (x, y)$ at time:

$$t_{\text{arr}}(\xi) = t_{\text{rup}}(\xi) + \frac{R(\xi)}{v_s}$$

where $R(\xi) = \sqrt{(x - x(\xi))^2 + (y - y(\xi))^2 + z(\xi)^2}$ is the 3D distance.

## 2. Azimuthal Doppler Directivity Factor

When the rupture propagates toward an observation site (forward directivity), the
apparent velocity of the rupture front is close to the shear wave velocity. As a
result, seismic energy radiated throughout the rupture duration arrives in a
compressed, coherent, high-amplitude pulse.

The classical Doppler directivity factor is defined as:

$$C_d = \frac{1}{1 - \frac{v_r}{v_s} \cos\theta}$$

where $\theta$ is the angle between the rupture propagation direction vector and
the ray path from the fault to the site.

Behavior of $C_d$:
- Forward Directivity ($\theta \to 0^\circ$): $\cos\theta \approx 1$. The denominator
  approaches $1 - 0.85 = 0.15$, yielding $C_d \approx 4.0\text{ to }6.0\times$ amplification.
- Transverse Directivity ($\theta \approx 90^\circ$): $\cos\theta = 0$, yielding $C_d = 1.0$ (neutral).
- Backward Directivity ($\theta \to 180^\circ$): $\cos\theta \approx -1$. Denominator
  becomes $1 + 0.85 = 1.85$, yielding $C_d \approx 0.54\times$ (de-amplification and elongated duration).

In scarp, the Ground Motion Model scales peak acceleration and velocity by:

$$\text{PGA}_{\text{directivity}} = \text{PGA}_{\text{base}} \cdot C_d^{0.35}$$
$$\text{PGV}_{\text{directivity}} = \text{PGV}_{\text{base}} \cdot C_d^{0.50}$$

## 3. Asperity Discretization and Stress Drop

The fault surface is discretized into a 2D mesh of $M \times N$ sub-fault patches.
Slip distribution across the patches is parameterized by:

$$s(x, y) = s_{\text{bg}} + \sum_{k=1}^K s_k \exp\left( -\frac{(x - x_k)^2 + (y - y_k)^2}{2 \sigma_k^2} \right)$$

where $(x_k, y_k)$ marks the center of asperity patch $k$.

The local Brune stress drop on each asperity patch is evaluated as:

$$\Delta\sigma_k = \frac{7}{16} \frac{M_{0, k}}{r_k^3}$$

Asperities typically exhibit stress drops between $5\text{ MPa}$ and $20\text{ MPa}$,
representing the primary source of destructive high-frequency ground motion.
