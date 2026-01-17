## household.py
import numpy as np
from numba import njit
from typing import Tuple, Any
from scipy.interpolate import interp1d

from config import EconomyConfig
from utils import tax_function, marginal_net_income, marginal_utility_c, utility_c, utility_h

class HouseholdPolicy:
    """
    Data structure to store the household decision rules and value functions.
    
    Attributes:
        k_prime: Optimal capital for next period (k_size, z_size).
        hours: Optimal hours worked (k_size, z_size).
        consumption: Optimal consumption (k_size, z_size).
        value_function: Value function V(k, z) (k_size, z_size).
        v_marginal: Marginal value of capital dV/dk (k_size, z_size).
    """
    def __init__(self, k_size: int, z_size: int):
        self.k_prime = np.zeros((k_size, z_size))
        self.hours = np.zeros((k_size, z_size))
        self.consumption = np.zeros((k_size, z_size))
        self.value_function = np.zeros((k_size, z_size))
        self.v_marginal = np.zeros((k_size, z_size))


class HouseholdSolver:
    """
    Solver for the dynastic household's optimization problem.
    Implements the Endogenous Gridpoint Method (EGM) to find policy functions.
    """
    def __init__(self, config: EconomyConfig):
        self.config = config

    def solve_labor_supply(self, c_pow_sigma: float, z: float, r: float, w: float, 
                           lambda_val: float, k: float) -> float:
        """
        Solves for optimal hours h given consumption (via marginal utility c^-sigma), 
        wealth k, and prices. This is used specifically when the borrowing 
        constraint k' = 0 is binding.
        
        Equation: theta * h^epsilon = c^-sigma * zw * lambda * (1 - tau) * (zwh + rk)^-tau
        
        Args:
            c_pow_sigma: Current marginal utility of consumption (c^-sigma).
            z, r, w: Productivity, interest rate, and wage.
            lambda_val: Tax scaling parameter.
            k: Current capital level.
            
        Returns:
            Optimal hours h.
        """
        # Extract parameters from config
        tau = self.config.tau
        theta = self.config.theta
        epsilon = self.config.epsilon
        
        # Bisection to solve for h in [0, 1]
        h_low = 1e-8
        h_high = 1.0 - 1e-8
        
        def foc_residual(h_val: float) -> float:
            y = z * w * h_val + r * k
            y_safe = max(y, 1e-10)
            # LHS: Marginal disutility of labor
            lhs = theta * (h_val ** epsilon)
            # RHS: Marginal utility of consumption * marginal disposable income * marginal product
            # Note: budget constraint c = y_d(y) + k - k' (with k'=0 here)
            y_d = tax_function(y, lambda_val, tau)
            c = max(y_d + k, 1e-10)
            rhs = marginal_utility_c(c, self.config.sigma) * marginal_net_income(y, lambda_val, tau) * z * w
            return lhs - rhs

        # Simple bisection
        if foc_residual(h_low) > 0: return h_low
        if foc_residual(h_high) < 0: return h_high
        
        for _ in range(100):
            h_mid = 0.5 * (h_low + h_high)
            if foc_residual(h_mid) > 0:
                h_high = h_mid
            else:
                h_low = h_mid
        return 0.5 * (h_low + h_high)

    def solve_backward_step(self, r_t: float, w_t: float, lambda_t: float, 
                            next_v_marginal: np.ndarray) -> HouseholdPolicy:
        """
        Performs one step of the Endogenous Gridpoint Method (EGM).
        
        Args:
            r_t, w_t, lambda_t: Prices and tax parameter for the current period.
            next_v_marginal: Marginal value function dV/dk for the next period (k_size, z_size).
            
        Returns:
            HouseholdPolicy for the current period.
        """
        # Grid sizes
        nk = self.config.k_size
        nz = len(self.config.z_states)
        k_grid = self.config.k_grid
        z_states = self.config.z_states
        
        # 1. Expected Marginal Utility of future wealth
        # E_V_k = E [ dV/dk (k', z') ]
        e_v_k = next_v_marginal @ self.config.transition_matrix.T  # Shape (nk, nz)
        
        # 2. Consumption today from Euler Equation
        # c^-sigma = beta * E[V_k]
        c_endo = (self.config.beta * e_v_k) ** (-1.0 / self.config.sigma)
        
        # 3. Solve for h and y using EGM for each (k', z)
        # For each k' on the fixed grid, we find the income y and hours h that satisfy FOCs
        # Then we deduce the beginning-of-period capital k_endo.
        k_endo_grid = np.zeros((nk, nz))
        h_endo_grid = np.zeros((nk, nz))
        y_endo_grid = np.zeros((nk, nz))
        
        for iz in range(nz):
            z = z_states[iz]
            for ik in range(nk):
                kp = k_grid[ik]
                c = c_endo[ik, iz]
                
                # We need to solve: 
                # f(y) = lambda * y^(1-tau) + (1/r)*(y - zwh(y, c)) - c - k' = 0
                # where h(y, c) = [ (c^-sigma * lambda * (1-tau) * y^-tau * zw) / theta ]^(1/epsilon)
                y_star = _solve_y_egm(c, kp, z, r_t, w_t, lambda_t, self.config.tau, 
                                     self.config.sigma, self.config.theta, self.config.epsilon)
                
                # Recover h and k
                m_net = marginal_net_income(y_star, lambda_t, self.config.tau)
                h_star = ((marginal_utility_c(c, self.config.sigma) * m_net * z * w_t) / self.config.theta) ** (1.0 / self.config.epsilon)
                h_star = min(max(h_star, 1e-8), 1.0 - 1e-8)
                
                # Budget: c + k' = y_d + k  => k = c + k' - y_d
                y_d = tax_function(y_star, lambda_t, self.config.tau)
                k_endo = c + kp - y_d
                
                k_endo_grid[ik, iz] = k_endo
                h_endo_grid[ik, iz] = h_star
                y_endo_grid[ik, iz] = y_star

        # 4. Interpolate policies back to fixed k_grid
        policy = HouseholdPolicy(nk, nz)
        for iz in range(nz):
            z = z_states[iz]
            
            # Interpolate k_prime
            # We have (k_endo -> k_prime_fixed). We want (k_fixed -> k_prime).
            interp_kp = interp1d(k_endo_grid[:, iz], k_grid, bounds_error=False, fill_value="extrapolate")
            policy.k_prime[:, iz] = np.maximum(interp_kp(k_grid), 0.0)
            
            # Interpolate hours
            interp_h = interp1d(k_endo_grid[:, iz], h_endo_grid[:, iz], bounds_error=False, fill_value="extrapolate")
            policy.hours[:, iz] = np.clip(interp_h(k_grid), 1e-8, 1.0 - 1e-8)
            
            # 5. Handle constrained agents (k' = 0)
            # If k_fixed < min(k_endo), the borrowing constraint is binding.
            k_min_endo = k_endo_grid[0, iz]
            constrained_indices = k_grid < k_min_endo
            if np.any(constrained_indices):
                for idx in np.where(constrained_indices)[0]:
                    k_val = k_grid[idx]
                    policy.k_prime[idx, iz] = 0.0
                    # Solve for h given k and k'=0
                    h_c = self.solve_labor_supply(0.0, z, r_t, w_t, lambda_t, k_val)
                    policy.hours[idx, iz] = h_c
            
            # 6. Calculate Consumption and Marginal Value for the fixed grid
            y_final = z * w_t * policy.hours[:, iz] + r_t * k_grid
            y_d_final = np.array([tax_function(val, lambda_t, self.config.tau) for val in y_final])
            policy.consumption[:, iz] = y_d_final + k_grid - policy.k_prime[:, iz]
            
            # Marginal Value Function: V_k = c^-sigma * (1 + r * dy_d/dy)
            # Eq from envelope condition: dV/dk = c^-sigma * (1 + r * lambda * (1-tau) * y^-tau)
            m_net_final = np.array([marginal_net_income(val, lambda_t, self.config.tau) for val in y_final])
            policy.v_marginal[:, iz] = (policy.consumption[:, iz] ** (-self.config.sigma)) * (1.0 + r_t * m_net_final)

        return policy

    def solve_steady_state_policy(self, r: float, w: float, lambda_val: float) -> HouseholdPolicy:
        """
        Iterates the backward step until the marginal value function converges.
        
        Args:
            r, w, lambda_val: Prices and tax parameter.
            
        Returns:
            Converged HouseholdPolicy.
        """
        nk = self.config.k_size
        nz = len(self.config.z_states)
        
        # Initial guess for marginal value function
        # A simple guess: V_k = (r*k + w*z)^-sigma * (1+r)
        v_marginal = np.zeros((nk, nz))
        for iz in range(nz):
            y_guess = self.config.z_states[iz] * w * 0.5 + r * self.config.k_grid
            v_marginal[:, iz] = (y_guess ** (-self.config.sigma)) * (1.0 + r)

        it = 0
        diff = 1.0
        while it < self.config.max_iter and diff > self.config.tol_ss:
            new_policy = self.solve_backward_step(r, w, lambda_val, v_marginal)
            diff = np.max(np.abs(new_policy.v_marginal - v_marginal))
            v_marginal = new_policy.v_marginal
            it += 1
            
        # Optional: Compute the actual Value Function V(k, z) once policies converged
        # Standard VFI step for one iteration to get V levels if needed for welfare
        # For simplicity, we can also compute it by iterating V = u + beta * E[V']
        v_func = np.zeros((nk, nz))
        for _ in range(200): # Sufficient for welfare analysis
            ev = v_func @ self.config.transition_matrix.T
            for iz in range(nz):
                c = new_policy.consumption[:, iz]
                h = new_policy.hours[:, iz]
                u = utility_c(c, self.config.sigma) - utility_h(h, self.config.theta, self.config.epsilon)
                
                # Interpolate E[V'] at k_prime
                interp_ev = interp1d(self.config.k_grid, ev[:, iz], bounds_error=False, fill_value="extrapolate")
                v_func[:, iz] = u + self.config.beta * interp_ev(new_policy.k_prime[:, iz])
        
        new_policy.value_function = v_func
        return new_policy


@njit
def _solve_y_egm(c: float, kp: float, z: float, r: float, w: float, 
                 lambda_val: float, tau: float, sigma: float, 
                 theta: float, epsilon: float) -> float:
    """
    Internal JIT-compiled helper to solve for income y in the EGM step.
    Solves f(y) = y_d(y) + (1/r)(y - zw*h(y, c)) - c - k' = 0
    """
    # Define search range for y. Minimum y occurs at h=0.
    y_min = 1e-8
    y_max = 200.0 # High upper bound
    
    def resid(y_val: float) -> float:
        y_safe = max(y_val, 1e-10)
        # h(y, c) from labor FOC
        m_net = lambda_val * (1.0 - tau) * (y_safe ** (-tau))
        c_inv = c ** (-sigma)
        h = ((c_inv * m_net * z * w) / theta) ** (1.0 / epsilon)
        h = min(max(h, 1e-10), 1.0 - 1e-10)
        
        y_d = lambda_val * (y_safe ** (1.0 - tau))
        # Budget solved for current k: k = c + k' - y_d
        k_implied = c + kp - y_d
        # Relationship y = zwh + rk
        y_implied = z * w * h + r * k_implied
        return y_val - y_implied

    # Bisection
    y_low, y_high = y_min, y_max
    if resid(y_low) > 0: return y_low
    if resid(y_high) < 0: return y_high
    
    for _ in range(100):
        y_mid = 0.5 * (y_low + y_high)
        if resid(y_mid) > 0:
            y_high = y_mid
        else:
            y_low = y_mid
    return 0.5 * (y_low + y_high)

