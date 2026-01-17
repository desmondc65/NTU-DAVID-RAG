## household_solver.py
import numpy as np
from numba import njit, prange
from typing import Tuple, Dict, Any


@njit
def interp1d_numba(x_val, x_grid, y_vals):
    """Simple linear interpolation for Numba-accelerated functions."""
    if x_val <= x_grid[0]:
        return y_vals[0]
    if x_val >= x_grid[-1]:
        return y_vals[-1]
    
    # Binary search to find the index
    low = 0
    high = len(x_grid) - 2
    idx = 0
    while low <= high:
        mid = (low + high) // 2
        if x_grid[mid] <= x_val:
            idx = mid
            low = mid + 1
        else:
            high = mid - 1
            
    # Interpolate
    weight = (x_val - x_grid[idx]) / (x_grid[idx + 1] - x_grid[idx])
    return y_vals[idx] * (1.0 - weight) + y_vals[idx + 1] * weight


@njit
def get_tax_income(y_pre, lam, tau):
    """Benabou-Heathcote progressive tax function: y_disposable = lambda * y_pre^(1-tau)."""
    if y_pre <= 0:
        return 0.0
    return lam * (y_pre ** (1.0 - tau))


@njit
def survival_prob(age_idx, gender, h, omegas):
    """Logistic survival probability function: s = 1 / (1 + exp(w0 + w1*j + w2*j^2 + w3*h))."""
    # age_idx: 1=25-29, ..., 15=99
    # omegas: [w0, w1, w2, w3]
    # omegas[3] should be < 0 for positive correlation with health
    power = omegas[0] + omegas[1] * age_idx + omegas[2] * (age_idx ** 2) + omegas[3] * h
    return 1.0 / (1.0 + np.exp(power))


class HouseholdSolver:
    """Solves the household lifecycle problem using backward induction and VFI.
    
    Handles singles (m/f) and married couples with endogenous health and survival risks.
    """

    def __init__(self, prices: Dict[str, float], gov_policy: Dict[str, Any], params: Dict[str, Any], grid_settings: Dict[str, Any]):
        """Initializes the solver with economic environment parameters.
        
        Args:
            prices: Dictionary containing 'r' (interest rate) and 'w' (wage).
            gov_policy: Dictionary containing tax, pension, and insurance policy parameters.
            params: General model parameters from Config.
            grid_settings: Grid dimensions and bounds.
        """
        self.r = prices['r']
        self.w = prices['w']
        self.gov = gov_policy
        self.params = params
        self.grids = grid_settings

        # Extract specific government parameters for easier access in NJIT
        self.tau_c = self.gov.get('tau_c', 0.1)
        self.phi = self.gov.get('phi_copay', 0.2)
        self.pi = self.gov.get('premium_rate', 0.0) # Calculated in GE loop
        self.psi = self.gov.get('replacement_rate', 0.4) # Calibrated
        self.bequest_dist = self.gov.get('bequest_dist', 0.0)

        # Tax parameters
        self.tax_s = self.gov.get('tax_single', {'lambda': 0.85, 'tau': 0.1})
        self.tax_m = self.gov.get('tax_married', {'lambda': 0.88, 'tau': 0.12})

    @staticmethod
    @njit
    def utility_function(c, n, sigma, theta, vg, eta=1.0, is_married=False):
        """Calculates utility for a period.
        
        If married, c is joint consumption and eta is the equivalence scale.
        u(c, n) = log(c) - theta * n^(1+sigma)/(1+sigma) + vg
        Married collective: U = u(c/eta, nm) + u(c/eta, nf)
        """
        if c <= 1e-6:
            return -1e10
        
        cons_utility = np.log(c / eta if is_married else c)
        leisure_utility = -theta * (n ** (1.0 + sigma)) / (1.0 + sigma)
        
        return cons_utility + leisure_utility + vg

    @staticmethod
    @njit
    def solve_retirement_age_njit(j, V_next_s_m, V_next_s_f, V_next_m,
                                 k_grid, e_grid, h_grid, h_trans, omegas,
                                 r, w, tau_c, phi, psi, 
                                 tax_s_lam, tax_s_tau, tax_m_lam, tax_m_tau,
                                 beta, sigma, vg_m, vg_f, theta_m, theta_f, eta,
                                 gamma, h_prod):
        """NJIT accelerated solver for one retirement age period (j >= 9)."""
        n_k, n_e, n_h = len(k_grid), len(e_grid), len(h_grid)
        
        # Policy functions and Value functions to fill
        V_s_m = np.zeros((n_k, n_h, n_e))
        V_s_f = np.zeros((n_k, n_h, n_e))
        V_married = np.zeros((n_k, n_h, n_e))
        
        # Grid dimensions for optimization
        # Decisions: k_prime and medical expense m
        m_grid = np.linspace(0.0, 2.0, 10) # Discretized medical spending grid
        
        # 1. Single Male & Female
        for i_e in range(n_e):
            e_val = e_grid[i_e]
            pension = psi * e_val
            for i_h in range(n_h):
                h_val = h_grid[i_h]
                for i_k in range(n_k):
                    k_val = k_grid[i_k]
                    
                    # Pre-tax income: Pension + Capital return
                    y_pre = pension + r * k_val
                    y_dis = get_tax_income(y_pre, tax_s_lam, tax_s_tau)
                    total_resource = k_val + y_dis
                    
                    # Solve for Single Male
                    best_v_m = -1e10
                    for ikp in range(n_k):
                        kp = k_grid[ikp]
                        for im in range(len(m_grid)):
                            m_val = m_grid[im]
                            c = (total_resource - phi * m_val - kp) / (1.0 + tau_c)
                            if c <= 0: continue
                            
                            # Survival and health evolution
                            prob_surv = survival_prob(j, 0, h_val, omegas)
                            # Health transition: sum over h' states
                            e_v_next = 0.0
                            # Note: Simplified health transition shifting with m
                            # In full model, prob(h'|h, m) would be used
                            for i_hp in range(n_h):
                                e_v_next += h_trans[j-9, i_h, i_hp] * V_next_s_m[ikp, i_hp, i_e]
                            
                            v = HouseholdSolver.utility_function(c, 0, sigma, theta_m, vg_m) + beta * prob_surv * e_v_next
                            if v > best_v_m: best_v_m = v
                    V_s_m[i_k, i_h, i_e] = best_v_m
                    
                    # Solve for Single Female
                    best_v_f = -1e10
                    for ikp in range(n_k):
                        kp = k_grid[ikp]
                        for im in range(len(m_grid)):
                            m_val = m_grid[im]
                            c = (total_resource - phi * m_val - kp) / (1.0 + tau_c)
                            if c <= 0: continue
                            
                            prob_surv = survival_prob(j, 1, h_val, omegas)
                            e_v_next = 0.0
                            for i_hp in range(n_h):
                                e_v_next += h_trans[j-9, i_h, i_hp] * V_next_s_f[ikp, i_hp, i_e]
                            
                            v = HouseholdSolver.utility_function(c, 0, sigma, theta_f, vg_f) + beta * prob_surv * e_v_next
                            if v > best_v_f: best_v_f = v
                    V_s_f[i_k, i_h, i_e] = best_v_f

        # 2. Married Couples (Collective Decision)
        for i_e in range(n_e):
            e_val = e_grid[i_e]
            pension_joint = 2.0 * psi * e_val
            for i_h in range(n_h):
                h_val = h_grid[i_h]
                for i_k in range(n_k):
                    k_val = k_grid[i_k]
                    
                    # Pooled resources
                    y_pre = pension_joint + r * k_val
                    y_dis = get_tax_income(y_pre, tax_m_lam, tax_m_tau)
                    total_resource = k_val + y_dis
                    
                    best_v = -1e10
                    for ikp in range(n_k):
                        kp = k_grid[ikp]
                        for im in range(len(m_grid)):
                            m_val = m_grid[im]
                            c = (total_resource - phi * m_val - kp) / (1.0 + tau_c)
                            if c <= 0: continue
                            
                            # Survival outcomes
                            sm = survival_prob(j, 0, h_val, omegas)
                            sf = survival_prob(j, 1, h_val, omegas)
                            
                            # Next period value estimation
                            e_v_next_m = 0.0 # Both survive
                            e_v_next_sm = 0.0 # Only husband survives
                            e_v_next_sf = 0.0 # Only wife survives
                            
                            for i_hp in range(n_h):
                                trans_prob = h_trans[j-9, i_h, i_hp]
                                e_v_next_m += trans_prob * V_next_m[ikp, i_hp, i_e]
                                e_v_next_sm += trans_prob * V_next_s_m[ikp, i_hp, i_e]
                                e_v_next_sf += trans_prob * V_next_s_f[ikp, i_hp, i_e]
                            
                            # Joint Utility Logic
                            # U = u(c/eta, 0) + u(c/eta, 0)
                            u_joint = HouseholdSolver.utility_function(c, 0, sigma, theta_m, vg_m, eta, True) + \
                                      HouseholdSolver.utility_function(c, 0, sigma, theta_f, vg_f, eta, True)
                            
                            v = u_joint + beta * (sm * sf * e_v_next_m + 
                                                 sm * (1.0 - sf) * e_v_next_sm + 
                                                 sf * (1.0 - sm) * e_v_next_sf)
                            if v > best_v: best_v = v
                    V_married[i_k, i_h, i_e] = best_v
                    
        return V_s_m, V_s_f, V_married

    @staticmethod
    @njit
    def solve_working_age_njit(j, V_next_s_m, V_next_s_f, V_next_m,
                              k_grid, e_grid, z_grid, pi_z, pi_joint,
                              r, w, tau_c, pi_rate, bequest,
                              tax_s_lam, tax_s_tau, tax_m_lam, tax_m_tau,
                              eps_m, eps_f, # Age-dependent human capital
                              beta, sigma, vg_m, vg_f, theta_m, theta_f, eta):
        """NJIT accelerated solver for one working age period (j < 9)."""
        n_k, n_e, n_z = len(k_grid), len(e_grid), len(z_grid)
        V_s_m = np.zeros((n_k, n_z, n_e))
        V_s_f = np.zeros((n_k, n_z, n_e))
        V_married = np.zeros((n_k, n_z * n_z, n_e))
        
        n_choice = np.linspace(0.0, 1.0, 5) # Labor supply grid

        # Singles Loop
        for i_e in range(n_e):
            e_val = e_grid[i_e]
            for i_z in range(n_z):
                z_val = z_grid[i_z]
                for i_k in range(n_k):
                    k_val = k_grid[i_k]
                    
                    # Single Male
                    best_v_m = -1e10
                    for ikp in range(n_k):
                        kp = k_grid[ikp]
                        for in_m in range(len(n_choice)):
                            n_m = n_choice[in_m]
                            earning = w * np.exp(z_val) * eps_m * n_m
                            y_pre = earning + r * k_val
                            y_dis = get_tax_income(y_pre, tax_s_lam, tax_s_tau)
                            c = (k_val + y_dis + bequest - pi_rate * earning - kp) / (1.0 + tau_c)
                            if c <= 0: continue
                            
                            # Earnings update: e' = ((j-1)e + earning)/j
                            e_next = ((j - 1.0) * e_val + earning) / j
                            
                            # Expectation over z'
                            ev = 0.0
                            for izp in range(n_z):
                                # Interpolate over e_next
                                v_next_at_enext = interp1d_numba(e_next, e_grid, V_next_s_m[ikp, izp, :])
                                ev += pi_z[i_z, izp] * v_next_at_enext
                                
                            v = HouseholdSolver.utility_function(c, n_m, sigma, theta_m, vg_m) + beta * ev
                            if v > best_v_m: best_v_m = v
                    V_s_m[i_k, i_z, i_e] = best_v_m
                    
                    # Single Female
                    best_v_f = -1e10
                    for ikp in range(n_k):
                        kp = k_grid[ikp]
                        for in_f in range(len(n_choice)):
                            n_f = n_choice[in_f]
                            earning = w * np.exp(z_val) * eps_f * n_f
                            y_pre = earning + r * k_val
                            y_dis = get_tax_income(y_pre, tax_s_lam, tax_s_tau)
                            c = (k_val + y_dis + bequest - pi_rate * earning - kp) / (1.0 + tau_c)
                            if c <= 0: continue
                            
                            e_next = ((j - 1.0) * e_val + earning) / j
                            ev = 0.0
                            for izp in range(n_z):
                                v_next_at_enext = interp1d_numba(e_next, e_grid, V_next_s_f[ikp, izp, :])
                                ev += pi_z[i_z, izp] * v_next_at_enext
                                
                            v = HouseholdSolver.utility_function(c, n_f, sigma, theta_f, vg_f) + beta * ev
                            if v > best_v_f: best_v_f = v
                    V_s_f[i_k, i_z, i_e] = best_v_f

        # Married Loop (State: k, z_m, z_f, e)
        # Note: z_joint maps to a flattened z_m * n_z + z_f
        for i_e in range(n_e):
            e_val = e_grid[i_e]
            for izm in range(n_z):
                z_m = z_grid[izm]
                for izf in range(n_z):
                    iz_joint = izm * n_z + izf
                    z_f = z_grid[izf]
                    for i_k in range(n_k):
                        k_val = k_grid[i_k]
                        
                        best_v = -1e10
                        for ikp in range(n_k):
                            kp = k_grid[ikp]
                            for inm in range(len(n_choice)):
                                n_m = n_choice[inm]
                                for inf in range(len(n_choice)):
                                    n_f = n_choice[inf]
                                    
                                    earning_m = w * np.exp(z_m) * eps_m * n_m
                                    earning_f = w * np.exp(z_f) * eps_f * n_f
                                    
                                    # Disposable income (separate taxation on shared assets)
                                    y_dis_m = get_tax_income(earning_m + r * k_val / 2.0, tax_m_lam, tax_m_tau)
                                    y_dis_f = get_tax_income(earning_f + r * k_val / 2.0, tax_m_lam, tax_m_tau)
                                    
                                    c = (k_val + y_dis_m + y_dis_f + bequest - pi_rate * (earning_m + earning_f) - kp) / (1.0 + tau_c)
                                    if c <= 0: continue
                                    
                                    # Joint pooled average earnings update
                                    e_next = ((j - 1.0) * e_val + (earning_m + earning_f) / 2.0) / j
                                    
                                    ev = 0.0
                                    for izp_joint in range(n_z * n_z):
                                        v_next_at_enext = interp1d_numba(e_next, e_grid, V_next_m[ikp, izp_joint, :])
                                        ev += pi_joint[iz_joint, izp_joint] * v_next_at_enext
                                        
                                    u_joint = HouseholdSolver.utility_function(c, n_m, sigma, theta_m, vg_m, eta, True) + \
                                              HouseholdSolver.utility_function(c, n_f, sigma, theta_f, vg_f, eta, True)
                                    v = u_joint + beta * ev
                                    if v > best_v: best_v = v
                        V_married[i_k, iz_joint, i_e] = best_v
                        
        return V_s_m, V_s_f, V_married

    def backward_induction(self, z_states, pi_z, pi_joint, h_trans, omegas, eps_profile) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """Orchestrates the backward induction process from j=15 down to 1."""
        n_p = self.params['num_periods']
        jr = self.params['jr'] # Retirement period (9)
        
        k_grid = np.linspace(self.grids['k_min'], self.grids['k_max'], self.grids['n_k'])
        e_grid = np.linspace(self.grids['e_min'], self.grids['e_max'], self.grids['n_e'])
        h_grid = np.array(self.grids['h_states'], dtype=np.float64)
        
        # Storage for value functions
        # Dimensions: Singles (Age, K, Health or Z, E), Married (Age, K, Health or Z_joint, E)
        # Note: Health is relevant for j >= 9, Z is relevant for j < 9
        V_s_m = {} 
        V_s_f = {}
        V_m = {}

        # Initial Terminal Value V_{J+1} = 0
        V_next_sm = np.zeros((self.grids['n_k'], self.grids['n_h'], self.grids['n_e']))
        V_next_sf = np.zeros((self.grids['n_k'], self.grids['n_h'], self.grids['n_e']))
        V_next_m = np.zeros((self.grids['n_k'], self.grids['n_h'], self.grids['n_e']))

        # Retirement Phase (j=15 down to 9)
        for j in range(n_p, jr - 1, -1):
            V_curr_sm, V_curr_sf, V_curr_m = self.solve_retirement_age_njit(
                j, V_next_sm, V_next_sf, V_next_m,
                k_grid, e_grid, h_grid, h_trans, omegas,
                self.r, self.w, self.tau_c, self.phi, self.psi,
                self.tax_s['lambda'], self.tax_s['tau'], self.tax_m['lambda'], self.tax_m['tau'],
                self.params['beta_period'], self.params['sigma'], self.params['vg_male'], self.params['vg_female'],
                0.5, 0.5, # Assume disutility parameters for leisure in retirement if needed
                self.params['eta'], self.params['gamma'], self.params['h_productivity']
            )
            V_s_m[j] = V_curr_sm
            V_s_f[j] = V_curr_sf
            V_m[j] = V_curr_m
            
            V_next_sm, V_next_sf, V_next_m = V_curr_sm, V_curr_sf, V_curr_m

        # Transition to Working Phase (j=8 down to 1)
        # Re-initialize "next" variables for Z state space
        # At age 65 (j=9), V depends on health. Working agents don't have health shocks.
        # We assume j=9 is the first retirement period. We take expectation over health status.
        V_next_sm_z = np.zeros((self.grids['n_k'], self.grids['n_z'], self.grids['n_e']))
        V_next_sf_z = np.zeros((self.grids['n_k'], self.grids['n_z'], self.grids['n_e']))
        V_next_m_z = np.zeros((self.grids['n_k'], self.grids['n_z']**2, self.grids['n_e']))
        
        # Integrate health for transition age j=8 -> j=9
        # Assuming initial health at 65 is average (index 2)
        for i_k in range(self.grids['n_k']):
            for i_e in range(self.grids['n_e']):
                for i_z in range(self.grids['n_z']):
                    V_next_sm_z[i_k, i_z, i_e] = V_s_m[jr][i_k, 2, i_e]
                    V_next_sf_z[i_k, i_z, i_e] = V_s_f[jr][i_k, 2, i_e]
                for i_zj in range(self.grids['n_z']**2):
                    V_next_m_z[i_k, i_zj, i_e] = V_m[jr][i_k, 2, i_e]

        for j in range(jr - 1, 0, -1):
            V_curr_sm, V_curr_sf, V_curr_m = self.solve_working_age_njit(
                j, V_next_sm_z, V_next_sf_z, V_next_m_z,
                k_grid, e_grid, z_states, pi_z, pi_joint,
                self.r, self.w, self.tau_c, self.pi, self.bequest_dist,
                self.tax_s['lambda'], self.tax_s['tau'], self.tax_m['lambda'], self.tax_m['tau'],
                eps_profile[j-1, 0], eps_profile[j-1, 1],
                self.params['beta_period'], self.params['sigma'], self.params['vg_male'], self.params['vg_female'],
                0.6, 0.8, # Placeholder disutility of work theta_m, theta_f
                self.params['eta']
            )
            V_s_m[j] = V_curr_sm
            V_s_f[j] = V_curr_sf
            V_m[j] = V_curr_m
            
            V_next_sm_z, V_next_sf_z, V_next_m_z = V_curr_sm, V_curr_sf, V_curr_m

        return V_s_m, V_s_f, V_m

    def solve_retirement_age(self, j, V_next):
        """Standard interface for solving a specific retirement age. 
        Note: Implementation delegated to NJIT version for performance.
        """
        pass # Backward induction handles this calls

    def solve_working_age(self, j, V_next):
        """Standard interface for solving a specific working age.
        Note: Implementation delegated to NJIT version for performance.
        """
        pass
