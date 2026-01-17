## discretization.py
import numpy as np
from typing import Tuple, Dict
from config import Config

class Discretizer:
    """
    Handles the discretization of the state space for the OLG model.
    
    This includes creating grids for wealth and historical earnings, 
    implementing the Rouwenhorst method for AR(1) wage shocks, and 
    calculating transition matrices for shocks and demographics.
    """

    def __init__(self, config: Config):
        """
        Initializes the Discretizer with model configuration.

        Args:
            config (Config): Configuration object containing model parameters.
        """
        self.config = config

    def rouwenhorst(self, rho: float, sigma: float, n: int) -> Tuple[np.ndarray, np.ndarray]:
        """
        Discretizes an AR(1) process using the Rouwenhorst (1995) method.
        
        The AR(1) process is: ln(z_t) = rho * ln(z_{t-1}) + epsilon_t, where epsilon ~ N(0, sigma^2).
        
        Args:
            rho (float): Persistence parameter.
            sigma (float): Standard deviation of the innovation.
            n (int): Number of nodes in the grid.
            
        Returns:
            nodes (np.ndarray): The discrete nodes (in log levels).
            P (np.ndarray): The n x n transition probability matrix.
        """
        if n == 1:
            return np.array([0.0]), np.array([[1.0]])

        # 1. Define nodes
        # Standard deviation of the stationary distribution of the AR(1)
        sigma_z = sigma / np.sqrt(1.0 - rho**2)
        # Boundary for the nodes
        psi = sigma_z * np.sqrt(n - 1)
        nodes = np.linspace(-psi, psi, n)

        # 2. Construct transition matrix P recursively
        p = (1.0 + rho) / 2.0
        q = p
        
        # Base case P for n=2
        P = np.array([[p, 1 - p], [1 - q, q]])

        # Recursive step
        for i in range(3, n + 1):
            P_new = np.zeros((i, i))
            P_new[0:i-1, 0:i-1] += p * P
            P_new[0:i-1, 1:i] += (1.0 - p) * P
            P_new[1:i, 0:i-1] += (1.0 - q) * P
            P_new[1:i, 1:i] += q * P
            
            # Normalize internal rows (all except first and last rows are added twice)
            P_new[1:i-1, :] /= 2.0
            P = P_new

        return nodes, P

    def create_wealth_grid(self, min_a: float, max_a: float, n: int) -> np.ndarray:
        """
        Creates a non-linear (power-spaced) grid for wealth.
        
        A non-linear grid places more nodes near the borrowing constraint where the 
        value function exhibits more curvature.
        
        Args:
            min_a (float): Minimum wealth (borrowing constraint).
            max_a (float): Maximum wealth.
            n (int): Number of nodes.
            
        Returns:
            np.ndarray: Discretized wealth grid.
        """
        # Using a power-spacing approach (p=2.0 provides good density near zero)
        power = 2.0
        grid = np.linspace(0, 1, n) ** power
        grid = min_a + (max_a - min_a) * grid
        return grid

    def create_aime_grid(self, max_b: float, n: int) -> np.ndarray:
        """
        Creates a grid for Average Indexed Monthly Earnings (AIME/historical earnings).
        
        Args:
            max_b (float): Maximum possible historical earnings.
            n (int): Number of nodes.
            
        Returns:
            np.ndarray: Discretized AIME grid.
        """
        # Focus on bend points specified in configuration if necessary, 
        # but standard linear spacing is common for AIME.
        return np.linspace(0.0, max_b, n)

    def get_survival_probs(self) -> Dict[str, np.ndarray]:
        """
        Provides conditional survival rates for men and women.
        
        Based on SSA 2010 Period Life Table approximation.
        
        Returns:
            Dict: Arrays 'phi_m' and 'phi_f' indexed by model age.
        """
        # Survival probabilities decrease with age. 
        # In a full implementation, this loads from a CSV.
        # Here we use a representative Gompertz-style approximation for demographics.
        ages = np.arange(self.config.age_start, self.config.age_end + 1)
        
        # Simplified survival logic for reproduction:
        # P(survive age i) = exp(-exp(A + B*i))
        # Calibrated roughly to SSA 2010 tables
        phi_m = np.ones(len(ages))
        phi_f = np.ones(len(ages))
        
        for idx, age in enumerate(ages[:-1]):
            # Men
            phi_m[idx] = max(0.0, 1.0 - np.exp(-10.5 + 0.09 * age))
            # Women
            phi_f[idx] = max(0.0, 1.0 - np.exp(-11.0 + 0.09 * age))
            
        # Last period: survival is zero
        phi_m[-1] = 0.0
        phi_f[-1] = 0.0
        
        return {"phi_m": phi_m, "phi_f": phi_f}

    def get_marital_transition_matrix(self, age_idx: int, phi_m: float, phi_f: float) -> np.ndarray:
        """
        Computes the transition matrix for marital status m at a specific age.
        
        Marital statuses: 0 (Married), 1 (Single Male), 2 (Single Female).
        
        Args:
            age_idx (int): Age index.
            phi_m (float): Survival probability for male.
            phi_f (float): Survival probability for female.
            
        Returns:
            np.ndarray: 3x3 transition matrix.
        """
        # Transition logic from Section 2.1 and 3.1
        # [p(0|0) p(1|0) p(2|0)]
        # [p(0|1) p(1|1) p(2|1)]
        # [p(0|2) p(1|2) p(2|2)]
        
        P_m = np.zeros((3, 3))
        
        # Current status: Married (0)
        P_m[0, 0] = phi_m * phi_f        # Both survive
        P_m[0, 1] = phi_m * (1 - phi_f)  # Husband survives, wife dies
        P_m[0, 2] = (1 - phi_m) * phi_f  # Wife survives, husband dies
        
        # Current status: Single Male (1)
        P_m[1, 1] = phi_m                # Male survives
        # Other transitions from single are 0 (no remarriage)
        
        # Current status: Single Female (2)
        P_m[2, 2] = phi_f                # Female survives
        
        return P_m

    def get_joint_shock_transition(self, Pi_e: np.ndarray, omega: float) -> np.ndarray:
        """
        Constructs the joint shock transition matrix for married households.
        
        Incorporates intrafamily correlation as per Section 3.4.
        
        Args:
            Pi_e (np.ndarray): The n_e x n_e transition matrix for a single individual.
            omega (float): The intrafamily wage correlation parameter.
            
        Returns:
            np.ndarray: (n_e^2) x (n_e^2) transition matrix for couples.
        """
        n_e = Pi_e.shape[0]
        # Kronecker product for the independent case (uncorrelated shocks)
        Pi_independent = np.kron(Pi_e, Pi_e)
        
        # Perfectly correlated component:
        # If the couple starts at (j, k) and ends at (j', k'), perfect correlation
        # assumes they transition to j' = k' with the individual probability.
        Pi_correlated = np.zeros((n_e**2, n_e**2))
        
        for j in range(n_e):
            for k in range(n_e):
                row = j * n_e + k
                for j_prime in range(n_e):
                    # Perfectly correlated: both transition to the same shock level j_prime
                    col = j_prime * n_e + j_prime
                    # Weighting by the average transition probability of both
                    Pi_correlated[row, col] = Pi_e[j, j_prime]
        
        # Combined transition matrix
        # pi(e1', e2' | e1, e2) = omega * I(e1'=e2') * pi(e1'|e1) + (1-omega) * pi(e1'|e1) * pi(e2'|e2)
        # Note: The paper formulation uses omega as a probability of being on the diagonal 
        # given they are already there, but the simpler interpretation is a weighted sum 
        # of the independent and perfectly correlated distributions.
        
        Pi_joint = omega * Pi_correlated + (1.0 - omega) * Pi_independent
        
        # Ensure row stochasticity (rows sum to 1)
        row_sums = Pi_joint.sum(axis=1)
        Pi_joint = Pi_joint / row_sums[:, np.newaxis]
        
        return Pi_joint

    def get_initial_distribution_age21(self) -> np.ndarray:
        """
        Returns the initial shock distribution at age 21.
        
        As specified in Section 3.4.
        
        Returns:
            np.ndarray: 5-element array of probabilities.
        """
        return np.array([0.0625, 0.2500, 0.3750, 0.2500, 0.0625])

    def get_grids(self, b_max: float = 3.0) -> Dict[str, np.ndarray]:
        """
        Convenience method to generate all necessary grids.
        
        Args:
            b_max (float): Maximum historical earnings normalized.
            
        Returns:
            Dict: Dictionary containing all state space grids.
        """
        e_nodes, e_trans = self.rouwenhorst(
            self.config.rho, self.config.sigma, self.config.shock_nodes
        )
        
        # Max wealth estimated to be significantly higher than average income (norm to 1.0)
        a_max = 60.0 
        a_grid = self.create_wealth_grid(0.0, a_max, self.config.wealth_nodes)
        
        b_grid = self.create_aime_grid(b_max, self.config.earning_nodes)
        
        return {
            "a": a_grid,
            "b": b_grid,
            "e_nodes": e_nodes,
            "e_trans_single": e_trans,
            "e_trans_joint": self.get_joint_shock_transition(e_trans, self.config.omega)
        }
