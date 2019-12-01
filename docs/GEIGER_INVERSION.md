# Geiger's Method and Non-Linear Hypocenter Inversion in scarp

This monograph details the non-linear least squares inversion formulation,
crustal ray tracing, adaptive damping, and covariance estimation implemented in scarp.

## 1. Mathematical Formulation

Let the hypocenter state vector be $\mathbf{m} = (x, y, z, t_0)^T \in \mathbb{R}^4$,
where $(x, y)$ represents latitude and longitude, $z$ represents focal depth,
and $t_0$ represents earthquake origin time.

Given $N$ observation stations with coordinates $\mathbf{s}_i = (x_i, y_i, z_i)$,
the observed arrival time is $t_{\text{obs}, i}$ and the theoretical travel time
is $T_i(\mathbf{m})$. The forward prediction equation is:

$$t_{\text{calc}, i} = t_0 + T_i(x, y, z)$$

The arrival time residual for station $i$ is:

$$r_i(\mathbf{m}) = t_{\text{obs}, i} - t_{\text{calc}, i}(\mathbf{m})$$

Linearizing around the current estimate $\mathbf{m}_k$ using first-order Taylor expansion:

$$\mathbf{r}(\mathbf{m}_k + \Delta \mathbf{m}) \approx \mathbf{r}(\mathbf{m}_k) - \mathbf{A} \Delta \mathbf{m}$$

where $\mathbf{A} \in \mathbb{R}^{N \times 4}$ is the Jacobian matrix with elements:

$$A_{i, 1} = \frac{\partial T_i}{\partial x}, \quad A_{i, 2} = \frac{\partial T_i}{\partial y}, \quad A_{i, 3} = \frac{\partial T_i}{\partial z}, \quad A_{i, 4} = 1.0$$

## 2. Levenberg-Marquardt Damped Normal Equations

In early warning scenarios, the station geometry may be sparse or collinear,
causing the normal matrix $\mathbf{A}^T \mathbf{A}$ to become rank-deficient.
scarp applies Levenberg-Marquardt adaptive damping:

$$(\mathbf{A}^T \mathbf{W} \mathbf{A} + \lambda \text{diag}(\mathbf{A}^T \mathbf{W} \mathbf{A})) \Delta \mathbf{m} = \mathbf{A}^T \mathbf{W} \mathbf{r}$$

where $\mathbf{W} = \text{diag}(w_1, \dots, w_N)$ represents observation weights.
The damping parameter $\lambda$ is dynamically adjusted:
- If RMS residual decreases: $\lambda \leftarrow \lambda \cdot 0.2$ (approaching fast Gauss-Newton quadratic convergence).
- If RMS residual increases: $\lambda \leftarrow \lambda \cdot 2.5$ (approaching stable steepest descent gradient step).

## 3. Huber M-Estimator Robust Reweighting

To suppress outliers caused by false phase identifications (e.g. secondary S-wave
or cultural noise burst mispicked as P-wave), scarp employs Huber M-estimation:

$$\rho(r) = \begin{cases} \frac{1}{2} r^2 & \text{for } |r| \le k\sigma \\ k\sigma |r| - \frac{1}{2} (k\sigma)^2 & \text{for } |r| > k\sigma \end{cases}$$

The corresponding weight function in Iteratively Reweighted Least Squares (IRLS) is:

$$w_i = \begin{cases} 1.0 & \text{for } |r_i| \le k\sigma \\ \frac{k\sigma}{|r_i|} & \text{for } |r_i| > k\sigma \end{cases}$$

with tuning constant $k = 1.5$ and scale $\sigma = \text{RMS}(\mathbf{r})$.

## 4. Covariance Matrix and 95% Error Ellipsoid

Upon convergence, the posterior parameter covariance matrix is:

$$\mathbf{C}_{\mathbf{m}} = \sigma_{\text{post}}^2 (\mathbf{A}^T \mathbf{W} \mathbf{A})^{-1}$$

where $\sigma_{\text{post}}^2 = \frac{\sum w_i r_i^2}{N - 4}$.

The horizontal sub-matrix:

$$\mathbf{C}_{\text{horiz}} = \begin{bmatrix} C_{xx} & C_{xy} \\ C_{yx} & C_{yy} \end{bmatrix}$$

yields eigenvalues $\mu_1 \ge \mu_2 \ge 0$. The 95% confidence error ellipse parameters are:
- Semi-major axis length: $a = 1.96 \sqrt{\mu_1}$ (km)
- Semi-minor axis length: $b = 1.96 \sqrt{\mu_2}$ (km)
- Strike azimuth: $\theta = \frac{1}{2} \text{atan2}(2 C_{xy}, C_{xx} - C_{yy})$
- Vertical depth error: $\sigma_z = 1.96 \sqrt{C_{zz}}$ (km)
