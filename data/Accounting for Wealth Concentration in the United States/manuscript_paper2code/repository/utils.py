## utils.py
import numpy as np
from numba import njit, prange
from scipy import optimize
from typing import Callable, Tuple, Any

@njit(cache=True)
def interp_1d(x_grid: np.ndarray, y_vals: np.ndarray, x_query: float) -> float:
    """
    Numba-accelerated linear interpolation for a 1D grid.
    
    Args:
        x_grid: Monotonically increasing grid points.
        y_vals: Values at grid points.
        x_query: Point to evaluate.
        
    Returns:
        Interpolated value. Linear extrapolation is used for out-of-bounds.
    """
    n = len(x_grid)
    
    # Handle boundaries
    if x_query <= x_grid[0]:
        # Linear extrapolation at the bottom
        slope = (y_vals[1] - y_vals[0]) / (x_grid[1] - x_grid[0])
        return y_vals[0] + slope * (x_query - x_grid[0])
    if x_query >= x_grid[n - 1]:
        # Linear extrapolation at the top
        slope = (y_vals[n - 1] - y_vals[n - 2]) / (x_grid[n - 1] - x_grid[n - 2])
        return y_vals[n - 1] + slope * (x_query - x_grid[n - 1])
    
    # Binary search for interval
    idx = np.searchsorted(x_grid, x_query) - 1
    
    # Linear interpolation formula
    x0, x1 = x_grid[idx], x_grid[idx + 1]
    y0, y1 = y_vals[idx], y_vals[idx + 1]
    
    weight = (x_query - x0) / (x1 - x0)
    return y0 + weight * (y1 - y0)

@njit(cache=True)
def make_grid(k_min: float, k_max: float, n_k: int, power: float = 3.0) -> np.ndarray:
    """
    Creates a non-linearly spaced grid for assets, denser near the lower bound.
    
    Args:
        k_min: Minimum asset level.
        k_max: Maximum asset level.
        n_k: Number of grid points.
        power: Curvature of the grid (1.0 is linear, >1.0 is more dense near k_min).
        
    Returns:
        np.ndarray: The asset grid.
    """
    grid = np.linspace(0.0, 1.0, n_k) ** power
    return k_min + (k_max - k_min) * grid

@njit(cache=True)
def phi_function(k_prime: float, phi1: float, phi2: float, sigma_b: float) -> float:
    """
    Calculates the utility value of bequeathed assets (non-homothetic motive).
    Equation: phi(k') = phi1 * [ (k' + phi2)^(1 - sigma_b) - 1 ] / (1 - sigma_b)
    Note: The 1-sigma_b denominator is standard for power utility to maintain 
    consistent curvature behavior.
    
    Args:
        k_prime: Assets left as bequest.
        phi1: Overall altruism parameter.
        phi2: Non-homotheticity parameter (luxury good threshold).
        sigma_b: Curvature of bequest utility.
        
    Returns:
        Utility value.
    """
    # Safety check for power utility domain
    base = k_prime + phi2
    if base <= 0:
        return -1e10 # Large penalty
        
    return phi1 * (base**(1.0 - sigma_b) - 1.0) / (1.0 - sigma_b)

@njit(cache=True)
def get_disposable_income(market_income: float, lmbda: float, tau: float, max_rate: float) -> float:
    """
    Calculates after-tax income using the log-linear progressivity function.
    Matches the specification in Section IV.E of the paper.
    
    Args:
        market_income: Pre-tax market income.
        lmbda: Scale parameter (lambda).
        tau: Progressivity parameter (tau).
        max_rate: Maximum marginal tax rate cap.
        
    Returns:
        Disposable income.
    """
    if market_income <= 0:
        return 0.0
    
    # y_d = min(lambda * y^(1-tau), (1 - max_rate) * y)
    progressive_income = lmbda * (market_income ** (1.0 - tau))
    capped_income = (1.0 - max_rate) * market_income
    
    return min(progressive_income, capped_income)

@njit(cache=True)
def compute_expected_value(k_prime: float, 
                           v_next: np.ndarray, 
                           pi_z_row: np.ndarray, 
                           pi_kappa_z: np.ndarray, 
                           k_grid: np.ndarray) -> float:
    """
    Computes the expected continuation value over next period's stochastic states.
    
    Args:
        k_prime: Savings choice.
        v_next: Value function for period j+1, shape (n_k, n_z, n_kappa).
        pi_z_row: Transition probabilities for labor z (row of Pi_z).
        pi_kappa_z: Transition probabilities for returns kappa (conditional on z).
        k_grid: Asset grid.
        
    Returns:
        Expected value.
    """
    n_z = v_next.shape[1]
    n_kappa = v_next.shape[2]
    
    ev = 0.0
    # Iterate over future productivity states z'
    for izp in range(n_z):
        prob_z = pi_z_row[izp]
        if prob_z <= 0:
            continue
            
        # Iterate over future return states kappa'
        # The return process can depend on the current or future z as per paper logic
        for ikp in range(n_kappa):
            prob_k = pi_kappa_z[ikp]
            if prob_k <= 0:
                continue
            
            # Interpolate value at k_prime for state (izp, ikp)
            v_interp = interp_1d(k_grid, v_next[:, izp, ikp], k_prime)
            ev += prob_z * prob_k * v_interp
            
    return ev

def solve_root_brentq(func: Callable[[float], float], 
                      lower: float, 
                      upper: float, 
                      xtol: float = 1e-6) -> float:
    """
    Wrapper for Scipy's BrentQ root finder, often used for interest rate (r) iteration.
    
    Args:
        func: The objective function (e.g., Excess Capital Demand).
        lower: Lower bound of search.
        upper: Upper bound of search.
        xtol: Tolerance.
        
    Returns:
        The root value.
    """
    try:
        root = optimize.brentq(func, lower, upper, xtol=xtol)
        return root
    except ValueError as e:
        print(f"BrentQ failed: {e}. Check bounds [{lower}, {upper}].")
        # Return mid-point as fallback or re-raise
        raise e

def calculate_gini(values: np.ndarray, weights: np.ndarray = None) -> float:
    """
    Calculates the Gini coefficient for a distribution.
    
    Args:
        values: Data values.
        weights: Population weights (optional).
        
    Returns:
        Gini coefficient.
    """
    if weights is None:
        weights = np.ones_like(values)
        
    # Sort values
    idx = np.argsort(values)
    values = values[idx]
    weights = weights[idx]
    
    # Weighted Gini
    cum_weights = np.cumsum(weights)
    sum_weights = cum_weights[-1]
    
    # Lorenz curve components
    lorenz_y = np.cumsum(values * weights)
    sum_y = lorenz_y[-1]
    
    if sum_y == 0:
        return 0.0
        
    lorenz_y /= sum_y
    cum_weights /= sum_weights
    
    # Area under Lorenz curve
    # Use trapezoidal rule
    area = 0.0
    for i in range(1, len(values)):
        area += 0.5 * (lorenz_y[i] + lorenz_y[i-1]) * (cum_weights[i] - cum_weights[i-1])
        
    return 1.0 - 2.0 * area

def calculate_top_share(values: np.ndarray, weights: np.ndarray, top_pct: float) -> float:
    """
    Calculates the wealth or income share of the top X percentile.
    
    Args:
        values: Data values.
        weights: Population weights.
        top_pct: Percentile (e.g., 0.01 for top 1%).
        
    Returns:
        Share of total.
    """
    idx = np.argsort(values)
    values = values[idx]
    weights = weights[idx]
    
    total_val = np.sum(values * weights)
    total_pop = np.sum(weights)
    
    # Cumulative population from top down
    cum_pop_top = np.cumsum(weights[::-1]) / total_pop
    
    # Find index where cumulative population exceeds top_pct
    cut_idx = np.searchsorted(cum_pop_top, top_pct)
    
    # Values are sorted ascending, so we take the last N elements
    top_values = values[len(values)-cut_idx:]
    top_weights = weights[len(weights)-cut_idx:]
    
    return np.sum(top_values * top_weights) / total_val
