## transition.py
import numpy as np
from numba import njit
from typing import Dict, List, Any, Tuple
from scipy.interpolate import interp1d

from config import EconomyConfig
from household import HouseholdSolver, HouseholdPolicy
from utils import tax_function, utility_c, utility_h

class TransitionSolver:
    """
    Solver for the non-linear transition path from the status quo steady state 
    to a new tax regime in a dynastic Aiyagari economy.

    Attributes:
        config: Central configuration object.
        hh_solver: Household decision rule solver.
        ss_start: Results from the initial steady state (U.S. status quo).
        ss_end: Results from the final target steady state.
    """

    def __init__(self, config: EconomyConfig, hh_solver: HouseholdSolver, 
                 ss_start: Dict[str, Any], ss_end: Dict[str, Any]):
        self.config = config
        self.hh_solver = hh_solver
        self.ss_start = ss_start
        self.ss_end = ss_end
        # The government expenditure level g is fixed from the benchmark status quo
        self.g_fixed: float = ss_start["g"]

    def solve_path(self, t_periods: int = 50, beta_g: float = 0.0) -> Dict[str, Any]:
        """
        Computes the transition path of prices and policies.
        
        Args:
            t_periods: Length of the transition path (T).
            beta_g: Discount factor used by the policy maker for future generations.
            
        Returns:
            Dictionary containing the sequences of aggregates, prices, and welfare metrics.
        """
        # 1. Initialize path guesses for r and lambda
        # Start with a guess that moves towards the final steady state values
        r_path = np.full(t_periods, self.ss_end["r"])
        lambda_path = np.full(t_periods, self.ss_end["lambda"])
        
        # Grid sizes
        nk = self.config.k_size
        nz = len(self.config.z_states)
        
        # Store results
        path_data = {
            "r": r_path,
            "lambda": lambda_path,
            "K": np.zeros(t_periods),
            "N": np.zeros(t_periods),
            "Y": np.zeros(t_periods),
            "C": np.zeros(t_periods),
            "Hours": np.zeros(t_periods),
            "distributions": [],
            "policies": []
        }

        # Iteration parameters
        it = 0
        diff = 1.0
        
        while it < self.config.max_iter and diff > self.config.tol_ge:
            # Step A: Backward Induction to find time-varying policies
            # We move from t = T down to t = 1.
            # Terminal condition: V_marginal at T+1 is the SS2 marginal value function.
            policies: List[HouseholdPolicy] = [None] * t_periods
            v_marginal_next = self.ss_end["policy"].v_marginal
            
            for t in reversed(range(t_periods)):
                # Calculate wage for period t based on current r_path guess
                # capital_labor_ratio = ((r + delta)/alpha)^(1/(alpha-1))
                kl_ratio_t = ((r_path[t] + self.config.delta) / self.config.alpha) ** (1.0 / (self.config.alpha - 1.0))
                w_t = (1.0 - self.config.alpha) * (kl_ratio_t ** self.config.alpha)
                
                # Solve policy for period t
                policy_t = self.hh_solver.solve_backward_step(r_path[t], w_t, lambda_path[t], v_marginal_next)
                policies[t] = policy_t
                v_marginal_next = policy_t.v_marginal
            
            # Step B: Forward Simulation to update distribution and aggregates
            # Initial distribution is from the status quo steady state (predetermined wealth)
            gamma_t = self.ss_start["distribution"]
            
            r_implied = np.zeros(t_periods)
            lambda_implied = np.zeros(t_periods)
            
            temp_ks = np.zeros(t_periods)
            temp_ns = np.zeros(t_periods)
            temp_cs = np.zeros(t_periods)
            temp_hs = np.zeros(t_periods)
            new_distributions = []

            for t in range(t_periods):
                new_distributions.append(gamma_t)
                policy_t = policies[t]
                
                # 1. Compute aggregates for current period t
                k_agg_t = np.sum(gamma_t * self.config.k_grid[:, np.newaxis])
                n_agg_t = 0.0
                for iz in range(nz):
                    n_agg_t += np.sum(gamma_t[:, iz] * self.config.z_states[iz] * policy_t.hours[:, iz])
                
                temp_ks[t] = k_agg_t
                temp_ns[t] = n_agg_t
                temp_cs[t] = np.sum(gamma_t * policy_t.consumption)
                temp_hs[t] = np.sum(gamma_t * policy_t.hours)
                
                # 2. Implied Prices and Taxes
                # r_implied from MPK
                r_imp_t = self.config.alpha * (k_agg_t / n_agg_t) ** (self.config.alpha - 1.0) - self.config.delta
                r_implied[t] = r_imp_t
                
                # Wage for period t (consistent with r_imp_t)
                w_imp_t = (1.0 - self.config.alpha) * ((k_agg_t / n_agg_t) ** self.config.alpha)
                
                # lambda_implied to balance budget: G = Sum (y_pre - y_disp)
                # y_pre = zwh + rk
                y_pre_tax_t = np.zeros((nk, nz))
                y_after_tax_no_lambda_t = np.zeros((nk, nz))
                for iz in range(nz):
                    y_pre_tax_t[:, iz] = self.config.z_states[iz] * w_imp_t * policy_t.hours[:, iz] + r_path[t] * self.config.k_grid
                    y_safe = np.maximum(y_pre_tax_t[:, iz], 1e-10)
                    y_after_tax_no_lambda_t[:, iz] = y_safe ** (1.0 - self.config.tau)
                
                total_pre_tax = np.sum(gamma_t * y_pre_tax_t)
                total_y_pow = np.sum(gamma_t * y_after_tax_no_lambda_t)
                lambda_implied[t] = (total_pre_tax - self.g_fixed) / total_y_pow
                
                # 3. Update distribution for period t+1
                gamma_t = _iterate_transition_distribution(
                    gamma_t, policy_t.k_prime, self.config.k_grid, self.config.transition_matrix
                )

            # Step C: Convergence check and path update
            diff_r = np.max(np.abs(r_implied - r_path))
            diff_lam = np.max(np.abs(lambda_implied - lambda_path))
            diff = max(diff_r, diff_lam)
            
            # Damped update of paths
            r_path = (1.0 - self.config.damping_r) * r_path + self.config.damping_r * r_implied
            lambda_path = (1.0 - self.config.damping_lambda) * lambda_path + self.config.damping_lambda * lambda_implied
            
            it += 1
            
            # Store data
            path_data["K"] = temp_ks
            path_data["N"] = temp_ns
            path_data["C"] = temp_cs
            path_data["Hours"] = temp_hs
            path_data["distributions"] = new_distributions
            path_data["policies"] = policies
            path_data["r"] = r_path
            path_data["lambda"] = lambda_path

        # Finally, calculate social welfare including future generations
        path_data["welfare"] = self._calculate_social_welfare(path_data, beta_g)
        
        return path_data

    def simulate_forward(self, path_policies: List[HouseholdPolicy]) -> List[np.ndarray]:
        """
        Auxiliary method to simulate the distribution forward given a fixed set of policies.
        """
        distributions = [self.ss_start["distribution"]]
        gamma = self.ss_start["distribution"]
        for policy in path_policies[:-1]:
            gamma = _iterate_transition_distribution(
                gamma, policy.k_prime, self.config.k_grid, self.config.transition_matrix
            )
            distributions.append(gamma)
        return distributions

    def _calculate_social_welfare(self, path_data: Dict[str, Any], beta_g: float) -> float:
        """
        Calculates social welfare according to Equation (6).
        W = AverageV_alive_at_0 + mu * Sum_{t=1..T} beta_g^t * AverageV_newborns_at_t
        """
        t_periods = len(path_data["policies"])
        nk, nz = self.config.k_size, len(self.config.z_states)
        
        # 1. Compute Value Function levels along the path: V_t = u_t + beta * E[V_{t+1}]
        v_path = [None] * (t_periods + 1)
        v_path[t_periods] = self.ss_end["policy"].value_function
        
        for t in reversed(range(t_periods)):
            policy = path_data["policies"][t]
            ev_next = v_path[t+1] @ self.config.transition_matrix.T
            
            v_t = np.zeros((nk, nz))
            for iz in range(nz):
                c = policy.consumption[:, iz]
                h = policy.hours[:, iz]
                u = utility_c(c, self.config.sigma) - utility_h(h, self.config.theta, self.config.epsilon)
                
                # Interpolate next period's expected value at chosen k_prime
                interp_ev = interp1d(self.config.k_grid, ev_next[:, iz], 
                                     bounds_error=False, fill_value="extrapolate")
                v_t[:, iz] = u + self.config.beta * interp_ev(policy.k_prime[:, iz])
            v_path[t] = v_t

        # 2. Integrate V_0 against initial distribution (Current generation)
        welfare_alive = np.sum(path_data["distributions"][0] * v_path[0])
        
        # 3. Integrate V_t against newborns distribution (Future generations)
        # In this model, the measure of newborns is mu. 
        # Newborns inherit k and their z is determined by matrix D.
        # Aggregate welfare of newborns at t is mu * \int V_t dGamma_newborn_t
        welfare_future = 0.0
        for t in range(1, t_periods):
            # Distribution of parents in period t-1
            gamma_parents = path_data["distributions"][t-1]
            policy_parents = path_data["policies"][t-1]
            
            # Distribution of children at beginning of t:
            # They inherit k' from parents and z is transitioned via D
            gamma_newborns_t = _iterate_newborn_distribution(
                gamma_parents, policy_parents.k_prime, self.config.k_grid, self.config.D_matrix
            )
            
            avg_v_newborn = np.sum(gamma_newborns_t * v_path[t])
            welfare_future += (beta_g ** t) * avg_v_newborn
            
        return welfare_alive + self.config.mu * welfare_future


@njit
def _iterate_transition_distribution(gamma: np.ndarray, k_prime: np.ndarray, 
                                     k_grid: np.ndarray, transition_matrix: np.ndarray) -> np.ndarray:
    """
    Time-step for distribution evolution using the linear interpolation (lottery) method.
    Reused from steady_state.py logic for consistency.
    """
    nk, nz = gamma.shape
    gamma_new = np.zeros_like(gamma)
    
    for ik in range(nk):
        for iz in range(nz):
            if gamma[ik, iz] <= 0:
                continue
            
            kp_val = k_prime[ik, iz]
            
            # Lottery on the capital grid
            if kp_val <= k_grid[0]:
                i_low = 0
                weight_high = 0.0
            elif kp_val >= k_grid[-1]:
                i_low = nk - 2
                weight_high = 1.0
            else:
                i_low = 0
                for j in range(nk - 1):
                    if k_grid[j] <= kp_val < k_grid[j+1]:
                        i_low = j
                        break
                weight_high = (kp_val - k_grid[i_low]) / (k_grid[i_low+1] - k_grid[i_low])
            
            mass = gamma[ik, iz]
            for iz_next in range(nz):
                prob = transition_matrix[iz, iz_next]
                gamma_new[i_low, iz_next] += (1.0 - weight_high) * prob * mass
                gamma_new[i_low + 1, iz_next] += weight_high * prob * mass
                
    return gamma_new

@njit
def _iterate_newborn_distribution(gamma_parents: np.ndarray, k_prime_parents: np.ndarray, 
                                  k_grid: np.ndarray, d_matrix: np.ndarray) -> np.ndarray:
    """
    Computes the distribution of newborns specifically.
    Newborns inherit k' from their parents, and transition into z' via the D_matrix.
    """
    nk, nz = gamma_parents.shape
    gamma_newborn = np.zeros_like(gamma_parents)
    
    for ik in range(nk):
        for iz in range(nz):
            if gamma_parents[ik, iz] <= 0:
                continue
                
            kp_val = k_prime_parents[ik, iz]
            
            # Find lottery indices
            if kp_val <= k_grid[0]:
                i_low = 0
                weight_high = 0.0
            elif kp_val >= k_grid[-1]:
                i_low = nk - 2
                weight_high = 1.0
            else:
                i_low = 0
                for j in range(nk - 1):
                    if k_grid[j] <= kp_val < k_grid[j+1]:
                        i_low = j
                        break
                weight_high = (kp_val - k_grid[i_low]) / (k_grid[i_low+1] - k_grid[i_low])
            
            mass = gamma_parents[ik, iz]
            for iz_next in range(nz):
                # Using D_matrix for newborn productivity draw
                prob = d_matrix[iz, iz_next]
                gamma_newborn[i_low, iz_next] += (1.0 - weight_high) * prob * mass
                gamma_newborn[i_low + 1, iz_next] += weight_high * prob * mass
                
    return gamma_newborn

