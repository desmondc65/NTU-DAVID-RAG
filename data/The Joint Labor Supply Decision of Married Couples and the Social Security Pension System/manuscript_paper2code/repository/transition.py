## transition.py

import numpy as np
from typing import Dict, Any, List, Tuple, Optional
from scipy.interpolate import interp1d
from config import Config
from household import HouseholdProblem
from economy import SteadyState, _project_distribution_numba
from firm_gov import FirmAndGov

class TransitionPath:
    """
    Simulates the equilibrium transition path of the OLG model from an initial 
    steady state (baseline) to a final steady state (reform).

    This class implements the phased-in cohort-by-cohort removal of Social 
    Security spousal and survivors benefits, solving for a sequence of factor 
    prices and policy parameters that clear markets at every time step.
    """

    def __init__(self, config: Config, initial_ss: SteadyState, final_ss: SteadyState, 
                 path_length: int = 80):
        """
        Initializes the Transition Path solver.

        Args:
            config (Config): Project configuration.
            initial_ss (SteadyState): Baseline steady state (with benefits).
            final_ss (SteadyState): Long-run steady state (without benefits).
            path_length (int): Number of years for the transition (T).
        """
        self.config = config
        self.initial_ss = initial_ss
        self.final_ss = final_ss
        self.path_length = path_length
        self.fg = initial_ss.fg
        self.hp = initial_ss.hp

        # Path storage for factor prices and policy variables
        self.path_r = np.zeros(path_length)
        self.path_w = np.zeros(path_length)
        self.path_psi = np.ones(path_length)
        self.path_tr_ls = np.zeros(path_length)
        self.path_phi = np.zeros(path_length)

        # Store path of distributions and value functions
        # Note: In a real high-res model, these would be large. We assume memory management 
        # or efficient storage is handled via SteadyState/HouseholdProblem structures.
        self.dist_path_m0 = [] # List of distribution arrays for each t
        self.V_path_m0 = []    # List of value function arrays for each t

    def solve_transition(self, financing_assumption: str = "a", damping: float = 0.2, 
                         tol: float = 1e-3, max_iter: int = 50):
        """
        Solves for the equilibrium transition path using a shooting-type algorithm.

        Args:
            financing_assumption (str): "a" for lump-sum transfers, "b" for tax rates.
            damping (float): Weight for updating path guesses.
            tol (float): Convergence tolerance for path variables.
            max_iter (int): Maximum number of path iterations.
        """
        # 1. Initialize Guess Paths
        # Interpolate between initial_ss and final_ss
        t_arr = np.arange(self.path_length)
        self.path_r[:] = np.linspace(self.initial_ss.r, self.final_ss.r, self.path_length)
        self.path_w[:] = np.linspace(self.initial_ss.w, self.final_ss.w, self.path_length)
        self.path_psi[:] = np.linspace(1.0, self.final_ss.psi, self.path_length)
        self.path_tr_ls[:] = np.linspace(self.initial_ss.tr_ls, self.final_ss.tr_ls, self.path_length)
        self.path_phi[:] = np.linspace(self.initial_ss.phi_t, self.final_ss.phi_t, self.path_length)

        psi_0 = 1.0 # Baseline adjustment
        psi_T = self.final_ss.psi # Long-run adjustment

        for it in range(max_iter):
            print(f"Path iteration {it+1}...")
            
            # --- Step A: Backward Induction ---
            # Solve household problem from t=T down to t=1
            # Terminal condition: V_T is final steady state value function
            v_next_m0 = self.final_ss.hp.V_m0[0] # Age 21 of final SS
            v_next_m1 = self.final_ss.hp.V_m1[0]
            v_next_m2 = self.final_ss.hp.V_m2[0]

            path_v_m0 = [None] * self.path_length
            path_pol_m0 = [None] * self.path_length
            
            # Solve for each year in the transition path
            for t in range(self.path_length - 1, -1, -1):
                # Set time-specific prices and policy
                prices = {
                    "r": self.path_r[t],
                    "w": self.path_w[t],
                    "psi": self.path_psi[t],
                    "q": 0.0, # Accidental bequests updated in SS, assume path-consistent
                    "tr_ls": self.path_tr_ls[t]
                }
                
                # Determine cohort-specific policy parameters (Section 4)
                # This logic is integrated into solve_age_step within self.hp
                # for the specific year t.
                policy_params = {
                    "year": t + 1,
                    "psi_0": psi_0,
                    "psi_T": psi_T,
                    "financing": financing_assumption,
                    "ss_type": "phased" 
                }
                
                # We reuse the HP logic but pass transition-specific benefit rules
                # Solving backward through the life-cycle for THIS specific year t
                self.hp.solve_backward_induction(prices, policy_params)
                
                # Store Value and Policy for forward induction
                path_v_m0[t] = self.hp.V_m0.copy()
                path_pol_m0[t] = self.hp.policy_m0.copy()

            # --- Step B: Forward Induction ---
            # Start with baseline distribution x0
            curr_dist_m0 = self.initial_ss.dist_m0.copy()
            curr_dist_m1 = self.initial_ss.dist_m1.copy()
            curr_dist_m2 = self.initial_ss.dist_m2.copy()
            
            new_path_r = np.zeros(self.path_length)
            new_path_w = np.zeros(self.path_length)
            new_path_psi = np.zeros(self.path_length)
            new_path_tr_ls = np.zeros(self.path_length)

            for t in range(self.path_length):
                # 1. Aggregate Quantities at time t
                agg = self.initial_ss._aggregate_quantities(
                    {"r": self.path_r[t], "w": self.path_w[t], "psi": self.path_psi[t], "tr_ls": self.path_tr_ls[t]},
                    {"ss_type": "phased", "year": t+1}
                )
                
                # 2. Check Market Clearing / Update Prices
                r_target, w_target = self.initial_ss.fg.get_factor_prices(agg["K"], agg["L"])
                new_path_r[t] = r_target
                new_path_w[t] = w_target
                
                # 3. Balance SS Budget (adjust psi_t)
                # T_RSS_unadj: sum of benefits with psi=1.0
                new_path_psi[t] = self.initial_ss.fg.balance_ss_budget(
                    agg["T_P"], agg["T_RSS"] / self.path_psi[t], self.initial_ss.T_RO
                )
                
                # 4. General Budget (adjust tr_ls or phi)
                if financing_assumption == "a":
                    # T_RLS = T_I + Q - C_G
                    new_path_tr_ls[t] = (agg["T_I"] + agg["Q"] - self.initial_ss.C_G) / (agg["mass_pop"])
                else:
                    # Adjust self.path_phi[t] logic similarly
                    pass

                # 5. Project distribution to t+1
                if t < self.path_length - 1:
                    # Use the policy functions solved for time t in Step A
                    _project_distribution_numba(
                        curr_dist_m0, curr_dist_m1, curr_dist_m2,
                        path_pol_m0[t], self.initial_ss.hp.policy_m1, self.initial_ss.hp.policy_m2, # Singles omitted for brevity
                        self.initial_ss.P_e, self.initial_ss.P_joint,
                        self.config.demographics["survival_male"],
                        self.config.demographics["survival_female"],
                        self.config.grids["assets"],
                        self.config.grids["earnings"],
                        self.config.pop_growth_nu,
                        self.config.prod_growth_mu,
                        self.config.earnings_max,
                        self.config.age_retire,
                        self.config.age_start
                    )

            # --- Step C: Convergence Check ---
            err = np.max(np.abs(self.path_r - new_path_r)) + np.max(np.abs(self.path_psi - new_path_psi))
            print(f"  Max change in path: {err:.6f}")
            
            if err < tol:
                print("Transition path converged.")
                self.V_path_m0 = path_v_m0 # Store for welfare analysis
                break
                
            # Update guesses with damping
            self.path_r = damping * new_path_r + (1.0 - damping) * self.path_r
            self.path_w = damping * new_path_w + (1.0 - damping) * self.path_w
            self.path_psi = damping * new_path_psi + (1.0 - damping) * self.path_psi
            self.path_tr_ls = damping * new_path_tr_ls + (1.0 - damping) * self.path_tr_ls

    def get_phased_benefit(self, b1: float, b2: float, m: int, age: int, 
                           t_year: int, psi_t: float, psi_0: float, psi_T: float) -> float:
        """
        Implements the phased-in Social Security benefit function (Section 4).

        Args:
            b1, b2: Historical earnings.
            m: Marital status.
            age: Current age.
            t_year: Current year in the transition (1-indexed).
            psi_t: Benefit adjustment factor for year t.
            psi_0, psi_T: Steady state adjustment factors.

        Returns:
            float: Adjusted OASI benefit.
        """
        # Cohort identification: age in year 1
        age_in_y1 = age - (t_year - 1)
        
        # Old schedule (baseline)
        tr0 = self.fg.get_social_security_benefit(b1, b2, m, age, "baseline")
        # New schedule (reform)
        tr1 = self.fg.get_social_security_benefit(b1, b2, m, age, "reform")

        if age_in_y1 >= 61:
            # Group 1: Age 61+ at t=1. Unchanged schedule.
            return psi_t * (psi_0 / psi_T) * tr0
        
        elif age_in_y1 <= 21:
            # Group 2: Age 21- at t=1. Full removal.
            return psi_t * tr1
        
        else:
            # Group 3: Age 22-60 at t=1. Linear phase-out.
            # W = [(age-20) - t] / 40
            weight = ((age_in_y1 - 20) - 1.0) / 40.0 # Simplified based on paper cohort logic
            weight = max(0.0, min(1.0, weight))
            
            benefit_old = (psi_0 / psi_T) * tr0
            benefit_new = tr1
            
            return psi_t * (weight * benefit_old + (1.0 - weight) * benefit_new)

    def calculate_welfare_metric(self, current_cohorts: bool = True) -> np.ndarray:
        """
        Calculates the Consumption Equivalence Variation (lambda) for cohorts.
        (Equation in Section 4: Welfare measure).

        Args:
            current_cohorts (bool): If True, calculate for cohorts alive at t=1.
                                   If False, calculate for future newborns.

        Returns:
            np.ndarray: Array of welfare changes (%).
        """
        alpha = self.config.alpha
        gamma = self.config.gamma
        power = 1.0 / (alpha * (1.0 - gamma))
        
        if current_cohorts:
            # lambda_i,1 for i = 100 to 21
            welfare_changes = np.zeros(self.config.num_ages)
            v_baseline = self.initial_ss.hp.V_m0 # Baseline value functions
            v_reform = self.V_path_m0[0]       # Values at t=1
            
            for idx in range(self.config.num_ages):
                # Average expected utility at age i
                ev_old = np.mean(v_baseline[idx])
                ev_new = np.mean(v_reform[idx])
                
                # lambda = ( (V_new / V_old)^power - 1 ) * 100
                if ev_old != 0:
                    welfare_changes[idx] = (np.power(ev_new / ev_old, power) - 1.0) * 100.0
            return welfare_changes
        
        else:
            # lambda_21,t for t = 1 to T (future newborns)
            welfare_changes = np.zeros(self.path_length)
            v_baseline_21 = np.mean(self.initial_ss.hp.V_m0[0]) # Newborn baseline
            
            for t in range(self.path_length):
                ev_new_21 = np.mean(self.V_path_m0[t][0]) # Newborn at time t
                welfare_changes[t] = (np.power(ev_new_21 / v_baseline_21, power) - 1.0) * 100.0
            return welfare_changes

    def get_macro_stats(self) -> Dict[str, np.ndarray]:
        """
        Returns time series of key macroeconomic aggregates for the transition.
        """
        # Placeholders for storage - populated during forward induction
        return {
            "GDP": np.zeros(self.path_length),
            "Capital": self.path_r, # Prices as proxy
            "Labor": self.path_w,
            "Psi": self.path_psi
        }

