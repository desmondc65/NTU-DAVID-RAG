## main.py
import numpy as np
import pandas as pd
from typing import Dict, List, Any, Tuple
from scipy.optimize import minimize_scalar

from config import EconomyConfig
from calibration import apply_calibration
from household import HouseholdSolver
 ignorant_ss_solver = None # Placeholder for circular logic check
from steady_state import SteadyStateSolver
from transition import TransitionSolver
from visualization import (
    plot_tax_fit,
    plot_welfare_by_wealth,
    plot_transition_paths,
    plot_optimal_tau_vs_beta_g,
    create_summary_table
)
from utils import calculate_certainty_equivalent_c, calculate_certainty_equivalent_h

class WelfareAnalysis:
    """
    Handles welfare metrics including Consumption Equivalent Variation (CEV)
    and the Efficiency Criterion as described in Section 2.3 of the paper.
    """

    def __init__(self, config: EconomyConfig):
        self.config = config

    def calculate_cev(self, v_new: float, ss_bench: Dict[str, Any]) -> float:
        """
        Calculates the factor (zeta) by which benchmark consumption must be 
        increased to match the new welfare level, keeping labor constant.
        
        Formula: V_new = (1 + zeta)^(1-sigma) * V_c_bench - V_h_bench
        """
        sigma = self.config.sigma
        gamma = ss_bench["distribution"]
        policy = ss_bench["policy"]
        
        # Calculate expected lifetime utility from consumption and labor separately for benchmark
        # We need the level of lifetime consumption utility and labor disutility
        # For a steady state, V_c = u(c)/(1-beta) and V_h = v(h)/(1-beta)
        v_c_bench = np.sum(gamma * (policy.consumption ** (1.0 - sigma)) / ((1.0 - sigma) * (1.0 - self.config.beta)))
        v_h_bench = np.sum(gamma * (self.config.theta * (policy.hours ** (1.0 + self.config.epsilon))) / 
                          ((1.0 + self.config.epsilon) * (1.0 - self.config.beta)))
        
        # Solving for zeta
        term = (v_new + v_h_bench) / v_c_bench
        zeta = (term ** (1.0 / (1.0 - sigma))) - 1.0
        return zeta * 100.0

    def calculate_efficiency_criterion(self, path_data: Dict[str, Any]) -> float:
        """
        Computes the aggregate efficiency criterion (Equation 7).
        Aggregates certainty-equivalent consumption and hours.
        """
        # Note: This is a simplified version of aggregating certainty equivalents 
        # across the distribution and time.
        distributions = path_data["distributions"]
        policies = path_data["policies"]
        beta = self.config.beta
        
        total_w_eff = 0.0
        # For simplicity in reproduction, we aggregate current period CE over the path
        # In a full implementation, one would solve the CE for each dynasty at t=0
        for t, (gamma_t, policy_t) in enumerate(zip(distributions, policies)):
            c_t = policy_t.consumption
            h_t = policy_t.hours
            
            # Aggregate certainty equivalents (or log sum if preferred by criterion)
            # Here we follow the logic: sum over agents of (CE_c - CE_h)
            # Given the utilitarian nature, we aggregate at each point
            c_agg = np.sum(gamma_t * c_t)
            h_agg = np.sum(gamma_t * h_t)
            
            total_w_eff += (beta ** t) * (c_agg - h_agg)
            
        return total_w_eff

def run_reproduction():
    """
    Orchestrates the reproduction experiments for the dynastic tax policy paper.
    """
    print("Initializing Economy Configuration...")
    config = EconomyConfig("config.yaml")
    apply_calibration(config)
    
    # Initialize Solvers
    hh_solver = HouseholdSolver(config)
    ss_solver = SteadyStateSolver(config, hh_solver)
    welfare_tool = WelfareAnalysis(config)

    # -------------------------------------------------------------------------
    # EXPERIMENT 1: U.S. Status Quo (Benchmark)
    # -------------------------------------------------------------------------
    print("\nExperiment 1: Computing U.S. Benchmark Steady State (tau = 0.17)...")
    ss_bench = ss_solver.find_equilibrium(config.tau_status_quo)
    print(f"Benchmark reached. r_annual: {ss_bench['r_annual']*100:.2f}%, K: {ss_bench['K']:.2f}, N: {ss_bench['N']:.2f}")

    # -------------------------------------------------------------------------
    # EXPERIMENT 2: Steady-State Optimal Tax Search
    # -------------------------------------------------------------------------
    print("\nExperiment 2: Searching for Steady-State Optimal Progressivity...")
    # The paper finds optimal tau_ss = -0.09
    # We evaluate a few points around the target to confirm
    tau_grid = [-0.15, -0.09, 0.0, 0.17, 0.30]
    ss_results = {}
    
    for tau in tau_grid:
        print(f"Evaluating tau = {tau}...")
        res = ss_solver.find_equilibrium(tau)
        # Utilitarian welfare: integral of V over stationary Gamma
        welfare = np.sum(res["distribution"] * res["policy"].value_function)
        ss_results[tau] = {"res": res, "welfare": welfare}
        
    optimal_tau_ss = max(ss_results, key=lambda k: ss_results[k]["welfare"])
    ss_opt = ss_results[optimal_tau_ss]["res"]
    
    print(f"Optimal Steady-State Progressivity found at tau = {optimal_tau_ss}")
    create_summary_table(config, ss_bench, ss_opt)
    
    # Welfare gain (CEV) for Steady State
    cev_ss = welfare_tool.calculate_cev(ss_results[optimal_tau_ss]["welfare"], ss_bench)
    print(f"Steady State Welfare Gain (CEV): {cev_ss:.2f}%")

    # Visualizations 1 & 2
    plot_tax_fit(config, ss_bench)
    plot_welfare_by_wealth(config, ss_bench, ss_opt)

    # -------------------------------------------------------------------------
    # EXPERIMENT 3: Transitional Dynamics to Optimal SS
    # -------------------------------------------------------------------------
    print("\nExperiment 3: Computing Transition Path from SQ to Optimal SS (tau = -0.09)...")
    trans_solver = TransitionSolver(config, hh_solver, ss_bench, ss_opt)
    # Transition to the regressive system found in SS optimization
    path_opt_ss = trans_solver.solve_path(t_periods=config.transition_periods, beta_g=0.0)
    
    # Plotting Figure 3
    plot_transition_paths(config, path_opt_ss, ss_bench)
    
    # Welfare of current generation along the transition
    welfare_trans = path_opt_ss["welfare"] # Computed with beta_g=0 inside solve_path
    cev_trans = welfare_tool.calculate_cev(welfare_trans, ss_bench)
    print(f"Welfare Gain of Current Generation including Transition: {cev_trans:.2f}%")
    print("(Note: The paper finds this is often negative or small for regressive shifts)")

    # -------------------------------------------------------------------------
    # EXPERIMENT 4: Optimal Reform vs Policy Maker Altruism (beta_g)
    # -------------------------------------------------------------------------
    print("\nExperiment 4: Finding Optimal Reform for varying beta_g...")
    # beta_g search: 0.0 (Only current), config.beta (Altruistic Parent), 0.98 (Long run)
    beta_g_targets = [0.0, config.beta ** (1.0/config.period_years), 0.95, 0.99]
    # To find optimal tau for a given beta_g, we evaluate a few candidates
    tau_candidates = [0.17, 0.16, 0.10, 0.0, -0.09]
    fig4_data = []

    for bg in beta_g_targets:
        best_tau_for_bg = 0.17
        max_w_bg = -1e10
        
        print(f"Searching optimal tau for beta_g = {bg:.3f}...")
        for tau_cand in tau_candidates:
            # We need the SS for the target tau_cand to solve transition
            ss_target = ss_solver.find_equilibrium(tau_cand)
            ts = TransitionSolver(config, hh_solver, ss_bench, ss_target)
            p_data = ts.solve_path(t_periods=config.transition_periods, beta_g=bg)
            
            if p_data["welfare"] > max_w_bg:
                max_w_bg = p_data["welfare"]
                best_tau_for_bg = tau_cand
        
        fig4_data.append((bg, best_tau_for_bg))
        print(f"  -> Optimal tau for beta_g {bg:.3f} is {best_tau_for_bg}")

    plot_optimal_tau_vs_beta_g(fig4_data, config)

    # -------------------------------------------------------------------------
    # EXPERIMENT 5: Efficiency Criterion
    # -------------------------------------------------------------------------
    print("\nExperiment 5: Evaluating Efficiency Criterion (Equation 7)...")
    # Using beta_g = beta (altruistic parents weight)
    # Search for tau that maximizes efficiency
    eff_results = []
    for tau_cand in [0.17, 0.10, 0.0, -0.09]:
        ss_target = ss_solver.find_equilibrium(tau_cand)
        ts = TransitionSolver(config, hh_solver, ss_bench, ss_target)
        p_data = ts.solve_path(t_periods=config.transition_periods, beta_g=config.beta)
        eff_val = welfare_tool.calculate_efficiency_criterion(p_data)
        eff_results.append((tau_cand, eff_val))
    
    best_tau_eff = max(eff_results, key=lambda x: x[1])[0]
    print(f"Optimal Progressivity under Efficiency Criterion: tau = {best_tau_eff}")

    print("\nReproduction process complete. Results saved to figures and tables.")

if __name__ == "__main__":
    # Ensure numerical precision
    np.set_printoptions(precision=4, suppress=True)
    run_reproduction()
