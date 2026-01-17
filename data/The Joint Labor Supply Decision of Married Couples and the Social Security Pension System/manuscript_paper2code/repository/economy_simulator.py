## economy_simulator.py
import numpy as np
from numba import njit, prange
from typing import Dict, Any, Tuple
from config import Config
from social_security import SocialSecurity

@njit(parallel=True)
def _distribute_mass(
    ni: int, na: int, nb: int, ne: int, nm: int,
    dist: np.ndarray,
    a_grid: np.ndarray,
    b_grid: np.ndarray,
    a_next_pol: np.ndarray,
    b1_next_pol: np.ndarray,
    b2_next_pol: np.ndarray,
    e_trans_single: np.ndarray,
    e_trans_joint: np.ndarray,
    phi_m: np.ndarray,
    phi_f: np.ndarray,
    nu: float
) -> np.ndarray:
    """
    Numba-accelerated kernel to compute the law of motion for the household distribution.
    Uses linear interpolation (weights) to distribute mass onto the discrete grid.
    """
    new_dist = np.zeros_like(dist)
    pop_growth_factor = 1.0 / (1.0 + nu)

    for age_idx in range(ni - 1):
        for m in prange(nm):
            for i_a in range(na):
                for i_b1 in range(nb):
                    for i_b2 in range(nb):
                        for i_e1 in range(ne):
                            for i_e2 in range(ne):
                                mass = dist[age_idx, i_a, i_b1, i_b2, i_e1, i_e2, m]
                                if mass < 1e-15:
                                    continue
                                
                                # Current policies
                                a_next = a_next_pol[age_idx, i_a, i_b1, i_b2, i_e1, i_e2, m]
                                b1_next = b1_next_pol[age_idx, i_a, i_b1, i_b2, i_e1, i_e2, m]
                                b2_next = b2_next_pol[age_idx, i_a, i_b1, i_b2, i_e1, i_e2, m]
                                
                                # Find indices and weights for wealth
                                ia_low = np.searchsorted(a_grid, a_next) - 1
                                ia_low = min(max(ia_low, 0), na - 2)
                                wa_high = (a_next - a_grid[ia_low]) / (a_grid[ia_low+1] - a_grid[ia_low])
                                wa_high = min(max(wa_high, 0.0), 1.0)
                                
                                # Find indices and weights for B1
                                ib1_low = np.searchsorted(b_grid, b1_next) - 1
                                ib1_low = min(max(ib1_low, 0), nb - 2)
                                wb1_high = (b1_next - b_grid[ib1_low]) / (b_grid[ib1_low+1] - b_grid[ib1_low])
                                wb1_high = min(max(wb1_high, 0.0), 1.0)

                                # Find indices and weights for B2
                                ib2_low = np.searchsorted(b_grid, b2_next) - 1
                                ib2_low = min(max(ib2_low, 0), nb - 2)
                                wb2_high = (b2_next - b_grid[ib2_low]) / (b_grid[ib2_low+1] - b_grid[ib2_low])
                                wb2_high = min(max(wb2_high, 0.0), 1.0)

                                # Transitions: Marital Status
                                pm0, pm1, pm2 = 0.0, 0.0, 0.0
                                if m == 0:
                                    pm0 = phi_m[age_idx] * phi_f[age_idx]
                                    pm1 = phi_m[age_idx] * (1.0 - phi_f[age_idx])
                                    pm2 = (1.0 - phi_m[age_idx]) * phi_f[age_idx]
                                elif m == 1:
                                    pm1 = phi_m[age_idx]
                                elif m == 2:
                                    pm2 = phi_f[age_idx]

                                # Transition: Shocks
                                for i_e1_next in range(ne):
                                    for i_e2_next in range(ne):
                                        if m == 0:
                                            prob_e = e_trans_joint[i_e1 * ne + i_e2, i_e1_next * ne + i_e2_next]
                                        elif m == 1:
                                            prob_e = e_trans_single[i_e1, i_e1_next] if i_e2_next == 0 else 0.0
                                        else: # m == 2
                                            prob_e = e_trans_single[i_e2, i_e2_next] if i_e1_next == 0 else 0.0
                                        
                                        if prob_e == 0: continue

                                        # Distribute mass across m', a', b1', b2'
                                        for m_next, p_m in enumerate([pm0, pm1, pm2]):
                                            if p_m <= 0: continue
                                            
                                            total_mass = mass * p_m * prob_e * pop_growth_factor
                                            
                                            # Triple linear interpolation distribution
                                            for i_a_off in range(2):
                                                wa = (1.0 - wa_high) if i_a_off == 0 else wa_high
                                                for i_b1_off in range(2):
                                                    wb1 = (1.0 - wb1_high) if i_b1_off == 0 else wb1_high
                                                    for i_b2_off in range(2):
                                                        wb2 = (1.0 - wb2_high) if i_b2_off == 0 else wb2_high
                                                        
                                                        final_mass = total_mass * wa * wb1 * wb2
                                                        new_dist[age_idx + 1, ia_low + i_a_off, ib1_low + i_b1_off, ib2_low + i_b2_off, i_e1_next, i_e2_next, m_next] += final_mass
    return new_dist


class EconomySimulator:
    """
    Simulates the population distribution and aggregates macroeconomic variables.
    
    This class implements the forward simulation of the population distribution x(s)
    given optimal household decisions and calculates aggregate K, L, tax revenues,
    and accidental bequests.
    """

    def __init__(self, config: Config, ss: SocialSecurity, grids: Dict[str, np.ndarray]):
        """
        Initializes the simulator with model parameters and state grids.
        """
        self.config = config
        self.ss = ss
        self.grids = grids
        
        # Grid sizes
        self.ni = config.total_periods
        self.na = config.wealth_nodes
        self.nb = config.earning_nodes
        self.ne = config.shock_nodes
        self.nm = 3
        
        # Initialize distribution
        self.distribution = np.zeros((self.ni, self.na, self.nb, self.nb, self.ne, self.ne, self.nm))
        
        # Policy arrays (to be populated by HouseholdSolver)
        self.policy_arrays = {}
        
        # Accidental bequests and government net worth
        self.q = 0.0
        self.w_g = 0.0 # Assumed 0 in baseline steady state

    def simulate_forward(self, policy_functions: Dict[str, np.ndarray]) -> None:
        """
        Computes the stationary distribution of households given policy functions.
        
        Args:
            policy_functions: Dictionary containing arrays for 'c', 'h1', 'h2', 'a_next'.
        """
        self.policy_arrays = policy_functions
        self.distribution.fill(0.0)
        
        # 1. Initialize Age 21 (Section 3.4 & 3.1)
        # All start with 0 wealth and 0 AIME
        eta = self.config.eta
        pi_e_start = np.array([0.0625, 0.2500, 0.3750, 0.2500, 0.0625]) # Section 3.4
        
        for i_e1 in range(self.ne):
            for i_e2 in range(self.ne):
                # Married (m=0)
                prob_joint = pi_e_start[i_e1] * pi_e_start[i_e2]
                self.distribution[0, 0, 0, 0, i_e1, i_e2, 0] = eta * prob_joint
                
                # Single Men (m=1) - assume e2=0 index is dummy
                if i_e2 == 0:
                    self.distribution[0, 0, 0, 0, i_e1, 0, 1] = (1.0 - eta) * pi_e_start[i_e1]
                
                # Single Women (m=2) - assume e1=0 index is dummy
                if i_e1 == 0:
                    self.distribution[0, 0, 0, 0, 0, i_e2, 2] = (1.0 - eta) * pi_e_start[i_e2]

        # 2. Iterate forward using the distribution law of motion
        a_next_pol = policy_functions['a_next']
        
        # Calculate AIME transition policies (Section 2.1)
        # b_next = (1{i<IR, m!=j} / (i-20)) * ((i-21)b + min(w*e*h, vmax)) + 1{i>=IR or m==j} * b
        b1_next_pol = np.zeros_like(a_next_pol)
        b2_next_pol = np.zeros_like(a_next_pol)
        
        w_val = 1.0 # Normalization for baseline
        v_max = self.config.oasi_thresholds[1] * 5.0 # High value relative to threshold

        for age_idx in range(self.ni):
            age = age_idx + self.config.age_start
            weight_old = (age - 21.0) / (age - 20.0) if age > 21 else 0.0
            weight_new = 1.0 / (age - 20.0) if age > 21 else 1.0
            
            for m in range(self.nm):
                h1 = policy_functions['h1'][age_idx, ..., m]
                h2 = policy_functions['h2'][age_idx, ..., m]
                
                # Vectorized AIME update logic
                if age < self.config.age_retirement:
                    # Logic for b1
                    if m != 2: # Married or Single Male
                        for i_e1 in range(self.ne):
                            e1 = np.exp(self.grids['e_nodes'][i_e1])
                            lab_inc1 = np.minimum(w_val * e1 * h1[..., i_e1, :], v_max)
                            b1_next_pol[age_idx, ..., i_e1, :, m] = weight_old * self.grids['b'][:, None, None] + weight_new * lab_inc1
                    else:
                        b1_next_pol[age_idx, ..., m] = self.grids['b'][:, None, None]
                        
                    # Logic for b2
                    if m != 1: # Married or Single Female
                        for i_e2 in range(self.ne):
                            e2 = np.exp(self.grids['e_nodes'][i_e2])
                            lab_inc2 = np.minimum(w_val * e2 * h2[..., :, i_e2], v_max)
                            b2_next_pol[age_idx, ..., :, i_e2, m] = weight_old * self.grids['b'][None, :, None] + weight_new * lab_inc2
                    else:
                        b2_next_pol[age_idx, ..., m] = self.grids['b'][None, :, None]
                else:
                    # After retirement, AIME stays constant
                    b1_next_pol[age_idx, ..., m] = self.grids['b'][:, None, None]
                    b2_next_pol[age_idx, ..., m] = self.grids['b'][None, :, None]

        # Call Numba kernel
        self.distribution = _distribute_mass(
            self.ni, self.na, self.nb, self.ne, self.nm,
            self.distribution,
            self.grids['a'], self.grids['b'],
            a_next_pol, b1_next_pol, b2_next_pol,
            self.grids['e_trans_single'], self.grids['e_trans_joint'],
            self.grids.get('phi_m', np.ones(self.ni)),
            self.grids.get('phi_f', np.ones(self.ni)),
            self.config.nu
        )

    def aggregate_k_l(self) -> Tuple[float, float]:
        """
        Calculates aggregate capital (K) and labor supply (L) in efficiency units.
        
        Returns:
            Tuple[float, float]: (K, L)
        """
        # Aggregate Private Wealth W_P
        w_p = 0.0
        l_eff = 0.0
        
        for age_idx in range(self.ni):
            for m in range(self.nm):
                # Private Wealth sum_s x(s)*a
                w_p += np.sum(self.distribution[age_idx, ..., m] * self.grids['a'][:, None, None, None, None])
                
                # Labor Supply sum_s x(s) * (e1*h1 + e2*h2)
                if age_idx + self.config.age_start < self.config.age_retirement:
                    h1 = self.policy_arrays['h1'][age_idx, ..., m]
                    h2 = self.policy_arrays['h2'][age_idx, ..., m]
                    
                    for i_e1 in range(self.ne):
                        e1 = np.exp(self.grids['e_nodes'][i_e1])
                        l_eff += np.sum(self.distribution[age_idx, :, :, :, i_e1, :, m] * e1 * h1[:, :, :, i_e1, :])
                    
                    for i_e2 in range(self.ne):
                        e2 = np.exp(self.grids['e_nodes'][i_e2])
                        l_eff += np.sum(self.distribution[age_idx, :, :, :, :, i_e2, m] * e2 * h2[:, :, :, :, i_e2])
        
        capital = w_p + self.w_g
        return capital, l_eff

    def calculate_tax_revenue(self, prices: Dict[str, float], psi_t: float = 1.0, pol_type: str = "baseline") -> Dict[str, float]:
        """
        Aggregates government tax revenues and Social Security expenditures.
        
        Returns:
            Dict: {'t_p': payroll_tax, 't_i': income_tax, 't_rss': ss_expenditure, 'q': bequests}
        """
        r, w = prices['r'], prices['w']
        t_p, t_i, t_rss, bequests = 0.0, 0.0, 0.0, 0.0
        
        phi_m = self.grids.get('phi_m', np.ones(self.ni))
        phi_f = self.grids.get('phi_f', np.ones(self.ni))
        v_max = self.config.oasi_thresholds[1] * 5.0

        for age_idx in range(self.ni):
            age = age_idx + self.config.age_start
            m_mult = np.array([2.0, 1.0, 1.0])
            
            for m in range(self.nm):
                dist_slice = self.distribution[age_idx, ..., m]
                a_slice = self.grids['a'][:, None, None, None, None]
                b1_slice = self.grids['b'][None, :, None, None, None]
                b2_slice = self.grids['b'][None, None, :, None, None]
                
                # 1. Accidental Bequests (Deceased wealth)
                survival_prob = 1.0
                if m == 0: survival_prob = phi_m[age_idx] * phi_f[age_idx]
                elif m == 1: survival_prob = phi_m[age_idx]
                elif m == 2: survival_prob = phi_f[age_idx]
                bequests += np.sum(dist_slice * a_slice * (1.0 - survival_prob))
                
                # 2. OASI Benefits (if retired)
                if age >= self.config.age_retirement:
                    benefits = self.ss.get_benefit(m, age, b1_slice, b2_slice, psi_t, pol_type)
                    t_rss += np.sum(dist_slice * benefits)
                
                # 3. Taxes (if working/has wealth)
                h1 = self.policy_arrays['h1'][age_idx, ..., m]
                h2 = self.policy_arrays['h2'][age_idx, ..., m]
                
                # Payroll tax and Income tax (Vectorized calculation)
                for i_e1 in range(self.ne):
                    e1 = np.exp(self.grids['e_nodes'][i_e1])
                    for i_e2 in range(self.ne):
                        e2 = np.exp(self.grids['e_nodes'][i_e2])
                        
                        y1, y2 = w * e1 * h1[..., i_e1, i_e2], w * e2 * h2[..., i_e1, i_e2]
                        
                        # Payroll tax
                        t_p += np.sum(dist_slice[..., i_e1, i_e2] * self.config.tau_p * (np.minimum(y1, v_max) + np.minimum(y2, v_max)))
                        
                        # Income tax
                        y_taxable = np.maximum(r * a_slice.squeeze()[:, None, None] + y1 + y2 - m_mult[m] * self.config.standard_deduction, 0.0)
                        # Apply Gouveia-Strauss (simplified here as linear phi_t since full function is inside HouseholdSolver)
                        tax_i = self.config.phi_t * y_taxable 
                        t_i += np.sum(dist_slice[..., i_e1, i_e2] * tax_i)

        # Normalize bequests: paper says uniformly distributed to all working-age adults
        self.q = bequests # Should be normalized by total working-age population count later
        
        return {'t_p': t_p, 't_i': t_i, 't_rss': t_rss, 'q': bequests}

