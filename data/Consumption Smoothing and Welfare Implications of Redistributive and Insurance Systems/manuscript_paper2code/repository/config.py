## config.py
import yaml
import os
from typing import Dict, Any


class Config:
    """Central configuration repository for the OLG life cycle model of Japan.

    This class loads parameters from 'config.yaml', performs necessary 
    conversions (e.g., annual to period rates), and defines the dimensions 
    and bounds for the numerical grids used in the model.
    """

    def __init__(self, config_path: str = "config.yaml"):
        """Initializes the Config class by loading the YAML file and setting parameters.

        Args:
            config_path: Path to the configuration file. Defaults to "config.yaml".
        """
        if not os.path.exists(config_path):
            raise FileNotFoundError(f"Configuration file {config_path} not found.")

        with open(config_path, "r") as f:
            self.raw_params = yaml.safe_load(f)

        self.params: Dict[str, Any] = {}
        self._load_params()
        self._derive_period_parameters()

    def _load_params(self):
        """Flattens and processes the hierarchical structure of the config file."""
        # Demographics
        self.params["start_age"] = self.raw_params["demographics"]["start_age"]
        self.params["retirement_age"] = self.raw_params["demographics"]["retirement_age"]
        self.params["max_age"] = self.raw_params["demographics"]["max_age"]
        self.params["period_length"] = self.raw_params["demographics"]["period_length"]
        self.params["num_periods"] = self.raw_params["demographics"]["num_periods"]
        
        # Calculations for age periods
        # j=1 (25-29), ..., j=8 (60-64), j=9 (65-69)
        self.params["jr"] = (self.params["retirement_age"] - self.params["start_age"]) // self.params["period_length"] + 1

        # Preferences
        self.params["beta_annual"] = self.raw_params["preferences"]["beta_annual"]
        self.params["sigma"] = self.raw_params["preferences"]["sigma"]
        self.params["frisch_elasticity"] = self.raw_params["preferences"]["frisch_elasticity"]
        self.params["eta"] = self.raw_params["preferences"]["eta"]
        self.params["vg_male"] = self.raw_params["preferences"]["vg_male"]
        self.params["vg_female"] = self.raw_params["preferences"]["vg_female"]

        # Technology
        self.params["alpha"] = self.raw_params["technology"]["alpha"]
        self.params["psi_tfp"] = self.raw_params["technology"]["psi_tfp"]
        self.params["delta_annual"] = self.raw_params["technology"]["delta_annual"]
        self.params["target_ky_ratio"] = self.raw_params["technology"]["target_ky_ratio"]

        # Productivity
        self.params["persistence_annual"] = self.raw_params["productivity"]["persistence_annual"]
        self.params["sigma_z"] = self.raw_params["productivity"]["sigma_z"]
        self.params["zeta"] = self.raw_params["productivity"]["zeta"]
        self.params["intra_family_corr"] = self.raw_params["productivity"]["intra_family_corr"]
        self.params["college_premium"] = self.raw_params["productivity"]["college_premium"]
        self.params["kappa_male"] = self.raw_params["productivity"]["kappa_male"]
        self.params["kappa_female"] = self.raw_params["productivity"]["kappa_female"]

        # Government
        self.params["tau_c"] = self.raw_params["government"]["tau_c"]
        self.params["g_to_gdp"] = self.raw_params["government"]["g_to_gdp"]
        self.params["phi_copay"] = self.raw_params["government"]["phi_copay"]
        self.params["target_pension_to_gdp"] = self.raw_params["government"]["target_pension_to_gdp"]
        
        # Tax Parameters
        self.params["tax_single"] = self.raw_params["government"]["tax_single"]
        self.params["tax_married"] = self.raw_params["government"]["tax_married"]

        # Health
        self.params["gamma"] = self.raw_params["health"]["gamma"]
        self.params["h_productivity"] = self.raw_params["health"]["h_productivity"]
        self.params["target_med_exp_gdp"] = self.raw_params["health"]["target_med_exp_gdp"]
        self.params["target_med_exp_income"] = self.raw_params["health"]["target_med_exp_income"]

        # Simulation
        self.params["num_agents"] = self.raw_params["simulation"]["num_agents"]
        self.params["tolerance_ge"] = float(self.raw_params["simulation"]["tolerance_ge"])
        self.params["max_iter_ge"] = self.raw_params["simulation"]["max_iter_ge"]

    def _derive_period_parameters(self):
        """Converts annual rates to period (5-year) equivalents."""
        p = self.params["period_length"]
        
        # Period discount factor beta
        self.params["beta_period"] = self.params["beta_annual"] ** p
        
        # Period depreciation delta: (1 - delta_p) = (1 - delta_a)^p
        self.params["delta_period"] = 1.0 - (1.0 - self.params["delta_annual"]) ** p

        # Period productivity persistence: rho_p = rho_a^p
        self.params["persistence_period"] = self.params["persistence_annual"] ** p

    def get_grid_settings(self) -> Dict[str, Any]:
        """Defines and returns the numerical grid settings for the model solver.

        Returns:
            A dictionary containing grid dimensions and bounds for assets, 
            average earnings, health, and productivity.
        """
        # Asset grid: k (log-spaced to handle borrowing constraints k >= 0)
        # Dimensions chosen to balance accuracy and speed in high-dimensional married states.
        grid_settings = {
            "n_k": 100,
            "k_min": 0.0,
            "k_max": 100.0,
            
            # Average earnings grid: e_tilde (linear, used for pension SS calculations)
            "n_e": 40,
            "e_min": 0.0,
            "e_max": 8.0,
            
            # Health grid: h (discrete states 0 to 4)
            "n_h": 5,
            "h_states": [0, 1, 2, 3, 4],
            
            # Productivity grid: z (discretized Markov chain)
            # 6 states: 3 transitory x 2 permanent (college vs non-college)
            "n_z": 6,
            "n_z_transitory": 3,
            "n_z_permanent": 2
        }
        return grid_settings

    def get_all_params(self) -> Dict[str, Any]:
        """Returns the full dictionary of parameters."""
        return self.params


if __name__ == "__main__":
    # Example usage for testing
    try:
        config = Config("config.yaml")
        print("Configuration successfully loaded.")
        print(f"Number of periods: {config.params['num_periods']}")
        print(f"Retirement starts at period: {config.params['jr']}")
        print(f"Period Discount Factor (beta): {config.params['beta_period']:.4f}")
        print(f"Period Depreciation (delta): {config.params['delta_period']:.4f}")
    except Exception as e:
        print(f"Error loading configuration: {e}")

