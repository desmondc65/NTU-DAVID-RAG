## steady_state.py
import numpy as np
from typing import Dict, Any, List, Tuple
from scipy import optimize

from config import Config
from household_solver import HouseholdSolver
from economy_simulator import EconomySimulator
from social_security import SocialSecurity

class SteadyStateSolver:
    """
    Solves for the stationary recursive competitive equilibrium of the model.
    
    This class orchestrates the interaction between the household solver and the 
    economy simulator to find market-clearing factor prices (r, w) and balanced 
    government budgets (accidental bequests, OASI residual).
    """

    def __init__(self, 
                 config: Config, 
                 hs: HouseholdSolver, 
                 es: EconomySimulator, 
                 ss: SocialSecurity):
        """
        Initializes the steady-state solver with required components.

        Args:
            config (Config): Model configuration parameters.
            hs (HouseholdSolver): Solver for the household dynamic program.
            es (EconomySimulator): Simulator for the population distribution.
            ss (SocialSecurity): OASI system rules and calculations.
        """
        self.config = config
        self.hs = hs
        self.es = es
        self.ss = ss

    def find_equilibrium(self, 
                         guess_k_l: float = 6.0, 
                         guess_bequests: float = 0.05) -> Dict[str, Any]:
        """
        Finds the steady-state equilibrium using an iterative outer loop.

        Args:
            guess_k_l (float): Initial guess for the Capital/Labor ratio.
            guess_bequests (float): Initial guess for accidental bequests (q).

        Returns:
            dict: Equilibrium results containing prices, policy functions, 
                  and the population distribution.
        """
        # Initial guesses for K, L, q
        # Based on w=1 and K/Y=3 (approx K=15, L=2.5)
        k_guess = 15.0
        l_guess = 2.5
        q_guess = guess_bequests
        
        x0 = [k_guess, l_guess, q_guess]
        
        # We use a dampening fixed-point iteration approach for stability, 
        # or a root-solver for precision.
        current_x = np.array(x0)
        tol = self.config.tolerance
        max_iter = self.config.max_iter
        damp = self.config.damping_factor
        
        print("Starting steady-state equilibrium iteration...")
        
        for i in range(max_iter):
            residuals = self.check_market_clearing(current_x)
            
            # residuals are [K_new - K, L_new - L, q_new - q]
            k_new = current_x[0] + residuals[0]
            l_new = current_x[1] + residuals[1]
            q_new = current_x[2] + residuals[2]
            
            error = np.linalg.norm(residuals)
            
            if i % 5 == 0:
                print(f"Iteration {i}: Error = {error:.6f}, K={current_x[0]:.4f}, L={current_x[1]:.4f}, q={current_x[2]:.4f}")
            
            if error < tol:
                print(f"Convergence achieved at iteration {i}.")
                break
                
            # Update with dampening
            current_x[0] = (1.0 - damp) * current_x[0] + damp * k_new
            current_x[1] = (1.0 - damp) * current_x[1] + damp * l_new
            current_x[2] = (1.0 - damp) * current_x[2] + damp * q_new
        else:
            print("Warning: Steady-state solver did not converge within max iterations.")

        # Final equilibrium state
        prices, policy = self._get_prices_and_policy(current_x)
        
        # Calculate final budget metrics (OASI Residual T_RO)
        tax_metrics = self.es.calculate_tax_revenue(prices, psi_t=1.0, pol_type="baseline")
        t_ro = tax_metrics['t_p'] - tax_metrics['t_rss']
        
        return {
            "prices": prices,
            "policy_params": policy,
            "distribution": self.es.distribution.copy(),
            "policy_functions": self.hs.pol_func.copy(),
            "value_functions": self.hs.v_func.copy(),
            "k_l_ratio": current_x[0] / current_x[1],
            "oasi_residual": t_ro,
            "metrics": tax_metrics
        }

    def check_market_clearing(self, guess: List[float]) -> List[float]:
        """
        Executes one full iteration of the model and returns residuals for root-finding.

        Args:
            guess (list): Vector [K, L, q].

        Returns:
            list: Residuals [K_new - K, L_new - L, q_new - q].
        """
        k, l, q = guess
        
        # 1. Calculate Prices and Policy
        prices, policy = self._get_prices_and_policy(guess)
        
        # 2. Solve Household Dynamic Program
        # prices: {'r', 'w'}, policy: {'tr_ls', 'q', 'psi_t', 'policy_type'}
        self.hs.solve_backward_induction(prices, policy)
        
        # 3. Simulate Population Distribution
        # Use resulting policy functions (c, h1, h2, a_next)
        policy_funcs = {
            'c': self.hs.pol_func[0],
            'h1': self.hs.pol_func[1],
            'h2': self.hs.pol_func[2],
            'a_next': self.hs.pol_func[3]
        }
        self.es.simulate_forward(policy_funcs)
        
        # 4. Aggregation
        k_new, l_new = self.es.aggregate_k_l()
        
        # 5. Accidental Bequests Logic (Section 2.3)
        # q = AccidentalBequests / TotalWorkingAgeAdults
        tax_metrics = self.es.calculate_tax_revenue(prices, psi_t=1.0, pol_type="baseline")
        q_total = tax_metrics['q']
        
        # Population of age 21 adults is 2.0 (normalized). 
        # Total working age adults approx 2 * (IR - 21) if survival is 1.0.
        # However, we calculate it properly from the distribution.
        working_age_pop = 0.0
        for age_idx in range(self.config.age_retirement - self.config.age_start):
            m_mult = np.array([2.0, 1.0, 1.0])
            for m in range(3):
                working_age_pop += np.sum(self.es.distribution[age_idx, ..., m]) * m_mult[m]
        
        q_new = q_total / working_age_pop if working_age_pop > 0 else 0.0
        
        return [k_new - k, l_new - l, q_new - q]

    def _get_prices_and_policy(self, guess: List[float]) -> Tuple[Dict[str, float], Dict[str, Any]]:
        """
        Calculates r, w, and policy variables from the current state guess.
        
        Args:
            guess (list): [K, L, q].
            
        Returns:
            Tuple: (Prices Dict, Policy Dict).
        """
        k, l, q = guess
        
        # Firm FOCs (Section 2.2 and 3.3)
        theta = self.config.theta
        delta = self.config.delta
        A = self.config.A_target
        
        # r = theta * A * (K/L)^(theta-1) - delta
        # w = (1-theta) * A * (K/L)^theta
        k_l_ratio = max(k / l, 1e-6)
        r = theta * A * (k_l_ratio**(theta - 1.0)) - delta
        w = (1.0 - theta) * A * (k_l_ratio**theta)
        
        prices = {'r': r, 'w': w}
        
        # Policy: Baseline steady state assumes psi_t=1 and tr_ls=0 (or calibrated)
        # q is derived from bequests.
        policy = {
            'tr_ls': 0.0,
            'q': q,
            'psi_t': 1.0,
            'policy_type': 'baseline'
        }
        
        return prices, policy

    def calibrate_tfp(self, target_r: float = 0.05, target_w: float = 1.0) -> float:
        """
        Calculates the TFP scalar (A) to match target factor prices in Section 3.3.
        
        A = w / [(1-theta) * ( (r+delta)/(theta*A) )^(theta/(theta-1)) ]
        Simplified from Section 3.3: A = 0.8885.
        
        Returns:
            float: Calibrated TFP scalar A.
        """
        # Logic from Section 3.3
        theta = self.config.theta
        delta = self.config.delta
        ky_ratio = 3.0 # Target K/Y ratio
        
        # A = w / [ (1-theta) * (K/L)^theta ]
        # K/L = ( (r+delta) / (theta * A) )^(1/(theta-1))
        # From Y = K / 3.0 => A * K^theta * L^(1-theta) = K / 3.0
        # A * (K/L)^(theta-1) = 1/3.0
        # Given r + delta = theta * (Y/K) = theta / 3.0
        # 0.05 + 0.075 = 0.375 / 3.0 = 0.125 (Matches!)
        
        # w = (1-theta) * (Y/L) = (1-theta) * A * (K/L)^theta
        # Since Y/L = (Y/K) * (K/L) = (1/3) * (K/L)
        # K/L = w / ((1-theta) * (1/3))
        kl_target = target_w / ((1.0 - theta) * (1.0/3.0))
        
        # A = (1/3) / (kl_target**(theta-1))
        a_calibrated = (1.0/3.0) / (kl_target**(theta - 1.0))
        
        return a_calibrated

