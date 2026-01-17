## config.py
import numpy as np
import yaml
from typing import Dict, Any

class Config:
    """
    Central configuration and parameter management for the wealth concentration model.
    Loads settings from config.yaml and computes derived parameters (grids, transition matrices).
    """

    def __init__(self, config_path: str = "config.yaml"):
        """
        Initializes the Config object.
        
        Args:
            config_path: Path to the YAML configuration file.
        """
        self.params: Dict[str, Any] = {}
        self.calibration_targets: Dict[str, Any] = {}
        self.load_config(config_path)

    def load_config(self, path: str):
        """
        Loads parameters from YAML and derives model-specific data structures.
        
        Args:
            path: String path to the config file.
        """
        with open(path, 'r') as f:
            raw_config = yaml.safe_load(f)

        # 1. Scalar Parameters from YAML
        mp = raw_config['model_parameters']
        self.params['period_length_years'] = mp['period_length_years']
        self.params['total_periods'] = mp['total_periods']
        self.params['retirement_period'] = mp['retirement_period']
        self.params['sigma_c'] = mp['sigma_c']
        self.params['sigma_l'] = mp['sigma_l']
        self.params['theta'] = mp['theta']
        self.params['beta'] = mp['beta']
        self.params['alpha'] = mp['alpha']
        self.params['delta_annual'] = mp['depreciation_annual']
        self.params['delta'] = 1 - (1 - mp['depreciation_annual'])**self.params['period_length_years']
        self.params['psi'] = mp['aggregate_tfp']

        # 2. Taxation System
        ts = raw_config['tax_system']
        self.params['tau_c'] = ts['corporate_tax_rate']
        self.params['tau_s'] = ts['sales_tax_rate']
        self.params['tau_b'] = ts['estate_tax_rate']
        self.params['estate_top_pct'] = ts['estate_tax_threshold_top_pct']
        self.params['tau_max'] = ts['income_tax_max_marginal']

        # 3. Calibration Targets
        self.calibration_targets = raw_config['calibration_targets']

        # 4. Demographics and Survival Probabilities
        # Values approximating Halliday et al. (2019) logistic survival function
        # s(j) = [1 + exp(w0 + w1*j + w2*j^2)]^-1
        # Coefficients derived to match US survival curves for 5-year periods
        w0, w1, w2 = -10.5, 0.25, -0.0015
        ages = np.arange(1, self.params['total_periods'] + 1)
        # Note: Paper uses survival probability for each age j. 
        # Usually s(j) is prob of surviving from age j to j+1.
        logit_vals = w0 + w1 * ages + w2 * (ages**2)
        self.params['survival_probs'] = 1.0 / (1.0 + np.exp(logit_vals))
        # Last period certain death
        self.params['survival_probs'][-1] = 0.0

        # 5. Labor Productivity Grid and Transitions (z)
        lp = raw_config['labor_productivity']
        self._setup_labor_productivity(lp)

        # 6. Capital Return Process (kappa)
        cr = raw_config['capital_returns']
        self._setup_capital_returns(cr)

        # 7. Asset Grid (k)
        self._setup_asset_grid()

        # 8. Bequest Utility Parameters (Initial Guesses)
        self.params['phi1'] = 10.0  # Overall altruism
        self.params['phi2'] = 5.0   # Degree of non-homotheticity
        self.params['sigma_b'] = 2.0 # Curvature of bequest function

    def _setup_labor_productivity(self, lp: Dict[str, Any]):
        """Sets up the 8-state labor productivity process."""
        n_ord = lp['ordinary_states']
        n_extra = lp['extraordinary_states']
        
        # AR(1) parameters for ordinary states (Heathcote et al. 2010)
        rho_ann = lp['ar1_persistence_annual']
        rho_5yr = rho_ann**self.params['period_length_years']
        
        # Sigma derived from paper (standard deviation of wages grows by 47%...)
        # We use a placeholder variance for the Rouwenhorst discretization
        sigma_eps = 0.81 * (1 - rho_5yr**2)**0.5 # Simplified stationary variance mapping
        
        # Discretize AR(1) using Rouwenhorst (3 states for transitory component a)
        # We'll use 2 permanent states (fL, fH) and 3 transitory (aL, aM, aH)
        # to get 6 ordinary states as per the paper.
        P_a = self._rouwenhorst(rho_5yr, sigma_eps, 3)
        
        # Construct the transition matrix for ordinary states (A)
        # Paper says A is normalized by (1 - lambda_in)
        lambda_in = lp['extraordinary_in_prob']
        lambda_out = lp['extraordinary_out_prob']
        
        A = P_a * (1 - lambda_in)
        
        # Full 8x8 Transition Matrix (Pi_z) - following Table 3 structure
        pi_z = np.zeros((8, 8))
        
        # Ordinary to Ordinary and Extraordinary (z1-z6)
        # Blocks for fL and fH (assuming permanent state doesn't switch)
        pi_z[0:3, 0:3] = A
        pi_z[3:6, 3:6] = A
        pi_z[0:6, 6] = lambda_in # Transition to z7
        
        # Extraordinary to Ordinary (z7)
        # Paper: equally likely to transition to any ordinary state
        pi_z[6, 0:6] = lambda_out / 6.0
        pi_z[6, 6] = 0.64 # Probability lambda_ll (from paper: stays in top 1% earn with 64%)
        pi_z[6, 7] = 1.0 - (lambda_out + 0.64)
        
        # Extraordinary to Extraordinary (z8)
        pi_z[7, 6:8] = [0.1, 0.9] # lambda_hl, lambda_hh (Placeholders for calibration)
        
        self.params['pi_z'] = pi_z
        
        # Productivity levels (z) - log values discretized then exponentiated
        # Placeholder values calibrated in equilibrium_solver
        self.params['z_grid'] = np.array([0.5, 0.8, 1.2, 1.5, 2.0, 3.0, 19.0, 160.0])
        
        # Initial distribution at age 20 (Table 3)
        zeta = 0.18
        self.params['initial_z_dist'] = np.array([
            zeta/4, (1-zeta)/2, zeta/4,
            zeta/4, (1-zeta)/2, zeta/4,
            0.0, 0.0
        ])

    def _setup_capital_returns(self, cr: Dict[str, Any]):
        """Sets up the 3-state return process."""
        # Convert annual rates to 5-year multipliers
        r_low = (1 + cr['low_return_annual'])**5
        r_high = (1 + cr['high_return_annual'])**5
        r_top = (1 + cr['top_return_annual'])**5
        
        self.params['kappa_grid'] = np.array([r_low, r_high, r_top])
        
        # Transition matrices for kappa depend on z
        # pi_in(z) is 15x larger for extraordinary productivity (z7, z8)
        base_pi_in = 0.02
        pi_in_extra = base_pi_in * 15.0
        
        def make_pi_kappa(pi_in):
            # Persistence probabilities pi_ll, pi_hh from paper (0.9-0.96)
            p_ll, p_hh = 0.95, 0.92
            m = np.zeros((3, 3))
            m[0, 0] = p_ll
            m[0, 1] = 1.0 - p_ll - pi_in
            m[0, 2] = pi_in
            m[1, 0] = 1.0 - p_hh - pi_in
            m[1, 1] = p_hh
            m[1, 2] = pi_in
            m[2, 0] = 0.0
            m[2, 1] = 0.1 # 1 - pi_top_top
            m[2, 2] = 0.9 # pi_top_top
            return m

        self.params['pi_kappa_ord'] = make_pi_kappa(base_pi_in)
        self.params['pi_kappa_extra'] = make_pi_kappa(pi_in_extra)

    def _setup_asset_grid(self):
        """Creates a non-linear grid for assets (k)."""
        k_min = 0.0
        k_max = 5000.0 # Large enough to capture the top 0.1%
        n_k = 150      # Fine grid for accuracy
        # Power-spaced grid: dense at the bottom, sparse at the top
        # k_i = max * (i / (n-1))^p
        power = 2.5
        self.params['k_grid'] = k_max * (np.linspace(0, 1, n_k)**power)

    def _rouwenhorst(self, rho: float, sigma: float, n: int) -> np.ndarray:
        """
        Discretizes an AR(1) process using the Rouwenhorst method.
        
        Args:
            rho: Persistence parameter.
            sigma: Standard deviation of innovations.
            n: Number of grid points.
            
        Returns:
            Transition matrix.
        """
        if n == 1:
            return np.array([[1.0]])
        
        p = (1 + rho) / 2
        q = p
        
        P = np.array([[p, 1-p], [1-q, q]])
        
        for i in range(2, n):
            P_new = np.zeros((i + 1, i + 1))
            P_new[:i, :i] += p * P
            P_new[:i, 1:i+1] += (1 - p) * P
            P_new[1:i+1, :i] += (1 - q) * P
            P_new[1:i+1, 1:i+1] += q * P
            # Normalize middle rows
            P_new[1:i, :] /= 2.0
            P = P_new
            
        return P

    def get_param(self, key: str, default: Any = None) -> Any:
        """Safe access to parameters."""
        return self.params.get(key, default)

    def update_param(self, key: str, value: Any):
        """Updates a parameter value (used during calibration)."""
        self.params[key] = value

