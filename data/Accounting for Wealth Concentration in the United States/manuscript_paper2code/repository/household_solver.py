## household_solver.py
import numpy as np
from scipy import interpolate, optimize
from typing import Dict, Any, Tuple
import utils

class HouseholdProblem:
    """
    The computational core for solving the household's lifecycle problem.
    Uses the Endogenous Grid Method (EGM) for consumption-savings and 
    a root-finding approach for non-linear labor supply choice under 
    progressive taxation.
    """

    def __init__(self, params: Dict[str, Any]):
        """
        Initializes the household solver with model parameters and grids.
        
        Args:
            params: Dictionary containing 'k_grid', 'z_grid', 'kappa_grid', 
                    'pi_z', 'pi_kappa_ord', 'pi_kappa_extra', etc.
        """
        self.params = params
        self.k_grid = params['k_grid']
        self.z_grid = params['z_grid']
        self.kappa_grid = params['kappa_grid']
        
        self.n_k = len(self.k_grid)
        self.n_z = len(self.z_grid)
        self.n_kappa = len(self.kappa_grid)
        self.total_periods = params['total_periods']
        self.retirement_period = params['retirement_period']

        # Transition matrices
        self.pi_z = params['pi_z']
        self.pi_kappa_ord = params['pi_kappa_ord']
        self.pi_kappa_extra = params['pi_kappa_extra']

        # Pre-calculated survival probabilities
        self.surv_probs = params['survival_probs']
        
        # Deterministic age-efficiency profile (example PSID-like)
        # Replicated logic from paper: "deterministic age profile common to all workers"
        self.epsilon = np.exp(0.05 * np.arange(self.total_periods) - 0.001 * np.arange(self.total_periods)**2)
        
        # Tax parameters (gamma0, gamma1) for log-linear system
        # These would normally be updated by the equilibrium solver
        self.tax_params = (params.get('tax_gamma0', -0.2), params.get('tax_gamma1', 0.8))

    def solve_lifecycle(self, w: float, r: float, tr: float) -> Dict[str, np.ndarray]:
        """
        Solves the lifecycle problem using backward induction.
        
        Args:
            w: Market wage rate.
            r: Base market interest rate.
            tr: Government transfer (lump-sum).
            
        Returns:
            Dictionary with policy functions: c_policy, k_prime_policy, h_policy.
        """
        # Initialize containers for policy functions (age, k, z, kappa)
        shape = (self.total_periods, self.n_k, self.n_z, self.n_kappa)
        c_policy = np.zeros(shape)
        k_prime_policy = np.zeros(shape)
        h_policy = np.zeros(shape)
        v_prime = np.zeros((self.n_k, self.n_z, self.n_kappa))

        # Backward Induction
        for j in range(self.total_periods - 1, -1, -1):
            age_idx = j + 1 # 1-based indexing for logic consistency
            
            if age_idx == self.total_periods:
                # Terminal Period: Consume everything, k' = 0
                c_policy[j, :, :, :], h_policy[j, :, :, :], v_prime = self._solve_terminal_period(w, r, tr, j)
                k_prime_policy[j, :, :, :] = 0.0
            else:
                # EGM Step for periods T-1 down to 1
                c, k_p, h, vp = self.egm_step(age_idx, v_prime, w, r, tr)
                c_policy[j, ...] = c
                k_prime_policy[j, ...] = k_p
                h_policy[j, ...] = h
                v_prime = vp

        return {
            'c_policy': c_policy,
            'k_prime_policy': k_prime_policy,
            'h_policy': h_policy
        }

    def _get_taxable_income(self, labor_inc: float, cap_inc: float) -> float:
        """
        Determines personal taxable income considering corporate tax.
        y_taxable = y_labor + (1 - tau_c) * y_capital
        """
        tau_c = self.params.get('tau_c', 0.236)
        return labor_inc + (1.0 - tau_c) * cap_inc

    def _solve_terminal_period(self, w: float, r: float, tr: float, j_idx: int) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """Households consume all remaining wealth in the last period of life."""
        c_res = np.zeros((self.n_k, self.n_z, self.n_kappa))
        h_res = np.zeros((self.n_k, self.n_z, self.n_kappa))
        v_prime = np.zeros((self.n_k, self.n_z, self.n_kappa))
        
        tau_s = self.params.get('tau_s', 0.05)
        sigma_c = self.params.get('sigma_c', 1.5)
        
        for iz in range(self.n_z):
            for ik in range(self.n_kappa):
                # Retirees don't work (age 16 > 10)
                labor_inc = self._get_pension(self.z_grid[iz])
                cap_inc = r * self.kappa_grid[ik] * self.k_grid
                
                for i_asset in range(self.n_k):
                    y_tax = self._get_taxable_income(labor_inc, cap_inc[i_asset])
                    y_disp = utils.compute_disposable_income(y_tax, self.tax_params, self.params['tau_max'])
                    
                    # Budget: (1+tau_s)c + k' = y_disp + k + tr. In T, k'=0.
                    c = (y_disp + self.k_grid[i_asset] + tr) / (1.0 + tau_s)
                    c_res[i_asset, iz, ik] = c
                    h_res[i_asset, iz, ik] = 0.0
                    # V'(k) = u'(c) / (1 + tau_s) * (1 + net_return)
                    # For terminal step, we just need the marginal utility component
                    v_prime[i_asset, iz, ik] = (c ** -sigma_c) / (1.0 + tau_s)
                    
        return c_res, h_res, v_prime

    def _get_pension(self, z_last: float) -> float:
        """Calculates pension based on last period's productivity."""
        # Simple placeholder for SSA replacement rules
        return 0.4 * z_last 

    def labor_supply_choice(self, c: float, z: float, age_idx: int, w: float) -> float:
        """
        Solves the intra-temporal FOC for labor supply h.
        
        Args:
            c: Consumption.
            z: Productivity state.
            age_idx: Model period.
            w: Market wage.
        """
        if age_idx >= self.retirement_period:
            return 0.0
        
        wage_eff = w * z * self.epsilon[age_idx - 1]
        return utils.solve_labor_supply(c, wage_eff, self.params, self.tax_params)

    def egm_step(self, age_idx: int, next_v_prime: np.ndarray, w: float, r: float, tr: float) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
        """
        Performs one backward step using the Endogenous Grid Method.
        """
        c_res = np.zeros((self.n_k, self.n_z, self.n_kappa))
        k_prime_res = np.zeros((self.n_k, self.n_z, self.n_kappa))
        h_res = np.zeros((self.n_k, self.n_z, self.n_kappa))
        curr_v_prime = np.zeros((self.n_k, self.n_z, self.n_kappa))

        beta = self.params['beta']
        sigma_c = self.params['sigma_c']
        tau_s = self.params['tau_s']
        s_j = self.surv_probs[age_idx - 1]
        
        # Grid of savings A (future assets)
        a_grid = self.k_grid 
        
        for iz in range(self.n_z):
            # Select correct return transition matrix based on productivity
            pi_kappa = self.pi_kappa_extra if iz >= 6 else self.pi_kappa_ord
            
            for ik in range(self.n_kappa):
                # 1. Expected Marginal Utility (EMU)
                # EMU = beta * [ (1-sj)*phi'(A) + sj * E[V'(A + Phi')] ]
                # We simplify stochastic bequests Phi' to its expected value for EGM stability
                exp_bequest = 0.0 # Standard OLG simplification or integrated via convolution
                
                # Pre-calculate E[V'(A)] over z' and kappa'
                # Transition probabilities: Prob(z', kappa' | z, kappa)
                emu_a = np.zeros(self.n_k)
                for iz_next in range(self.n_z):
                    prob_z = self.pi_z[iz, iz_next]
                    if prob_z <= 0: continue
                    for ik_next in range(self.n_kappa):
                        prob_k = pi_kappa[ik, ik_next]
                        if prob_k <= 0: continue
                        
                        # Interpolate v_prime onto (A + Phi')
                        # Here Phi' is assumed 0 for the point-wise EGM, 
                        # distributed bequests handled in simulation.
                        emu_a += prob_z * prob_k * next_v_prime[:, iz_next, ik_next]

                # Warm-glow bequest marginal utility
                mu_bequest = utils.get_bequest_marginal_utility(
                    a_grid, self.params['phi1'], self.params['phi2'], self.params['sigma_b']
                )

                expected_mu = beta * (s_j * emu_a + (1.0 - s_j) * mu_bequest)
                
                # 2. Consumption from Euler Equation
                # u'(c) = (1 + tau_s) * Expected_MU
                c_star = (expected_mu * (1.0 + tau_s)) ** (-1.0 / sigma_c)
                
                # 3. Labor Supply
                h_star = np.array([self.labor_supply_choice(c, self.z_grid[iz], age_idx, w) for c in c_star])
                
                # 4. Endogenous current assets k
                # (1+tau_s)c + A = y_disp(h, k) + k + tr
                # This requires solving for k because y_disp depends on k via capital income
                k_implied = np.zeros(self.n_k)
                for i_a in range(self.n_k):
                    labor_inc = w * self.z_grid[iz] * self.epsilon[age_idx - 1] * h_star[i_a] if age_idx < self.retirement_period else self._get_pension(self.z_grid[iz])
                    
                    def budget_residual(k_guess):
                        cap_inc = r * self.kappa_grid[ik] * k_guess
                        y_tax = self._get_taxable_income(labor_inc, cap_inc)
                        y_disp = utils.compute_disposable_income(y_tax, self.tax_params, self.params['tau_max'])
                        return (1.0 + tau_s) * c_star[i_a] + a_grid[i_a] - y_disp - k_guess - tr

                    # Solve for k_implied
                    try:
                        k_implied[i_a] = optimize.brentq(budget_residual, -tr, 1e6)
                    except ValueError:
                        k_implied[i_a] = 1e6 # Fallback
                
                # 5. Map back to fixed k_grid
                # Handle borrowing constraint (k_grid < min(k_implied))
                # Note: EGM gives us points (k_implied, a_grid). We want (k_grid, k_prime).
                valid = np.argsort(k_implied)
                k_prime_res[:, iz, ik] = np.interp(self.k_grid, k_implied[valid], a_grid[valid], left=0.0)
                c_res[:, iz, ik] = np.interp(self.k_grid, k_implied[valid], c_star[valid])
                h_res[:, iz, ik] = np.interp(self.k_grid, k_implied[valid], h_star[valid])
                
                # Re-solve for constrained households (k' = 0)
                constrained = self.k_grid < k_implied[valid][0]
                if np.any(constrained):
                    for i_const in np.where(constrained)[0]:
                        k_val = self.k_grid[i_const]
                        # Solve (1+tau_s)c = y_disp(c, k) + k + tr with k'=0
                        def cons_res(c_guess):
                            h_g = self.labor_supply_choice(c_guess, self.z_grid[iz], age_idx, w)
                            l_inc = w * self.z_grid[iz] * self.epsilon[age_idx - 1] * h_g if age_idx < self.retirement_period else self._get_pension(self.z_grid[iz])
                            y_tax = self._get_taxable_income(l_inc, r * self.kappa_grid[ik] * k_val)
                            y_disp = utils.compute_disposable_income(y_tax, self.tax_params, self.params['tau_max'])
                            return (1.0 + tau_s) * c_guess - y_disp - k_val - tr
                        
                        c_fixed = optimize.brentq(cons_res, 1e-6, 1e4)
                        c_res[i_const, iz, ik] = c_fixed
                        k_prime_res[i_const, iz, ik] = 0.0
                        h_res[i_const, iz, ik] = self.labor_supply_choice(c_fixed, self.z_grid[iz], age_idx, w)

                # 6. Update current V'
                curr_v_prime[:, iz, ik] = (c_res[:, iz, ik] ** -sigma_c) / (1.0 + tau_s)

        return c_res, k_prime_res, h_res, curr_v_prime

