## config.py
import yaml
import os
from typing import Dict, Any, List

class Config:
    """
    Model configuration class for the OLG Social Security Redistribution study.
    
    This class loads parameters from 'config.yaml' and calculates derived constants
    necessary for the general-equilibrium overlapping-generations (OLG) model.
    It adheres to the calibrated parameters for the 2013 U.S. economy.
    """

    def __init__(self, config_path: str = "config.yaml"):
        """
        Initializes the Config object.

        Args:
            config_path (str): The path to the configuration file.
        """
        # Load yaml configuration
        if os.path.exists(config_path):
            with open(config_path, "r") as f:
                self._data = yaml.safe_load(f)
        else:
            raise FileNotFoundError(f"Configuration file {config_path} not found.")

        # Demographics (Section 2.1 and 3.1)
        age_cfg = self._data.get("age", {})
        self.age_start: int = age_cfg.get("start", 21)
        self.age_end: int = age_cfg.get("end", 100)
        self.age_retirement: int = age_cfg.get("retirement", 66)
        self.total_periods: int = age_cfg.get("total_periods", 80)
        self.eta: float = 0.667  # Share of married population (Section 3.1)

        # Preference Parameters (Table 1 & Section 3.2)
        pref_cfg = self._data.get("preferences", {})
        self.gamma: float = pref_cfg.get("gamma", 2.0)
        self.alpha: float = pref_cfg.get("alpha", 0.6530)
        self.lambda_joint: float = pref_cfg.get("lambda_joint", 0.6)
        self.beta_unadjusted: float = pref_cfg.get("discount_factor", 0.9827)
        self.frisch_elasticity: float = pref_cfg.get("frisch_elasticity", 0.5)

        # Production Technology (Section 3.3)
        prod_cfg = self._data.get("production", {})
        self.theta: float = prod_cfg.get("theta", 0.375)
        self.delta: float = prod_cfg.get("delta", 0.075)
        self.mu: float = prod_cfg.get("mu", 0.015)
        self.nu: float = prod_cfg.get("nu", 0.009)
        self.A_target: float = prod_cfg.get("A_target", 0.8885)

        # Earning Process (Section 3.4)
        earn_cfg = self._data.get("earning_process", {})
        self.rho: float = earn_cfg.get("rho", 0.87)
        self.sigma: float = earn_cfg.get("sigma", 0.39)
        self.omega: float = earn_cfg.get("wage_corr_married", 0.29)
        self.nodes_e: int = earn_cfg.get("nodes_e", 5)

        # Grid Sizes (Section Appendix A)
        grid_cfg = self._data.get("grid_sizes", {})
        self.wealth_nodes: int = grid_cfg.get("a", 27)
        self.earning_nodes: int = grid_cfg.get("b", 15)
        self.shock_nodes: int = grid_cfg.get("e", 5)

        # Derived Parameter: Growth-adjusted time discount factor (Section 2.1)
        # beta_hat = beta * (1 + mu)**(alpha * (1 - gamma))
        self.beta_hat: float = self.beta_unadjusted * (
            (1.0 + self.mu) ** (self.alpha * (1.0 - self.gamma))
        )

        # Government Policy (Section 3.5)
        pol_cfg = self._data.get("policy", {})
        self.tau_p: float = pol_cfg.get("tau_p", 0.1007)
        
        inc_tax = pol_cfg.get("income_tax", {})
        self.phi_t: float = inc_tax.get("phi_t", 0.3454)
        self.phi_m1: float = inc_tax.get("phi_m1", 0.0) # Placeholder from YAML
        self.phi_m2: float = inc_tax.get("phi_m2", 0.0) # Placeholder from YAML
        
        self.standard_deduction: float = pol_cfg.get("standard_deduction", 0.1)
        self.oasi_brackets: List[float] = pol_cfg.get("oasi_brackets", [0.90, 0.32, 0.15])
        self.oasi_thresholds: List[float] = pol_cfg.get("oasi_thresholds", [0.15, 0.90])

        # Numerical Solver Settings
        solve_cfg = self._data.get("solver", {})
        self.damping_factor: float = solve_cfg.get("damping_factor", 0.2)
        self.tolerance: float = solve_cfg.get("tolerance", 1e-4)
        self.max_iter: int = solve_cfg.get("max_iter", 500)
        self.transition_years: int = solve_cfg.get("transition_years", 100)

    def get_policy_params(self) -> Dict[str, Any]:
        """
        Returns government policy parameters as a dictionary.

        Returns:
            dict: Dictionary containing OASI tax rates, income tax parameters,
                  and Social Security brackets.
        """
        return {
            "tau_p": self.tau_p,
            "phi_t": self.phi_t,
            "phi_m1": self.phi_m1,
            "phi_m2": self.phi_m2,
            "standard_deduction": self.standard_deduction,
            "oasi_brackets": self.oasi_brackets,
            "oasi_thresholds": self.oasi_thresholds,
            "retirement_age": self.age_retirement,
            "eta": self.eta
        }

    @property
    def a_min_scalar(self) -> float:
        """
        Borrowing constraint scalar used to set age-dependent minimum wealth.
        Multiplying factor of 0.10 as specified in Section 3.4.
        """
        return 0.10

    @property
    def model_unit_dollars(self) -> float:
        """
        Dollar value of one model unit as calibrated in Section 3.4.
        """
        return 87766.0
