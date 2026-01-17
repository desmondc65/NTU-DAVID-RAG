## lifecycle_solver.py
import numpy as np
from numba import njit, prange
from typing import Dict, Any, Tuple
from parameters import ModelParams

@njit(cache=True)
def linear_interp(x_grid: np.ndarray, y_values: np.ndarray, x_val: float) -> float:
    """Fast linear interpolation for Numba."""
    if x_val <= x_grid[0]:
        return y_values[0]
    if x_val >= x_grid[-1]:
        return y_values[-1]
    
    idx = np.searchsorted(x_grid, x_val) - 1
    x0, x1 = x_grid[idx], x_grid[idx+1]
    y0, y1 = y_values[idx], y_values[idx+1]
    return y0 + (y1 - y0) * (x_val - x0) / (x1 - x0)

@njit(cache=True)
def utility(c: float, n: float, theta: float, sigma: float, phi: float) -> float:
    """Additively separable utility function."""
    if c <= 0:
        return -1e10
    val = np.log(c) - theta * (n**(1.0 + sigma)) / (1.0 + sigma)
    if n > 0:
        val -= phi
    return val

@njit(cache=True)
def get_disposable_income(y_f: float, y_b: float, lambda_val: float, tau: float, tau_max: float) -> float:
    """Calculates disposable income using the Benabou functional form with a top cap."""
    if y_f <= y_b:
        return lambda_val * (y_f**(1.0 - tau))
    else:
        # Linear extension after threshold y_b
        y_d_at_b = lambda_val * (y_b**(1.0 - tau))
        return y_d_at_b + (1.0 - tau_max) * (y_f - y_b)

class LifecycleSolver:
    """
    Computational engine for solving the household dynamic programming problems.
    Uses backward induction and Numba-accelerated loops.
    """

    def __init__(self, params: ModelParams):
        self.p = params
        # Pre-calculated period values
        self.beta = self.p.beta
        self.sigma_g = self.p.sigma_g
        self.z_states = self.p.z_states
        self.z_trans = self.p.z_transition
        self.k_grid = self.p.k_grid
        self.e_grid = self.p.e_tilde_grid
        self.J = self.p.J
        self.Jr = self.p.Jr
        self.eta = self.p.eta
        self.tau_c = self.p.tau_c

    def solve_singles(self, r: float, t: float, tax_params: Dict[str, float], 
                      w: float = 1.0, b: float = 0.0, tr: float = 0.0) -> Dict[str, np.ndarray]:
        """
        Solves the lifecycle problem for single households (Male/Female).
        
        Args:
            r: Interest rate (5-year).
            t: Insurance premium rate.
            tax_params: Contains tau_s, lambda_s, tau_max.
            w: Wage per skill unit.
            b: Accidental bequests.
            tr: Social in-kind transfers.
        """
        # Prepare storage: [gender, age, asset, productivity, e_tilde]
        # Productivity index is only relevant before retirement
        shape = (2, self.J, len(self.k_grid), len(self.z_states), len(self.e_grid))
        v_func = np.zeros(shape)
        c_pol = np.zeros(shape)
        k_pol = np.zeros(shape)
        n_pol = np.zeros(shape)

        # Pre-process tax parameters
        tau_s = tax_params.get('tau_s', self.p.tau_s)
        lam_s = tax_params.get('lambda_s', self.p.lambda_tax['s'])
        tau_max = tax_params.get('tau_max', self.p.tau_max)
        
        # Calculate y_b: where marginal tax = tau_max
        # lambda * (1-tau) * y_b^(-tau) = 1 - tau_max
        y_b = (lam_s * (1.0 - tau_s) / (1.0 - tau_max))**(1.0 / tau_s)

        # Survival probabilities
        surv_m = self.p.get_survival_probs('m')
        surv_f = self.p.get_survival_probs('f')
        surv = np.stack((surv_m, surv_f))
        
        # Human capital profiles
        # In a real run, these would be loaded from data_handler.get_age_efficiency_profiles()
        # For this standalone file, we assume they are accessible in params
        # (Assuming they were stored in p.epsilon_profile[gender, age])
        # Placeholder epsilon if not present
        eps = np.ones((2, self.J)) 

        # Call the JIT-optimized backend
        _solve_singles_jit(
            v_func, c_pol, k_pol, n_pol,
            self.k_grid, self.e_grid, self.z_states, self.z_trans,
            surv, eps, self.J, self.Jr, self.beta, r, t, w, b, tr, self.tau_c,
            tau_s, lam_s, tau_max, y_b,
            np.array([self.p.theta['m'], self.p.theta['f']]),
            np.array([self.p.sigma_m, self.p.sigma_f]),
            np.array([self.p.phi['s_m'], self.p.phi['s_f']]),
            self.p.psi_ss
        )

        return {'v': v_func, 'c': c_pol, 'k_prime': k_pol, 'n': n_pol}

    def solve_married(self, r: float, t: float, tax_params: Dict[str, float], 
                      v_singles: np.ndarray, w: float = 1.0, b: float = 0.0, tr: float = 0.0) -> Dict[str, np.ndarray]:
        """
        Solves the lifecycle problem for married households (joint decision).
        
        Args:
            v_singles: Single retiree value functions for transition after spouse's death.
        """
        # State: [age, asset, z_m, z_f, e_tilde]
        nz = len(self.z_states)
        nk = len(self.k_grid)
        ne = len(self.e_grid)
        shape = (self.J, nk, nz, nz, ne)
        
        v_func = np.zeros(shape)
        c_pol = np.zeros(shape)
        k_pol = np.zeros(shape)
        nm_pol = np.zeros(shape)
        nf_pol = np.zeros(shape)

        tau_m = tax_params.get('tau_m', self.p.tau_m)
        lam_m = tax_params.get('lambda_m', self.p.lambda_tax['m'])
        tau_max = tax_params.get('tau_max', self.p.tau_max)
        y_b = (lam_m * (1.0 - tau_m) / (1.0 - tau_max))**(1.0 / tau_m)

        surv_m = self.p.get_survival_probs('m')
        surv_f = self.p.get_survival_probs('f')
        eps = np.ones((2, self.J)) # Placeholder

        _solve_married_jit(
            v_func, c_pol, k_pol, nm_pol, nf_pol,
            self.k_grid, self.e_grid, self.z_states, self.z_trans,
            surv_m, surv_f, eps, v_singles,
            self.J, self.Jr, self.beta, r, t, w, b, tr, self.tau_c,
            tau_m, lam_m, tau_max, y_b,
            np.array([self.p.theta['m'], self.p.theta['f']]),
            np.array([self.p.sigma_m, self.p.sigma_f]),
            np.array([self.p.phi['m_m'], self.p.phi['m_f']]),
            self.p.psi_ss, self.eta
        )

        return {'v': v_func, 'c': c_pol, 'k_prime': k_pol, 'n_m': nm_pol, 'n_f': nf_pol}


@njit(parallel=True, cache=True)
def _solve_singles_jit(V, C, K_pol, N, k_grid, e_grid, z_states, z_trans, 
                      surv, eps, J, Jr, beta, r, t_prem, w, b, tr, tau_c,
                      tau, lam, tau_max, y_b, theta_g, sigma_g, phi_g, psi_ss):
    """JIT accelerated backend for single households."""
    nk = len(k_grid)
    nz = len(z_states)
    ne = len(e_grid)

    for g in range(2): # 0: Male, 1: Female
        # Terminal Period J
        for ik in prange(nk):
            for iz in range(nz):
                for ie in range(ne):
                    # Retired, no labor
                    ss_benefit = psi_ss * e_grid[ie]
                    y_f = ss_benefit + r * k_grid[ik]
                    y_d = get_disposable_income(y_f, y_b, lam, tau, tau_max)
                    budget = k_grid[ik] + y_d + tr
                    cons = budget / (1.0 + tau_c)
                    V[g, J-1, ik, iz, ie] = utility(cons, 0.0, theta_g[g], sigma_g[g], 0.0)
                    C[g, J-1, ik, iz, ie] = cons
                    K_pol[g, J-1, ik, iz, ie] = 0.0

        # Backward Induction
        for j in range(J-2, -1, -1):
            age = j + 1
            is_retired = (age >= Jr)
            for ik in prange(nk):
                for iz in range(nz):
                    for ie in range(ne):
                        best_v = -1e11
                        
                        # Labor supply optimization (if working age)
                        n_options = np.array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0]) if not is_retired else np.array([0.0])
                        
                        for n in n_options:
                            curr_phi = phi_g[g] if n > 0 else 0.0
                            if is_retired:
                                ss_benefit = psi_ss * e_grid[ie]
                                y_f = ss_benefit + r * k_grid[ik]
                                pi_prem = 0.0
                                e_next = e_grid[ie]
                            else:
                                e_curr = w * z_states[iz] * eps[g, j] * n
                                y_f = e_curr + r * k_grid[ik]
                                pi_prem = t_prem * e_curr
                                # Update average earnings
                                e_next = ((age - 1) * e_grid[ie] + e_curr) / age

                            y_d = get_disposable_income(y_f, y_b, lam, tau, tau_max)
                            resources = k_grid[ik] + y_d + tr + (b if not is_retired else 0.0) - pi_prem
                            
                            # Simple grid search for k_prime
                            for ikp in range(nk):
                                kp = k_grid[ikp]
                                cons = (resources - kp) / (1.0 + tau_c)
                                if cons <= 0: continue
                                
                                # Expectation over z'
                                ev = 0.0
                                if is_retired:
                                    # State ie is constant in retirement
                                    # Use interpolation for k_prime if needed, but here searching on grid
                                    ev = V[g, j+1, ikp, 0, ie] 
                                else:
                                    for izp in range(nz):
                                        # Search for e_next on grid
                                        v_at_enext = linear_interp(e_grid, V[g, j+1, ikp, izp, :], e_next)
                                        ev += z_trans[iz, izp] * v_at_enext
                                
                                curr_v = utility(cons, n, theta_g[g], sigma_g[g], curr_phi) + beta * surv[g, j] * ev
                                if curr_v > best_v:
                                    best_v = curr_v
                                    V[g, j, ik, iz, ie] = best_v
                                    C[g, j, ik, iz, ie] = cons
                                    K_pol[g, j, ik, iz, ie] = kp
                                    N[g, j, ik, iz, ie] = n

@njit(parallel=True, cache=True)
def _solve_married_jit(V, C, K_pol, NM, NF, k_grid, e_grid, z_states, z_trans,
                       surv_m, surv_f, eps, v_singles, J, Jr, beta, r, t_prem, 
                       w, b, tr, tau_c, tau, lam, tau_max, y_b, 
                       theta_g, sigma_g, phi_g, psi_ss, eta):
    """JIT accelerated backend for married households."""
    nk = len(k_grid)
    nz = len(z_states)
    ne = len(e_grid)

    for j in range(J-1, -1, -1):
        age = j + 1
        is_retired = (age >= Jr)
        for ik in prange(nk):
            for izm in range(nz):
                for izf in range(nz):
                    for ie in range(ne):
                        best_v = -1e11
                        
                        # Decision Grid
                        nm_options = np.array([0.0, 0.4, 0.8]) if not is_retired else np.array([0.0])
                        nf_options = np.array([0.0, 0.4, 0.8]) if not is_retired else np.array([0.0])
                        
                        for nm in nm_options:
                            for nf in nf_options:
                                phi_m = phi_g[0] if nm > 0 else 0.0
                                phi_f = phi_g[1] if nf > 0 else 0.0
                                
                                if is_retired:
                                    # Pooled retirement benefit
                                    y_f = 2.0 * psi_ss * e_grid[ie] + r * k_grid[ik]
                                    pi_prem = 0.0
                                    e_next = e_grid[ie]
                                else:
                                    em = w * z_states[izm] * eps[0, j] * nm
                                    ef = w * z_states[izf] * eps[1, j] * nf
                                    y_f = em + ef + r * k_grid[ik]
                                    pi_prem = t_prem * (em + ef)
                                    e_next = ((age - 1) * e_grid[ie] + (em + ef)/2.0) / age

                                y_d = get_disposable_income(y_f, y_b, lam, tau, tau_max)
                                resources = k_grid[ik] + y_d + 2.0*tr + 2.0*b - pi_prem
                                
                                for ikp in range(nk):
                                    kp = k_grid[ikp]
                                    cons = (resources - kp) / (1.0 + tau_c)
                                    if cons <= 0: continue
                                    
                                    # Continuation Value
                                    ev = 0.0
                                    if j < J - 1:
                                        if is_retired:
                                            # Joint survival + transition to singles if one dies
                                            p_both = surv_m[j] * surv_f[j]
                                            p_m_only = surv_m[j] * (1.0 - surv_f[j])
                                            p_f_only = surv_f[j] * (1.0 - surv_m[j])
                                            
                                            v_both = V[j+1, ikp, 0, 0, ie]
                                            v_m = v_singles[0, j+1, ikp, 0, ie]
                                            v_f = v_singles[1, j+1, ikp, 0, ie]
                                            ev = p_both * v_both + p_m_only * v_m + p_f_only * v_f
                                        else:
                                            # Working age: Expectation over zm', zf'
                                            for izmp in range(nz):
                                                for izfp in range(nz):
                                                    v_next = V[j+1, ikp, izmp, izfp, :]
                                                    v_interp = linear_interp(e_grid, v_next, e_next)
                                                    ev += z_trans[izm, izmp] * z_trans[izf, izfp] * v_interp

                                    # Collective utility function
                                    u_m = utility(cons/eta, nm, theta_g[0], sigma_g[0], phi_m)
                                    u_f = utility(cons/eta, nf, theta_g[1], sigma_g[1], phi_f)
                                    curr_v = (u_m + u_f) + beta * ev
                                    
                                    if curr_v > best_v:
                                        best_v = curr_v
                                        V[j, ik, izm, izf, ie] = best_v
                                        C[j, ik, izm, izf, ie] = cons
                                        K_pol[j, ik, izm, izf, ie] = kp
                                        NM[j, ik, izm, izf, ie] = nm
                                        NF[j, ik, izm, izf, ie] = nf

