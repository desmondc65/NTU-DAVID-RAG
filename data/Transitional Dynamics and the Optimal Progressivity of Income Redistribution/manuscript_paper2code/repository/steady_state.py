## steady_state.py
import numpy as np
from numba import njit
from typing import Dict, Any, Tuple
from scipy.interpolate import interp1d

from config import EconomyConfig
from household import HouseholdSolver, HouseholdPolicy
from utils import tax_function, get_gini

class SteadyStateSolver:
    """
    Solver for the steady-state general equilibrium of the dynastic Aiyagari economy.
    
    This class handles:
    1. Finding the stationary distribution of assets and productivity.
    2. Solving for the equilibrium interest rate and tax scaling factor (lambda).
    3. Calculating aggregate statistics and inequality metrics.
    """

    def __init__(self, config: EconomyConfig, hh_solver: HouseholdSolver):
        self.config = config
        self.hh_solver = hh_solver
        # g_fixed is determined during the status quo (benchmark) solve
        self.g_fixed: float = None

    def compute_distribution(self, policy: HouseholdPolicy) -> np.ndarray:
        """
        Computes the stationary distribution Gamma(k, z) using the policy function k'.
        
        Args:
            policy: Converged HouseholdPolicy object.
            
        Returns:
            A (nk, nz) array representing the stationary mass distribution.
        """
        nk = self.config.k_size
        nz = len(self.config.z_states)
        k_grid = self.config.k_grid
        transition_matrix = self.config.transition_matrix
        
        # Initialize distribution (uniform guess)
        gamma = np.ones((nk, nz)) / (nk * nz)
        
        # Extract k_prime policy for JIT-friendly consumption
        k_prime = policy.k_prime
        
        it = 0
        diff = 1.0
        while it < self.config.max_iter and diff > self.config.tol_ss:
            gamma_new = _iterate_distribution(gamma, k_prime, k_grid, transition_matrix)
            diff = np.max(np.abs(gamma_new - gamma))
            gamma = gamma_new
            it += 1
            
        return gamma

    def check_market_clearing(self, r_guess: float, lambda_guess: float, tau: float) -> Tuple[float, float, Dict[str, Any]]:
        """
        Evaluates the economy given a guess for r and lambda.
        
        Returns:
            r_implied, lambda_implied, result_dict
        """
        # 1. Determine factor prices from r_guess
        # Gross marginal product of capital must equal r + delta
        capital_labor_ratio = ((r_guess + self.config.delta) / self.config.alpha) ** (1.0 / (self.config.alpha - 1.0))
        wage = (1.0 - self.config.alpha) * (capital_labor_ratio ** self.config.alpha)
        
        # 2. Solve Household Problem
        policy = self.hh_solver.solve_steady_state_policy(r_guess, wage, lambda_guess)
        
        # 3. Find Stationary Distribution
        gamma = self.compute_distribution(policy)
        
        # 4. Aggregation
        nk, nz = self.config.k_size, len(self.config.z_states)
        k_grid = self.config.k_grid
        z_states = self.config.z_states
        
        k_agg = np.sum(gamma * k_grid[:, np.newaxis])
        n_agg = 0.0
        for iz in range(nz):
            n_agg += np.sum(gamma[:, iz] * z_states[iz] * policy.hours[:, iz])
            
        y_prod = (k_agg ** self.config.alpha) * (n_agg ** (1.0 - self.config.alpha))
        
        # If g is not yet fixed, calculate it from the benchmark g/Y ratio
        if self.g_fixed is None:
            self.g_fixed = self.config.g_y_ratio * (y_prod - self.config.delta * k_agg)
        
        # 5. Market Clearing Residuals
        # Implied r from capital demand
        if n_agg > 1e-10:
            r_implied = self.config.alpha * (k_agg / n_agg) ** (self.config.alpha - 1.0) - self.config.delta
        else:
            r_implied = -self.config.delta
            
        # Implied lambda to balance budget: G = Sum (y - y_d)
        # Pre-tax income: y = zwh + rk. Note: y_prod - delta*K = wN + rK
        # Sum (y) = wN + rK. We need Sum (y - lambda*y^(1-tau)) = g_fixed
        y_pre_tax = np.zeros((nk, nz))
        y_after_tax_no_lambda = np.zeros((nk, nz))
        for iz in range(nz):
            y_pre_tax[:, iz] = z_states[iz] * wage * policy.hours[:, iz] + r_guess * k_grid
            # Handle potential non-positive income for the power function
            y_safe = np.maximum(y_pre_tax[:, iz], 1e-10)
            y_after_tax_no_lambda[:, iz] = y_safe ** (1.0 - tau)
            
        total_pre_tax = np.sum(gamma * y_pre_tax)
        total_y_pow = np.sum(gamma * y_after_tax_no_lambda)
        
        lambda_implied = (total_pre_tax - self.g_fixed) / total_y_pow
        
        # 6. Store results
        res = {
            "r": r_guess,
            "w": wage,
            "lambda": lambda_guess,
            "K": k_agg,
            "N": n_agg,
            "Y": y_prod - self.config.delta * k_agg, # Taxable Net Output
            "C": np.sum(gamma * policy.consumption),
            "Hours": np.sum(gamma * policy.hours),
            "policy": policy,
            "distribution": gamma,
            "y_pre_tax": y_pre_tax,
            "g": self.g_fixed
        }
        
        return r_implied, lambda_implied, res

    def find_equilibrium(self, tau: float) -> Dict[str, Any]:
        """
        Main nested loop for General Equilibrium (Steady State).
        
        Args:
            tau: Progressivity of the tax code.
            
        Returns:
            Dictionary with equilibrium aggregates and metrics.
        """
        # Initial guesses
        r_guess = self.config.get_period_r(self.config.r_annual_target)
        lambda_guess = 1.0
        
        self.config.update_tau(tau)
        
        # Nested loop
        for out_it in range(self.config.max_iter):
            # Inner loop: find r given lambda
            for in_it in range(self.config.max_iter):
                r_imp, _, res = self.check_market_clearing(r_guess, lambda_guess, tau)
                
                if abs(r_imp - r_guess) < self.config.tol_ge:
                    break
                
                # Update r with damping
                r_guess = (1.0 - self.config.damping_r) * r_guess + self.config.damping_r * r_imp
            
            # Now check lambda consistency
            _, lam_imp, res = self.check_market_clearing(r_guess, lambda_guess, tau)
            
            if abs(lam_imp - lambda_guess) < self.config.tol_ge:
                break
            
            # Update lambda with damping
            lambda_guess = (1.0 - self.config.damping_lambda) * lambda_guess + self.config.damping_lambda * lam_imp
        
        # Compute Ginis for the final state
        gamma_flat = res["distribution"].flatten()
        k_grid_rep = np.repeat(self.config.k_grid, len(self.config.z_states))
        y_flat = res["y_pre_tax"].flatten()
        c_flat = res["policy"].consumption.flatten()
        
        y_d_flat = np.array([tax_function(y, res["lambda"], tau) for y in y_flat])
        
        res["gini_wealth"] = get_gini(k_grid_rep, gamma_flat)
        res["gini_pre_tax"] = get_gini(y_flat, gamma_flat)
        res["gini_disposable"] = get_gini(y_d_flat, gamma_flat)
        res["gini_consumption"] = get_gini(c_flat, gamma_flat)
        res["r_annual"] = self.config.get_annual_r(res["r"])
        
        return res

@njit
def _iterate_distribution(gamma: np.ndarray, k_prime: np.ndarray, k_grid: np.ndarray, 
                         transition_matrix: np.ndarray) -> np.ndarray:
    """
    JIT-accelerated law of motion for the stationary distribution.
    Uses the lottery (linear interpolation) method for k'.
    """
    nk, nz = gamma.shape
    gamma_new = np.zeros_like(gamma)
    
    for ik in range(nk):
        for iz in range(nz):
            if gamma[ik, iz] <= 0:
                continue
            
            kp_val = k_prime[ik, iz]
            
            # Find indices for lottery on k grid
            # If kp_val is below min or above max, clip to boundaries
            if kp_val <= k_grid[0]:
                i_low = 0
                weight_high = 0.0
            elif kp_val >= k_grid[-1]:
                i_low = nk - 2
                weight_high = 1.0
            else:
                # Find bracket
                i_low = 0
                for j in range(nk - 1):
                    if k_grid[j] <= kp_val < k_grid[j+1]:
                        i_low = j
                        break
                weight_high = (kp_val - k_grid[i_low]) / (k_grid[i_low+1] - k_grid[i_low])
            
            # Distribute mass across z' and k_low/k_high
            mass = gamma[ik, iz]
            for iz_next in range(nz):
                prob = transition_matrix[iz, iz_next]
                gamma_new[i_low, iz_next] += (1.0 - weight_high) * prob * mass
                gamma_new[i_low + 1, iz_next] += weight_high * prob * mass
                
    return gamma_new

