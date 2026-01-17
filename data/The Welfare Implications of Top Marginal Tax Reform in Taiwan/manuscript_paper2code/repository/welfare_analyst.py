## welfare_analyst.py
import numpy as np
import yaml
from typing import Dict, Any, Optional

class WelfareAnalyst:
    """
    Evaluates the social welfare implications of tax reforms in the Taiwanese 
    life-cycle economy.
    
    This class calculates Ex-ante Newborn Welfare (W_N) and Utilitarian Social 
    Welfare (W_U), then determines the Consumption Equivalent Variation (CEV) 
    required to make agents indifferent between different policy regimes.
    """

    def __init__(self, config_path: str = "config.yaml"):
        """
        Initializes the WelfareAnalyst with parameters from the config file.
        
        Args:
            config_path: Path to the config.yaml file.
        """
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
            
        self.J: int = self.config['demographics']['total_periods']  # 15
        self.beta_annual: float = self.config['preferences']['beta_annual']
        self.period_len: int = self.config['demographics']['period_length']
        self.beta: float = self.beta_annual ** self.period_len
        self.phi_married: float = 0.5  # Consistent with EconomySimulator
        
        # Expected Discounted Person-Years (EDPY) cache
        self.edpy_s: Optional[np.ndarray] = None  # Shape (2, J)
        self.edpy_m: Optional[np.ndarray] = None  # Shape (J,)

    def _compute_edpy(self, survival_m: np.ndarray, survival_f: np.ndarray) -> None:
        """
        Computes the Expected Discounted Person-Years (EDPY) for each household type.
        This represents the derivative of the lifetime value function with respect
        to the log of a uniform consumption scaler.
        
        Args:
            survival_m: Survival probabilities for males (J,).
            survival_f: Survival probabilities for females (J,).
        """
        edpy_s = np.zeros((2, self.J))
        edpy_m = np.zeros(self.J)
        
        # Terminal period: household size
        edpy_s[0, self.J-1] = 1.0
        edpy_s[1, self.J-1] = 1.0
        edpy_m[self.J-1] = 2.0
        
        # Backward induction for EDPY
        # D_j = size + beta * prob_survival * D_{j+1}
        for j in range(self.J - 2, -1, -1):
            # Singles
            edpy_s[0, j] = 1.0 + self.beta * survival_m[j] * edpy_s[0, j+1]
            edpy_s[1, j] = 1.0 + self.beta * survival_f[j] * edpy_s[1, j+1]
            
            # Married: includes joint survival and transition to single status
            p_both = survival_m[j] * survival_f[j]
            p_m_only = survival_m[j] * (1.0 - survival_f[j])
            p_f_only = survival_f[j] * (1.0 - survival_m[j])
            
            edpy_m[j] = 2.0 + self.beta * (
                p_both * edpy_m[j+1] + 
                p_m_only * edpy_s[0, j+1] + 
                p_f_only * edpy_s[1, j+1]
            )
            
        self.edpy_s = edpy_s
        self.edpy_m = edpy_m

    def compute_newborn_welfare(self, steady_state: Dict[str, Any]) -> float:
        """
        Computes the ex-ante newborn welfare (W_N) at age 25.
        
        Args:
            steady_state: Dictionary containing 'value_funcs' and initial 
                          productivity distributions.
                          
        Returns:
            The expected lifetime utility of a newborn household.
        """
        # Value functions at j=0 (Age 25-29)
        # Assuming value_funcs structure from solver: {'s': V_S, 'm': V_M}
        # V_S: (gender, age, asset, prod, earn)
        # V_M: (age, asset, prod_m, prod_f, earn)
        v_s = steady_state['value_funcs']['s']
        v_m = steady_state['value_funcs']['m']
        
        # Initial productivity distribution (z1-z4 are equally likely, z5 is 0)
        z_start_prob = np.array([0.25, 0.25, 0.25, 0.25, 0.0])
        nz = len(z_start_prob)
        
        # Calculate expected value for newborns (k=0, earn=0)
        # Weighting by male/female share for singles and joint for married
        ev_s_m = 0.0
        ev_s_f = 0.0
        for iz in range(nz):
            ev_s_m += z_start_prob[iz] * v_s[0, 0, 0, iz, 0]
            ev_s_f += z_start_prob[iz] * v_s[1, 0, 0, iz, 0]
            
        ev_m = 0.0
        for izm in range(nz):
            for izf in range(nz):
                ev_m += z_start_prob[izm] * z_start_prob[izf] * v_m[0, 0, izm, izf, 0]
                
        # Aggregate per-capita newborn welfare
        # Pop per newborn cohort: (1-phi) males + (1-phi) females + phi*2 in couples = 2
        w_n = 0.5 * ((1.0 - self.phi_married) * (ev_s_m + ev_s_f) + self.phi_married * ev_m)
        return w_n

    def compute_utilitarian_welfare(self, steady_state: Dict[str, Any]) -> float:
        """
        Computes the utilitarian social welfare (W_U) aggregating across all agents.
        
        Args:
            steady_state: Dictionary containing stationary distributions 'dist_s', 
                          'dist_m' and 'value_funcs'.
                          
        Returns:
            The total utilitarian welfare of the current population.
        """
        dist_s = steady_state['dist_s']
        dist_m = steady_state['dist_m']
        v_s = steady_state['value_funcs']['s']
        v_m = steady_state['value_funcs']['m']
        
        # Sum utility across the entire stationary distribution
        # Note: distributions are assumed to be probability masses over the state space
        total_w_u = np.sum(dist_s * v_s) + np.sum(dist_m * v_m)
        
        # Normalize by total person-population (normalized to 2.0 in our logic)
        return total_w_u / 2.0

    def calculate_cev(self, base_results: Dict[str, Any], new_results: Dict[str, Any]) -> Dict[str, float]:
        """
        Calculates the Consumption Equivalent Variation (CEV) for Newborn and 
        Utilitarian measures.
        
        Logic: 
        W_new = W_base + EDPY * log(1 + delta)
        delta = exp((W_new - W_base) / EDPY) - 1
        
        Args:
            base_results: Results from the benchmark steady state.
            new_results: Results from the reform/optimal steady state.
            
        Returns:
            Dictionary containing 'newborn_cev' and 'utilitarian_cev' (percentages).
        """
        # Ensure EDPY are computed using base parameters
        # Survival probabilities should be extracted from results or config
        # Here we assume they are stored in base_results['surv']
        surv_m = base_results.get('surv_m', np.ones(self.J))
        surv_f = base_results.get('surv_f', np.ones(self.J))
        self._compute_edpy(surv_m, surv_f)
        
        # 1. Newborn CEV
        wn_base = self.compute_newborn_welfare(base_results)
        wn_new = self.compute_newborn_welfare(new_results)
        
        # Aggregate EDPY for newborns at j=0
        edpy_n = 0.5 * (
            (1.0 - self.phi_married) * (self.edpy_s[0, 0] + self.edpy_s[1, 0]) + 
            self.phi_married * self.edpy_m[0]
        )
        
        newborn_cev = (np.exp((wn_new - wn_base) / edpy_n) - 1.0) * 100.0
        
        # 2. Utilitarian CEV
        wu_base = self.compute_utilitarian_welfare(base_results)
        wu_new = self.compute_utilitarian_welfare(new_results)
        
        # Aggregate population-weighted EDPY (utilitarian divisor)
        # Sum across all states j, k, z, e
        dist_s = base_results['dist_s']
        dist_m = base_results['dist_m']
        
        # Expand EDPY arrays to broadcast across asset/prod/earn dimensions
        pop_edpy = 0.0
        for j in range(self.J):
            pop_edpy += np.sum(dist_s[0, j]) * self.edpy_s[0, j]
            pop_edpy += np.sum(dist_s[1, j]) * self.edpy_s[1, j]
            pop_edpy += np.sum(dist_m[j]) * self.edpy_m[j]
            
        # Per capita population EDPY
        pop_edpy /= 2.0
        
        utilitarian_cev = (np.exp((wu_new - wu_base) / pop_edpy) - 1.0) * 100.0
        
        return {
            'newborn_cev': newborn_cev,
            'utilitarian_cev': utilitarian_cev
        }
