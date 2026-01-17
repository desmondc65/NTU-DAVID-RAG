## experiments.py
import numpy as np
import copy
from typing import Dict, Any, List, Tuple
from equilibrium_solver import EquilibriumSolver
from household_solver import HouseholdProblem
from simulation import Simulator

class ExperimentRunner:
    """
    Executes the decomposition analysis and counterfactual experiments 
    described in Section VI of the paper. This includes:
    - Scenario A: Equalizing bequests.
    - Scenario B: Removing superearners (z7, z8 = z6).
    - Scenario C: Homogenizing asset returns.
    - Systematic marginal effects calculation across all combinations.
    """

    def __init__(self, benchmark_solver: EquilibriumSolver):
        """
        Initializes the ExperimentRunner with a solved benchmark solver.

        Args:
            benchmark_solver: An EquilibriumSolver instance that has already 
                              solved the benchmark GE to obtain target prices and metrics.
        """
        self.benchmark_solver = benchmark_solver
        # Extract benchmark metrics for reference
        self.benchmark_results = self.benchmark_solver.solve_ge()
        self.params = benchmark_solver.params
        
        # Pre-calculate the value-weighted return from the benchmark for homogenization
        self.vw_avg_return = self._calculate_benchmark_avg_return()

    def _calculate_benchmark_avg_return(self) -> float:
        """
        Calculates the aggregate value-weighted rate of return from the benchmark distribution.
        Used to discipline the 'Homogeneous Returns' counterfactual.
        """
        dist = self.benchmark_results['gamma']
        metrics = self.benchmark_results['metrics']
        r_base = self.benchmark_results['r']
        k_grid = self.params['k_grid']
        kappa_grid = self.params['kappa_grid']
        
        total_k = metrics['K']
        weighted_r_sum = 0.0
        
        for j in range(self.params['total_periods']):
            for ik in range(len(k_grid)):
                for iz in range(len(self.params['z_grid'])):
                    for ikap in range(len(kappa_grid)):
                        mass = dist[j, ik, iz, ikap]
                        if mass > 0:
                            # Aggregate return for this state: base_r * kappa_i
                            # Note: kappa_grid contains multipliers for the 5-year period
                            weighted_r_sum += mass * k_grid[ik] * (r_base * kappa_grid[ikap])
                            
        return weighted_r_sum / total_k if total_k > 0 else r_base

    def run_counterfactual(self, scenario_type: str) -> Dict[str, Any]:
        """
        Runs a specific counterfactual scenario and solves for the new General Equilibrium.

        Args:
            scenario_type: String identifier for the scenario:
                           'equal_bequests', 'no_superearners', 'homog_returns',
                           'no_sup_no_ret', 'no_ret_no_beq', 'no_sup_no_beq', 'none'.

        Returns:
            Dictionary containing equilibrium metrics for the counterfactual.
        """
        # 1. Deep copy the solver components to avoid mutating the benchmark
        cf_solver = copy.deepcopy(self.benchmark_solver)
        hp = cf_solver.hp
        
        # 2. Modify the model environment based on scenario
        self._apply_scenario_modifications(cf_solver, scenario_type)
        
        # 3. Solve for the new General Equilibrium
        # Note: Removing superearners or returns changes K and N, requiring re-solving.
        print(f"Solving counterfactual: {scenario_type}...")
        results = cf_solver.solve_ge()
        
        return results

    def _apply_scenario_modifications(self, solver: EquilibriumSolver, scenario: str):
        """
        Mutates the household problem or solver logic for a given counterfactual.
        """
        hp = solver.hp
        
        # A. Remove Superearners: z7, z8 = z6
        if 'no_superearners' in scenario or scenario in ['no_sup_no_ret', 'no_sup_no_beq', 'none']:
            # Set productivity of extraordinary states to highest ordinary state
            hp.z_grid[6] = hp.z_grid[5] # z7 = z6
            hp.z_grid[7] = hp.z_grid[5] # z8 = z6
            
        # B. Homogeneous Returns: kappa = weighted average
        if 'homog_returns' in scenario or scenario in ['no_sup_no_ret', 'no_ret_no_beq', 'none']:
            # All return states are set to the multiplier corresponding to the benchmark average
            # multiplier = (1 + r_avg_annual)^5 / (1 + r_base_annual)^5
            avg_multiplier = self.vw_avg_return / solver.benchmark_solver.solve_ge()['r']
            hp.kappa_grid[:] = avg_multiplier
            
        # C. Equal Bequests
        if 'equal_bequests' in scenario or scenario in ['no_ret_no_beq', 'no_sup_no_beq', 'none']:
            # Modify the parameters used in Simulator's _allocate_bequests.
            # In simulation.py, equal redistribution is already the default 
            # if intergenerational correlation parameters (gamma_z, gamma_kappa)
            # are not activated or set to neutral.
            # Here we ensure they are disabled.
            solver.params['bequest_correlation_z'] = 0.5
            solver.params['bequest_correlation_kappa'] = 0.5

    def calculate_marginal_effects(self) -> Dict[str, Dict[str, Any]]:
        """
        Calculates the marginal contribution of each factor on wealth concentration, 
        accounting for interactions (Figure 7 logic).
        
        Runs all 2^3 combinations of factors:
        Factors: E (Superearners), R (Return Heterogeneity), B (Bequest Inequality)
        
        Returns:
            Dictionary containing mean, min, and max marginal effects for each factor 
            on the wealth Gini and top wealth shares.
        """
        # Scenarios bitmask: [S, R, B] (1 = benchmark state, 0 = counterfactual state)
        scenarios = {}
        
        # Run all 8 combinations
        for s in [0, 1]:
            for r in [0, 1]:
                for b in [0, 1]:
                    key = (s, r, b)
                    # Mapping bitmask to scenario mutation
                    temp_solver = copy.deepcopy(self.benchmark_solver)
                    if s == 0:
                        temp_solver.hp.z_grid[6:] = temp_solver.hp.z_grid[5]
                    if r == 0:
                        avg_mult = self.vw_avg_return / self.benchmark_results['r']
                        temp_solver.hp.kappa_grid[:] = avg_mult
                    if b == 0:
                        temp_solver.params['bequest_correlation_z'] = 0.5
                        temp_solver.params['bequest_correlation_kappa'] = 0.5
                    
                    print(f"Solving scenario permutation: S={s}, R={r}, B={b}")
                    res = temp_solver.solve_ge()
                    scenarios[key] = res['metrics']

        # Calculate Marginal Effects for each factor
        # Effect = Metric(Factor ON) - Metric(Factor OFF)
        factors = {'superearners': 0, 'returns': 1, 'bequests': 2}
        final_effects = {}
        
        metrics_to_track = ['wealth_gini', 'top_1pct_wealth_share', 'top_0.1pct_wealth_share']
        
        for factor_name, bit_idx in factors.items():
            factor_impacts = {m: [] for m in metrics_to_track}
            
            # There are 4 pairs for each factor marginal effect calculation
            # Example for S (index 0): 
            # (1,1,1)-(0,1,1), (1,0,1)-(0,0,1), (1,1,0)-(0,1,0), (1,0,0)-(0,0,0)
            for other_bits in range(4):
                # Construct bitmask
                binary = format(other_bits, '02b')
                mask_off = [0, 0, 0]
                mask_on = [0, 0, 0]
                
                # Distribute other_bits to the remaining two positions
                other_positions = [i for i in range(3) if i != bit_idx]
                for i, pos in enumerate(other_positions):
                    mask_off[pos] = int(binary[i])
                    mask_on[pos] = int(binary[i])
                
                mask_off[bit_idx] = 0
                mask_on[bit_idx] = 1
                
                m_off = scenarios[tuple(mask_off)]
                m_on = scenarios[tuple(mask_on)]
                
                for metric in metrics_to_track:
                    # Marginal contribution (Reduction in wealth concentration)
                    impact = m_on[metric] - m_off[metric]
                    factor_impacts[metric].append(impact)
            
            # Aggregate stats for the factor
            final_effects[factor_name] = {
                metric: {
                    'mean': np.mean(vals),
                    'min': np.min(vals),
                    'max': np.max(vals)
                } for metric, vals in factor_impacts.items()
            }
            
        return final_effects

    def generate_table_5_data(self) -> List[Dict[str, Any]]:
        """
        Generates data for Table 5 (Determinants of Wealth Concentration).
        """
        table_rows = []
        
        # 1. Benchmark
        table_rows.append({
            'label': 'Benchmark',
            'results': self.benchmark_results['metrics']
        })
        
        # 2. Individual Counterfactuals (a, b, c)
        scenarios = [
            ('equal_bequests', 'Economy (a): Equal Bequests'),
            ('no_superearners', 'Economy (b): No Superearners'),
            ('homog_returns', 'Economy (c): Homogeneous Returns')
        ]
        
        for s_type, label in scenarios:
            res = self.run_counterfactual(s_type)
            table_rows.append({
                'label': label,
                'results': res['metrics']
            })
            
        # 3. Combinations
        combos = [
            ('no_sup_no_ret', 'Economy (d): No Sup. + No Returns'),
            ('no_ret_no_beq', 'Economy (e): No Ret. + No Bequests')
        ]
        for s_type, label in combos:
            res = self.run_counterfactual(s_type)
            table_rows.append({
                'label': label,
                'results': res['metrics']
            })
            
        return table_rows

    def plot_figure_7_data(self):
        """
        Convenience function to print formatted data for Figure 7.
        """
        effects = self.calculate_marginal_effects()
        print("\n--- Figure 7 Marginal Effects (Reduction in Top 1% Wealth Share) ---")
        for factor, data in effects.items():
            top1 = data['top_1pct_wealth_share']
            print(f"{factor.capitalize()}: Mean={top1['mean']:.4f}, Range=[{top1['min']:.4f}, {top1['max']:.4f}]")

