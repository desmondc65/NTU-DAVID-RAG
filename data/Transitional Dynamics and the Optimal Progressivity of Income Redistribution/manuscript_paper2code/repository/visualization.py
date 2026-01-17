## visualization.py
import numpy as np
import matplotlib.pyplot as plt
from typing import Dict, Any, List, Tuple
from config import EconomyConfig
from utils import tax_function, get_gini, marginal_net_income
from household import HouseholdPolicy

"""
The visualization.py module handles the generation of key figures from the paper:
Figure 1: Tax system progressivity fit.
Figure 2: Welfare by wealth and productivity.
Figure 3: Transition dynamics from benchmark to optimal regressive taxation.
Figure 4: Optimal progressivity (tau) vs policymaker's discount factor (beta_g).
"""

def plot_tax_fit(config: EconomyConfig, ss_benchmark: Dict[str, Any], save_path: str = "figure1_tax_fit.png") -> None:
    """
    Reproduces Figure 1: Log-log plot of disposable income vs pre-tax income.
    Shows the fit of the log-linear tax function to the benchmark economy.
    """
    gamma = ss_benchmark["distribution"]
    y_pre = ss_benchmark["y_pre_tax"]
    lambda_val = ss_benchmark["lambda"]
    tau = config.tau_status_quo
    
    # Flatten and calculate disposable income
    y_pre_flat = y_pre.flatten()
    gamma_flat = gamma.flatten()
    y_disp_flat = np.array([tax_function(y, lambda_val, tau) for y in y_pre_flat])
    
    # Sort for quantile grouping
    idx = np.argsort(y_pre_flat)
    y_pre_sorted = y_pre_flat[idx]
    y_disp_sorted = y_disp_flat[idx]
    gamma_sorted = gamma_flat[idx]
    
    # Calculate quantiles (bins) for the "circles" in the paper
    n_bins = 20
    cum_mass = np.cumsum(gamma_sorted)
    bin_edges = np.linspace(0.01, 0.99, n_bins)
    
    bin_y_pre = []
    bin_y_disp = []
    
    for i in range(len(bin_edges) - 1):
        mask = (cum_mass >= bin_edges[i]) & (cum_mass < bin_edges[i+1])
        if np.any(mask):
            bin_y_pre.append(np.mean(y_pre_sorted[mask]))
            bin_y_disp.append(np.mean(y_disp_sorted[mask]))
            
    # Plotting
    plt.figure(figsize=(8, 6))
    
    # Log values
    log_y_pre = np.log(y_pre_sorted[y_pre_sorted > 0])
    log_y_disp = np.log(y_disp_sorted[y_pre_sorted > 0])
    
    # Fitted line
    plt.plot(log_y_pre, log_y_pre * (1.0 - tau) + np.log(lambda_val), 
             color='black', label=f'Model Fit (tau={tau})')
    
    # Quantile circles
    plt.scatter(np.log(bin_y_pre), np.log(bin_y_disp), 
                facecolors='none', edgecolors='blue', label='Quantile Averages')
    
    # 45 degree line
    min_log = np.min(log_y_pre)
    max_log = np.max(log_y_pre)
    plt.plot([min_log, max_log], [min_log, max_log], '--', color='gray', alpha=0.5, label='45 degree line')
    
    plt.xlabel('log Pre-tax Income')
    plt.ylabel('log Disposable Income')
    plt.title('Figure 1: Progressivity of the U.S. Tax System')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.savefig(save_path)
    plt.close()

def plot_welfare_by_wealth(config: EconomyConfig, ss_benchmark: Dict[str, Any], 
                           ss_optimal: Dict[str, Any], save_path: str = "figure2_welfare.png") -> None:
    """
    Reproduces Figure 2: Welfare (Value Function) by wealth for different productivity groups.
    Compares the benchmark (tau=0.17) with the long-run optimal (tau=-0.09).
    """
    k_grid = config.k_grid
    v_bench = ss_benchmark["policy"].value_function
    v_opt = ss_optimal["policy"].value_function
    
    # Identify low and high productivity states
    # Based on calibration: 0 is (fL, aL) lowest, 3 is (fH, aH) highest
    iz_low = 0
    iz_high = 3
    
    plt.figure(figsize=(10, 6))
    
    # Plot for lowest productivity
    plt.plot(k_grid, v_bench[:, iz_low], 'b-', label='Benchmark (Low z)')
    plt.plot(k_grid, v_opt[:, iz_low], 'b--', label='Optimal SS (Low z)')
    
    # Plot for highest productivity
    plt.plot(k_grid, v_bench[:, iz_high], 'r-', label='Benchmark (High z)')
    plt.plot(k_grid, v_opt[:, iz_high], 'r--', label='Optimal SS (High z)')
    
    # Vertical lines for average wealth
    plt.axvline(ss_benchmark["K"], color='blue', alpha=0.5, linestyle=':', label='Avg Wealth (Bench)')
    plt.axvline(ss_optimal["K"], color='red', alpha=0.5, linestyle=':', label='Avg Wealth (Opt)')
    
    plt.xlabel('Wealth (k)')
    plt.ylabel('Welfare (V)')
    plt.title('Figure 2: Welfare by Wealth and Productivity')
    plt.legend()
    plt.xlim([0, config.k_max * 0.4]) # Focus on the relevant range
    plt.grid(True, alpha=0.3)
    plt.savefig(save_path)
    plt.close()

def plot_transition_paths(config: EconomyConfig, path_data: Dict[str, Any], 
                          ss_start: Dict[str, Any], save_path: str = "figure3_transition.png") -> None:
    """
    Reproduces Figure 3: Transition paths of K, N, C, r, and consumption inequality.
    Values are normalized relative to the initial steady state (Period 0).
    """
    t_periods = len(path_data["K"])
    time_years = np.arange(t_periods) * config.period_years
    
    # Normalization factors
    k0 = ss_start["K"]
    n0 = ss_start["N"]
    c0 = ss_start["C"]
    
    # 1. Capital (K)
    k_rel = path_data["K"] / k0
    
    # 2. Labor Supply (N)
    n_rel = path_data["N"] / n0
    
    # 3. Average Consumption (C)
    c_rel = path_data["C"] / c0
    
    # 4. Interest Rate (Annual %)
    r_annual = np.array([config.get_annual_r(r) for r in path_data["r"]]) * 100.0
    
    # 5. Consumption Inequality (Gini)
    # This requires calculating Gini for each period in the path
    gini_c_path = []
    for t in range(t_periods):
        gamma_t = path_data["distributions"][t]
        policy_t = path_data["policies"][t]
        c_flat = policy_t.consumption.flatten()
        gamma_flat = gamma_t.flatten()
        gini_c_path.append(get_gini(c_flat, gamma_flat))
    
    # Plotting grid (2x3)
    fig, axes = plt.subplots(2, 3, figsize=(15, 10))
    
    # Capital
    axes[0, 0].plot(time_years, k_rel, 'k-')
    axes[0, 0].set_title('Aggregate Capital (K)')
    axes[0, 0].set_ylabel('Relative to Status Quo')
    
    # Labor
    axes[0, 1].plot(time_years, n_rel, 'k-')
    axes[0, 1].set_title('Labor Input (N)')
    
    # Consumption
    axes[0, 2].plot(time_years, c_rel, 'k-')
    axes[0, 2].set_title('Average Consumption (C)')
    
    # Interest Rate
    axes[1, 0].plot(time_years, r_annual, 'k-')
    axes[1, 0].set_title('Interest Rate (r, annual %)')
    axes[1, 0].set_ylabel('%')
    
    # Consumption Gini
    axes[1, 1].plot(time_years, gini_c_path, 'k-')
    axes[1, 1].set_title('Consumption Inequality (Gini)')
    
    # Empty or placeholder (e.g., Output)
    y_rel = (path_data["K"]**config.alpha * path_data["N"]**(1-config.alpha)) / \
            (k0**config.alpha * n0**(1-config.alpha))
    axes[1, 2].plot(time_years, y_rel, 'k-')
    axes[1, 2].set_title('Aggregate Output (Y)')

    for ax in axes.flat:
        ax.set_xlabel('Years')
        ax.grid(True, alpha=0.3)
        
    plt.tight_layout()
    plt.savefig(save_path)
    plt.close()

def plot_optimal_tau_vs_beta_g(results: List[Tuple[float, float]], 
                               config: EconomyConfig, 
                               save_path: str = "figure4_opt_tau.png") -> None:
    """
    Reproduces Figure 4: Optimal progressivity (tau) as a function of the 
    policymaker's discount factor for future generations (beta_g).
    
    Args:
        results: List of (beta_g, optimal_tau) pairs.
        config: EconomyConfig for reference (e.g., benchmark beta).
    """
    if not results:
        print("No results provided for Figure 4.")
        return
        
    # Sort results by beta_g
    results.sort(key=lambda x: x[0])
    beta_gs, taus = zip(*results)
    
    plt.figure(figsize=(8, 6))
    plt.plot(beta_gs, taus, 'k-o', label='Optimal Progressivity (tau)')
    
    # Benchmark tau level
    plt.axhline(config.tau_status_quo, color='blue', linestyle=':', label='Status Quo (tau=0.17)')
    
    # Mark specific weights
    # 1. beta_g = 0 (Only care about current generation)
    # 2. beta_g = beta_period (Parental weight)
    plt.axvline(0.0, color='gray', alpha=0.3)
    
    # Convert annual beta to period beta for reference
    beta_annual = config.beta ** (1.0 / config.period_years)
    plt.axvline(beta_annual, color='red', linestyle='--', alpha=0.5, label='Annual Parent Beta')
    
    plt.xlabel("Policy Maker's Discount Factor (beta_g)")
    plt.ylabel("Optimal Progressivity (tau)")
    plt.title("Figure 4: Government Altruism and Optimal Tax Progressivity")
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.savefig(save_path)
    plt.close()

def create_summary_table(config: EconomyConfig, 
                         bench_ss: Dict[str, Any], 
                         opt_ss: Dict[str, Any]) -> None:
    """
    Prints a formatted summary similar to Table 2 in the paper.
    Compares Status Quo vs Steady State Optimal.
    """
    print("\n" + "="*50)
    print("Table 2: Steady State Comparison")
    print("-" * 50)
    print(f"{'Metric':<25} | {'U.S. (Bench)':<10} | {'Optimal SS':<10}")
    print("-" * 50)
    
    def format_val(val: float, bench: float = None, is_gini: bool = False) -> str:
        if bench is not None:
            pct_change = (val / bench - 1.0) * 100.0
            return f"{val:>10.3f} ({pct_change:+.1f}%)"
        if is_gini:
            return f"({val:.3f})"
        return f"{val:>10.3f}"

    print(f"{'Progressivity (tau)':<25} | {bench_ss['lambda']*0 + config.tau_status_quo:>10.2f} | {config.tau_optimal_ss:>10.2f}")
    print(f"{'Interest rate (annual %)':<25} | {bench_ss['r_annual']*100:>10.2f} | {opt_ss['r_annual']*100:>10.2f}")
    print(f"{'Wage rate':<25} | {bench_ss['w']:>10.3f} | {opt_ss['w']:>10.3f}")
    print(f"{'Hours':<25} | {bench_ss['Hours']:>10.3f} | {opt_ss['Hours']:>10.3f}")
    print("-" * 50)
    print(f"{'Output (Y)':<25} | {format_val(bench_ss['Y'])} | {format_val(opt_ss['Y'], bench_ss['Y'])}")
    print(f"{'Pre-tax Income':<25} | {format_val(bench_ss['Y'])} | {format_val(opt_ss['Y'], bench_ss['Y'])}")
    print(f"{'  (Gini)':<25} | {format_val(bench_ss['gini_pre_tax'], is_gini=True)} | {format_val(opt_ss['gini_pre_tax'], is_gini=True)}")
    print(f"{'Wealth (K)':<25} | {format_val(bench_ss['K'])} | {format_val(opt_ss['K'], bench_ss['K'])}")
    print(f"{'  (Gini)':<25} | {format_val(bench_ss['gini_wealth'], is_gini=True)} | {format_val(opt_ss['gini_wealth'], is_gini=True)}")
    print(f"{'Consumption (C)':<25} | {format_val(bench_ss['C'])} | {format_val(opt_ss['C'], bench_ss['C'])}")
    print(f"{'  (Gini)':<25} | {format_val(bench_ss['gini_consumption'], is_gini=True)} | {format_val(opt_ss['gini_consumption'], is_gini=True)}")
    print("="*50 + "\n")
