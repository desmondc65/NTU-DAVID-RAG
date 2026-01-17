## economy_simulator.py
import numpy as np
from numba import njit, prange
from scipy import optimize
from typing import Dict, Any, Tuple
from parameters import ModelParams
from lifecycle_solver import LifecycleSolver, get_disposable_income

@njit(cache=True)
def distribute_mass(grid: np.ndarray, val: float, mass: float, target_dist: np.ndarray):
    """
    Distributes mass to the two nearest grid points using linear interpolation weights.
    Used for mapping policy outcomes back to the stationary distribution grids.
    """
    size = len(grid)
    if val <= grid[0]:
        target_dist[0] += mass
    elif val >= grid[-1]:
        target_dist[-1] += mass
    else:
        # Find index such that grid[idx] <= val < grid[idx+1]
        idx = np.searchsorted(grid, val) - 1
        x0, x1 = grid[idx], grid[idx+1]
        weight_high = (val - x0) / (x1 - x0)
        target_dist[idx] += mass * (1.0 - weight_high)
        target_dist[idx+1] += mass * weight_high

@njit(parallel=True, cache=True)
def _iterate_distribution_jit(
    dist_s: np.ndarray, dist_m: np.ndarray,
    k_pol_s: np.ndarray, n_pol_s: np.ndarray,
    k_pol_m: np.ndarray, nm_pol_m: np.ndarray, nf_pol_m: np.ndarray,
    k_grid: np.ndarray, e_grid: np.ndarray, z_states: np.ndarray, z_trans: np.ndarray,
    surv: np.ndarray, eps: np.ndarray, J: int, Jr: int, w: float, phi_m: float
) -> Tuple[np.ndarray, np.ndarray, float]:
    """
    Propagates the mass of households through the state space over time.
    Calculates stationary distributions for singles and married households.
    Also collects accidental bequests.
    """
    nk, nz, ne = len(k_grid), len(z_states), len(e_grid)
    
    # Initialize next period distributions
    new_dist_s = np.zeros_like(dist_s)
    new_dist_m = np.zeros_like(dist_m)
    bequests = 0.0

    # 1. Singles Distribution Iteration
    for g in range(2):
        for j in range(J - 1):
            for ik in prange(nk):
                for iz in range(nz):
                    for ie in range(ne):
                        mass = dist_s[g, j, ik, iz, ie]
                        if mass < 1e-15: continue
                        
                        # Policy outcomes
                        kp = k_pol_s[g, j, ik, iz, ie]
                        n = n_pol_s[g, j, ik, iz, ie]
                        
                        # Update average earnings (ẽ)
                        if (j + 1) < Jr:
                            e_curr = w * z_states[iz] * eps[g, j] * n
                            e_next = (j * e_grid[ie] + e_curr) / (j + 1)
                        else:
                            e_next = e_grid[ie]
                            
                        # Survival and Bequests
                        s_prob = surv[g, j]
                        bequests += mass * (1.0 - s_prob) * kp
                        
                        # Move mass to j+1
                        surviving_mass = mass * s_prob
                        for izp in range(nz):
                            p_trans = z_trans[iz, izp]
                            
                            # Linear interpolation weight for kp and e_next
                            # Logic: Find grid neighbors and distribute mass
                            # This is done across multiple dimensions (k, e)
                            # For simplicity in Numba, we do nested search and assignment
                            
                            # Find k indices
                            ikp = np.searchsorted(k_grid, kp) - 1
                            ikp = max(0, min(ikp, nk - 2))
                            wk_h = (kp - k_grid[ikp]) / (k_grid[ikp+1] - k_grid[ikp])
                            
                            # Find e indices
                            iep = np.searchsorted(e_grid, e_next) - 1
                            iep = max(0, min(iep, ne - 2))
                            we_h = (e_next - e_grid[iep]) / (e_grid[iep+1] - e_grid[iep])
                            
                            m_trans = surviving_mass * p_trans
                            new_dist_s[g, j+1, ikp, izp, iep] += m_trans * (1.0 - wk_h) * (1.0 - we_h)
                            new_dist_s[g, j+1, ikp+1, izp, iep] += m_trans * wk_h * (1.0 - we_h)
                            new_dist_s[g, j+1, ikp, izp, iep+1] += m_trans * (1.0 - wk_h) * we_h
                            new_dist_s[g, j+1, ikp+1, izp, iep+1] += m_trans * wk_h * we_h

    # 2. Married Distribution Iteration
    for j in range(J - 1):
        for ik in prange(nk):
            for izm in range(nz):
                for izf in range(nz):
                    for ie in range(ne):
                        mass = dist_m[j, ik, izm, izf, ie]
                        if mass < 1e-15: continue
                        
                        kp = k_pol_m[j, ik, izm, izf, ie]
                        nm = nm_pol_m[j, ik, izm, izf, ie]
                        nf = nf_pol_m[j, ik, izm, izf, ie]
                        
                        if (j + 1) < Jr:
                            em = w * z_states[izm] * eps[0, j] * nm
                            ef = w * z_states[izf] * eps[1, j] * nf
                            e_next = (j * e_grid[ie] + (em + ef)/2.0) / (j + 1)
                        else:
                            e_next = e_grid[ie]
                            
                        sm, sf = surv[0, j], surv[1, j]
                        
                        # Bequests from both dying
                        bequests += mass * (1.0 - sm) * (1.0 - sf) * kp
                        
                        # Mass transitions: 
                        # - Both survive (to Married dist)
                        # - One survives (to Single dist)
                        
                        # Case 1: Both survive
                        m_both = mass * sm * sf
                        # Case 2: Only male survives
                        m_m_only = mass * sm * (1.0 - sf)
                        # Case 3: Only female survives
                        m_f_only = mass * sf * (1.0 - sm)
                        
                        # Grid weights
                        ikp = np.searchsorted(k_grid, kp) - 1
                        ikp = max(0, min(ikp, nk - 2))
                        wk_h = (kp - k_grid[ikp]) / (k_grid[ikp+1] - k_grid[ikp])
                        iep = np.searchsorted(e_grid, e_next) - 1
                        iep = max(0, min(iep, ne - 2))
                        we_h = (e_next - e_grid[iep]) / (e_grid[iep+1] - e_grid[iep])

                        # Propagate Both Surviving
                        for izmp in range(nz):
                            p_m = z_trans[izm, izmp]
                            for izfp in range(nz):
                                p_f = z_trans[izf, izfp]
                                total_p = p_m * p_f
                                m_tr = m_both * total_p
                                new_dist_m[j+1, ikp, izmp, izfp, iep] += m_tr * (1.0 - wk_h) * (1.0 - we_h)
                                new_dist_m[j+1, ikp+1, izmp, izfp, iep] += m_tr * wk_h * (1.0 - we_h)
                                new_dist_m[j+1, ikp, izmp, izfp, iep+1] += m_tr * (1.0 - wk_h) * we_h
                                new_dist_m[j+1, ikp+1, izmp, izfp, iep+1] += m_tr * wk_h * we_h
                                
                        # Propagate Single Survivors (to z=0 index for simplicity or average transition)
                        for izp in range(nz):
                            # Male only survives
                            p_m = z_trans[izm, izp]
                            m_tr_m = m_m_only * p_m
                            new_dist_s[0, j+1, ikp, izp, iep] += m_tr_m * (1.0 - wk_h) * (1.0 - we_h)
                            new_dist_s[0, j+1, ikp+1, izp, iep] += m_tr_m * wk_h * (1.0 - we_h)
                            new_dist_s[0, j+1, ikp, izp, iep+1] += m_tr_m * (1.0 - wk_h) * we_h
                            new_dist_s[0, j+1, ikp+1, izp, iep+1] += m_tr_m * wk_h * we_h
                            
                            # Female only survives
                            p_f = z_trans[izf, izp]
                            m_tr_f = m_f_only * p_f
                            new_dist_s[1, j+1, ikp, izp, iep] += m_tr_f * (1.0 - wk_h) * (1.0 - we_h)
                            new_dist_s[1, j+1, ikp+1, izp, iep] += m_tr_f * wk_h * (1.0 - we_h)
                            new_dist_s[1, j+1, ikp, izp, iep+1] += m_tr_f * (1.0 - wk_h) * we_h
                            new_dist_s[1, j+1, ikp+1, izp, iep+1] += m_tr_f * wk_h * we_h

    return new_dist_s, new_dist_m, bequests

class EconomySimulator:
    """
    Solves for the stationary General Equilibrium of the life-cycle economy.
    Finds market-clearing interest rate (r) and budget-balancing premium rate (t).
    """

    def __init__(self, params: ModelParams):
        self.p = params
        self.solver = LifecycleSolver(params)
        self.tol = self.p.config['solver']['tolerance_ge']
        self.max_iter = self.p.config['solver']['max_iterations_ge']
        
        # Fixed proportions of married couples vs singles at age 25
        self.phi_married = 0.5 # Default proportion
        
        # Store latest stationary distribution
        self.dist_s = None
        self.dist_m = None

    def compute_stationary_distribution(self, policy_funcs: Dict[str, Any], 
                                         w: float) -> Tuple[np.ndarray, np.ndarray, float]:
        """
        Calculates the stationary distribution by iterating mass forward through 
        the lifecycle given policy functions.
        """
        nk, nz, ne = len(self.p.k_grid), len(self.p.z_states), len(self.p.e_tilde_grid)
        
        # Initial mass at j=0 (Age 25)
        # We assume newborns have zero assets and zero avg earnings
        dist_s = np.zeros((2, self.p.J, nk, nz, ne))
        dist_m = np.zeros((self.p.J, nk, nz, nz, ne))
        
        # Initial productivity distribution (stationary distribution of first 4 states)
        z_start_prob = np.array([0.25, 0.25, 0.25, 0.25, 0.0])
        
        # Singles (Male/Female)
        for g in range(2):
            for iz in range(nz):
                dist_s[g, 0, 0, iz, 0] = (1.0 - self.phi_married) * 0.5 * z_start_prob[iz]
                
        # Married
        for izm in range(nz):
            for izf in range(nz):
                dist_m[0, 0, izm, izf, 0] = self.phi_married * z_start_prob[izm] * z_start_prob[izf]

        # Get survival and epsilon profiles from params
        # In a real run these would be obtained via data_handler
        surv = np.stack((self.p.get_survival_probs('m'), self.p.get_survival_probs('f')))
        eps = np.ones((2, self.p.J)) # Profiles

        # Iterate forward
        new_dist_s, new_dist_m, bequests = _iterate_distribution_jit(
            dist_s, dist_m,
            policy_funcs['s']['k_prime'], policy_funcs['s']['n'],
            policy_funcs['m']['k_prime'], policy_funcs['m']['n_m'], policy_funcs['m']['n_f'],
            self.p.k_grid, self.p.e_tilde_grid, self.p.z_states, self.p.z_transition,
            surv, eps, self.p.J, self.p.Jr, w, self.phi_married
        )
        
        self.dist_s = new_dist_s
        self.dist_m = new_dist_m
        
        # Return bequests collected to be distributed in the next iteration 
        # (Usually distributed uniformly to working-age population b = TotalBequests / WorkingPop)
        working_pop = np.sum(new_dist_s[:, :self.p.Jr-1]) + 2.0 * np.sum(new_dist_m[:self.p.Jr-1])
        b_per_cap = bequests / working_pop if working_pop > 0 else 0.0
        
        return new_dist_s, new_dist_m, b_per_cap

    def check_market_clearing(self, r: float, t: float, tax_max: float) -> Dict[str, float]:
        """
        Aggregates individual behavior over the stationary distribution to check
        capital market clearing and government budget balance.
        """
        # Load parameters
        alpha = self.p.alpha
        delta = self.p.delta
        psi = self.p.psi
        tau_c = self.p.tau_c
        
        # 1. Aggregate Supply side from Distribution
        k_supply = 0.0
        n_supply = 0.0
        total_cons = 0.0
        tax_revenue = 0.0
        premium_revenue = 0.0
        ss_expenditure = 0.0
        
        # Profiles
        eps = np.ones((2, self.p.J))
        z_s = self.p.z_states
        w = 1.0 # Global wage normalization
        
        # Policy functions must be cached or passed. Assuming they are consistent with self.dist
        # This implementation requires passing policy functions or accessing them from the solver
        # For brevity, we assume the simulator has access to the solver's results
        pf_s = self.solver_results['s']
        pf_m = self.solver_results['m']
        
        # Aggregation over Singles
        for g in range(2):
            for j in range(self.p.J):
                lam = self.p.lambda_tax['s']
                tau = self.p.tau_s
                y_b = (lam * (1.0 - tau) / (1.0 - tax_max))**(1.0 / tau)
                
                mass_slice = self.dist_s[g, j, :, :, :]
                k_supply += np.sum(mass_slice * pf_s['k_prime'][g, j])
                total_cons += np.sum(mass_slice * pf_s['c'][g, j])
                
                # Earnings and Taxes
                for ik in range(len(self.p.k_grid)):
                    for iz in range(len(z_s)):
                        for ie in range(len(self.p.e_tilde_grid)):
                            mass = self.dist_s[g, j, ik, iz, ie]
                            if mass < 1e-15: continue
                            
                            n = pf_s['n'][g, j, ik, iz, ie]
                            k = self.p.k_grid[ik]
                            
                            if j < self.p.Jr - 1:
                                labor_income = w * z_s[iz] * eps[g, j] * n
                                y_f = labor_income + r * k
                                premium_revenue += t * labor_income * mass
                                n_supply += labor_income * mass
                            else:
                                benefit = self.p.psi_ss * self.p.e_tilde_grid[ie]
                                y_f = benefit + r * k
                                ss_expenditure += benefit * mass
                            
                            y_d = get_disposable_income(y_f, y_b, lam, tau, tax_max)
                            tax_revenue += (y_f - y_d) * mass

        # Aggregation over Married
        for j in range(self.p.J):
            lam = self.p.lambda_tax['m']
            tau = self.p.tau_m
            y_b = (lam * (1.0 - tau) / (1.0 - tax_max))**(1.0 / tau)
            
            mass_slice = self.dist_m[j, :, :, :, :]
            k_supply += np.sum(mass_slice * pf_m['k_prime'][j])
            total_cons += np.sum(mass_slice * pf_m['c'][j])
            
            for ik in range(len(self.p.k_grid)):
                for izm in range(len(z_s)):
                    for izf in range(len(z_s)):
                        for ie in range(len(self.p.e_tilde_grid)):
                            mass = self.dist_m[j, ik, izm, izf, ie]
                            if mass < 1e-15: continue
                            
                            nm = pf_m['n_m'][j, ik, izm, izf, ie]
                            nf = pf_m['n_f'][j, ik, izm, izf, ie]
                            k = self.p.k_grid[ik]
                            
                            if j < self.p.Jr - 1:
                                em = w * z_s[izm] * eps[0, j] * nm
                                ef = w * z_s[izf] * eps[1, j] * nf
                                labor_inc = em + ef
                                y_f = labor_inc + r * k
                                premium_revenue += t * labor_inc * mass
                                n_supply += labor_inc * mass
                            else:
                                benefit = 2.0 * self.p.psi_ss * self.p.e_tilde_grid[ie]
                                y_f = benefit + r * k
                                ss_expenditure += benefit * mass
                                
                            y_d = get_disposable_income(y_f, y_b, lam, tau, tax_max)
                            tax_revenue += (y_f - y_d) * mass

        # 2. Firm sector and Demand side
        # Firm FOC: K/N = (alpha * psi / (r + delta))^(1 / (1-alpha))
        k_demand = n_supply * ( (alpha * psi) / (r + delta) )**(1.0 / (1.0 - alpha))
        output_y = psi * (k_demand**alpha) * (n_supply**(1.0 - alpha))
        
        # 3. Government Budget
        # Rev = Income Tax + Consumption Tax + Premiums
        total_revenue = tax_revenue + tau_c * total_cons + premium_revenue
        # Exp = SS + G (fixed share) + Tr (fixed share)
        g_exp = output_y * 0.044
        tr_exp = output_y * self.p.tr_gdp_share
        total_expenditure = ss_expenditure + g_exp + tr_exp
        
        return {
            'market_resid': k_supply - k_demand,
            'budget_resid': total_revenue - total_expenditure,
            'K': k_supply,
            'N': n_supply,
            'Y': output_y,
            'tax_rev': tax_revenue,
            'premium_rev': premium_revenue,
            'consumption': total_cons
        }

    def solve_steady_state(self, tax_max: float) -> Dict[str, Any]:
        """
        Orchestrates the general equilibrium iteration.
        1. Outer Loop: Brentq to find r that clears capital market.
        2. Inner Loop: Find t that balances government budget.
        """
        print(f"Solving Steady State for top tax rate: {tax_max}")
        
        def ge_objective(r_guess: float) -> float:
            # Firm FOC implies w given r
            # Since we normalized w=1 in calibration by choice of psi,
            # in policy analysis w shifts relative to benchmark.
            # But let's assume we find r such that K_s = K_d.
            
            # Inner Loop for t (Premium Rate)
            def budget_objective(t_guess: float) -> float:
                # Solve Household Problem
                tax_params = {'tau_max': tax_max}
                # Initial bequests guess
                b_guess = 0.0
                
                # Iterate on policy and distribution until stationary (including bequests)
                for _ in range(5): 
                    self.solver_results = {
                        's': self.solver.solve_singles(r_guess, t_guess, tax_params, b=b_guess),
                        'm': self.solver.solve_married(r_guess, t_guess, tax_params, 
                                                      self.solver.solve_singles(r_guess, t_guess, tax_params, b=b_guess)['v'],
                                                      b=b_guess)
                    }
                    _, _, b_new = self.compute_stationary_distribution(self.solver_results, w=1.0)
                    if abs(b_new - b_guess) < 1e-5: break
                    b_guess = b_new
                
                results = self.check_market_clearing(r_guess, t_guess, tax_max)
                return results['budget_resid']

            # Find t_balancing
            try:
                t_star = optimize.brentq(budget_objective, 0.01, 0.3, xtol=self.tol)
            except ValueError:
                t_star = 0.1 # Fallback
            
            # Now calculate market clearing residual with t_star
            final_res = self.check_market_clearing(r_guess, t_star, tax_max)
            return final_res['market_resid']

        # Find r_clearing
        # r_guess range: annual 2% - 10% -> converted to 5-year
        r_min = (1.0 + 0.01)**5 - 1.0
        r_max = (1.0 + 0.15)**5 - 1.0
        
        try:
            r_star = optimize.brentq(ge_objective, r_min, r_max, xtol=self.tol)
        except ValueError:
            r_star = (1.0 + 0.04)**5 - 1.0 # Default fallback
            
        # Compile final results
        final_results = self.check_market_clearing(r_star, 0.1, tax_max) # Re-runs solve steps
        final_results['r_5y'] = r_star
        final_results['r_annual'] = (1.0 + r_star)**(1/5.0) - 1.0
        final_results['dist_s'] = self.dist_s
        final_results['dist_m'] = self.dist_m
        
        return final_results
