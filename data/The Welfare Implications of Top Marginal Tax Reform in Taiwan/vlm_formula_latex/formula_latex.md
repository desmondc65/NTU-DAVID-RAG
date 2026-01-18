# Formula Extraction Results
Total Formulas: 23

## Page 6

### Formula 1
**Image:** `page_6_formula_1.png`

$$ 
V^S(j, k, z, \tilde{e}, g) = \max_{c, k', n} \{ u(c, n) + \beta \mathbb{E} [ V^S(j+1, k', z', \tilde{e}', g) | z ] \}
 $$

---

### Formula 2
**Image:** `page_6_formula_2.png`

$$ 
(1 + \tau_c)c + k' + \pi(wz\varepsilon_{g,j}n) = k + y_S^d(wz\varepsilon_{g,j}n + rk) + Tr + b
 $$

---

### Formula 3
**Image:** `page_6_formula_3.png`

$$ 
\tilde{e}' = [(j - 1)\tilde{e} + e] / j
 $$

---

## Page 7

### Formula 1
**Image:** `page_7_formula_1.png`

$$ 
R^S(j, k, \tilde{e}, g) = \max_{c, k'} [u(c, 0) + \beta s_{g, j} R^S(j + 1, k', \tilde{e}', g)]
 $$

---

### Formula 2
**Image:** `page_7_formula_2.png`

$$ 
(1 + \tau_c)c + k' = k + y_S^d(SS(\tilde{e}) + rk) + Tr
 $$

---

### Formula 3
**Image:** `page_7_formula_3.png`

$$ 
U(c, n_m, n_f) = u(c/\eta, n_m) + u(c/\eta, n_f)
 $$

---

### Formula 4
**Image:** `page_7_formula_4.png`

$$ 
V^M(j, k, z_m, z_f, \tilde{e}) = \max_{c, k', n_m, n_f} \{U(c, n_m, n_f) + \beta \mathbb{E} [V^M(j+1, k', z'_m, z'_f, \tilde{e}') | z_m, z_f]\}
 $$

---

### Formula 5
**Image:** `page_7_formula_5.png`

$$ 
(1 + \tau_c)c + k' + \pi(w z_m \varepsilon_{m,j} n_m + w z_f \varepsilon_{f,j} n_f) = k + y_M^d(w z_m \varepsilon_{m,j} n_m + w z_f \varepsilon_{f,j} n_f + r k) + 2(Tr + b)
 $$

---

### Formula 6
**Image:** `page_7_formula_6.png`

$$ 
\tilde{e}' = [(j - 1)\tilde{e} + (e_m + e_f)/2]/j
 $$

---

## Page 8

### Formula 1
**Image:** `page_8_formula_1.png`

$$ 
R^M(j, k, \tilde{e}) = \max_{c, k'} [U(c, 0, 0) + \beta s_{m,j} s_{f,j} R^M(j + 1, k', \tilde{e}') + \beta s_{m,j}(1 - s_{f,j}) R^S(j + 1, k', \tilde{e}', m) + \beta s_{f,j}(1 - s_{m,j}) R^S(j + 1, k', \tilde{e}', f)]
 $$

---

### Formula 2
**Image:** `page_8_formula_2.png`

$$ 
(1 + \tau_c)c + k' = k + y_M^d(2SS(\tilde{e}) + rk) + 2Tr
 $$

---

### Formula 3
**Image:** `page_8_formula_3.png`

$$ 
r = \alpha \Psi (K/N)^{\alpha-1} - \delta \\
w = (1 - \alpha) \Psi (K/N)^{\alpha}
 $$

---

### Formula 4
**Image:** `page_8_formula_4.png`

$$ 
K = \int k'^M(\omega^M)d\Gamma^M(\omega^M) + \int k'^S(\omega^S)d\Gamma^S(\omega^S) \\
N = \int [z_m \varepsilon_{m,j} n_m^M(\omega^M) + z_f \varepsilon_{f,j} n_f^M(\omega^M)] d\Gamma^M(\omega^M) \\
+ \int z_m \varepsilon_{m,j} n_m^S(\omega^S) d\Gamma^S(\omega^S) + \int z_f \varepsilon_{f,j} n_f^S(\omega^S) d\Gamma^S(\omega^S)
 $$

---

## Page 9

### Formula 1
**Image:** `page_9_formula_1.png`

$$ 
\begin{aligned}
G+2 \int_{j \ge J_r} S S(\tilde{e}) d \Gamma^M\left(\omega^M\right)+\int_{j \ge J_r} S S(\tilde{e}) d \Gamma^S\left(\omega^S\right)= & \tau_c\left[\int c^M\left(\omega^M\right) d \Gamma^M\left(\omega^M\right)+\int c^S\left(\omega^S\right) d \Gamma^S\left(\omega^S\right)\right] \\
& +\int\left[y\left(\omega^M\right)-y_M^d\left(y\left(\omega^M\right)\right)\right] d \Gamma^M\left(\omega^M\right) \\
& +\int\left[y\left(\omega^S\right)-y_S^d\left(y\left(\omega^S\right)\right)\right] d \Gamma^S\left(\omega^S\right) \\
& +\left(\int_{j<J_r} \pi\left(\omega^M\right) d \Gamma^M\left(\omega^M\right)+\int_{j<J_r} \pi\left(\omega^S\right) d \Gamma^S\left(\omega^S\right)\right)
\end{aligned}
 $$

---

### Formula 2
**Image:** `page_9_formula_2.png`

$$ 
\mathcal{W}^N = \underbrace{\sum_{g=m,f} \int V^S(1, k, z, \tilde{e}, g) d\Gamma^S(1, k, z, \tilde{e}, g)}_{\text{single households}} + \underbrace{\int V^M(1, k, z_m, z_f, \tilde{e}) d\Gamma^M(1, k, z_m, z_f, \tilde{e})}_{\text{married households}}
 $$

---

## Page 10

### Formula 1
**Image:** `page_10_formula_1.png`

$$ 
\mathcal{W}^U = \underbrace{\sum_{g=m,f} \left[ \int V^S(j, k, z, \tilde{e}, g) d\Gamma(j, k, z, \tilde{e}, g) + \int R^S(j, k, \tilde{e}, g) d\Gamma(j, k, \tilde{e}, g) \right]}_{\text{single households}} + \underbrace{\int V^M(j, k, z_m, z_f, \tilde{e}) d\Gamma(j, k, z_m, z_f, \tilde{e}) + \int R^M(j, k, \tilde{e}) d\Gamma(j, k, \tilde{e})}_{\text{married households}}
 $$

---

## Page 11

### Formula 1
**Image:** `page_11_formula_1.png`

$$ 
E \left[ \sum_{j=1}^J \beta^{j-1} u(c_j, n_j) \right]
 $$

---

## Page 12

### Formula 1
**Image:** `page_12_formula_1.png`

$$ 
u(c, n) = \log c - \theta_g \frac{n^{1+\sigma_g}}{1+\sigma_g} - \phi_g^\iota \mathbf{I}_{n>0}
 $$

---

## Page 14

### Formula 1
**Image:** `page_14_formula_1.png`

$$ 
y_f = z w \epsilon_j h + r k \quad \forall j < J_r \\ y_f = SS(\tilde{e}) + r k \quad \forall j \geq J_r
 $$

---

### Formula 2
**Image:** `page_14_formula_2.png`

$$ 
y^d = \lambda_\iota \min\{y_b, y_f\}^{1-\tau_\iota} + (1 - \tau_{max}) \max\{0, y_f - y_b\} + Tr - \pi(y_f) \text{ for } \iota \in \{S, M\}
 $$

---

## Page 16

### Formula 1
**Image:** `page_16_formula_1.png`

$$ 
y_i^d = \lambda y_i^{1-\tau}
 $$

---

### Formula 2
**Image:** `page_16_formula_2.png`

$$ 
\log y_i^d = \log \lambda + (1 - \tau) \log y_i + \epsilon_i
 $$

---

## Page 18

### Formula 1
**Image:** `page_18_formula_1.png`

$$ 
SS(\tilde{e}) = \psi \tilde{e}
 $$

---

