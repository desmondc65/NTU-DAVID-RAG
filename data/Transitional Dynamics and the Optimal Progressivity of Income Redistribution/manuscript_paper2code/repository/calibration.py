## calibration.py
import numpy as np
from typing import Tuple, Any

"""
The calibration.py module is responsible for translating the empirical findings 
described in Section 3 of the paper into the numerical parameters and transition 
matrices required for the dynastic Aiyagari-Bewley-Huggett model.

It converts annual parameters to the model-period (5-year) equivalents, constructs 
the composite 4-state labor productivity process, and generates the capital grid.
"""

def calculate_z_states(f_states: np.ndarray, a_states: np.ndarray) -> np.ndarray:
    """
    Computes the 4-state discretized grid for labor efficiency z = exp(f + a).
    The states are ordered as:
    0: (f_L, a_L)
    1: (f_L, a_H)
    2: (f_H, a_L)
    3: (f_H, a_H)
    """
    z0 = np.exp(f_states[0] + a_states[0])
    z1 = np.exp(f_states[0] + a_states[1])
    z2 = np.exp(f_states[1] + a_states[0])
    z3 = np.exp(f_states[1] + a_states[1])
    return np.array([z0, z1, z2, z3], dtype=np.float64)

def calculate_transition_matrices(
    mu: float, 
    transition_f: np.ndarray, 
    transition_a_annual: np.ndarray, 
    pi_low: float, 
    period_years: int
) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Constructs the transition matrices S (survival), D (death/descendant), 
    and the aggregate transition matrix P = (1-mu)S + muD.
    
    Args:
        mu: Probability of death per period.
        transition_f: 2x2 intergenerational transition matrix F.
        transition_a_annual: 2x2 annual life-cycle transition matrix A.
        pi_low: Probability that a newborn starts in the low life-cycle state a_L.
        period_years: Number of years per model period (typically 5).
        
    Returns:
        (S, D, P): 4x4 transition matrices.
    """
    # 1. Survival Transition (S): f is fixed, a transitions via A^period_years
    # Matrix A governing life-cycle transitions over 5 years
    a_period = np.linalg.matrix_power(transition_a_annual, period_years)
    
    s_matrix = np.zeros((4, 4))
    # If parent was f_L (states 0, 1), they stay in f_L states [0, 1]
    s_matrix[0:2, 0:2] = a_period
    # If parent was f_H (states 2, 3), they stay in f_H states [2, 3]
    s_matrix[2:4, 2:4] = a_period

    # 2. Death/Descendant Transition (D): f transitions via F, a resets via pi
    # Rows represent parent's state, columns represent child's initial state
    d_matrix = np.zeros((4, 4))
    
    # Probabilities of child's life-cycle state
    p_a_child = np.array([pi_low, 1.0 - pi_low])
    
    # If parent was f_L (states 0 and 1)
    for i in [0, 1]:
        # Child gets f_L with prob transition_f[0,0]
        d_matrix[i, 0] = transition_f[0, 0] * p_a_child[0]
        d_matrix[i, 1] = transition_f[0, 0] * p_a_child[1]
        # Child gets f_H with prob transition_f[0,1]
        d_matrix[i, 2] = transition_f[0, 1] * p_a_child[0]
        d_matrix[i, 3] = transition_f[0, 1] * p_a_child[1]
        
    # If parent was f_H (states 2 and 3)
    for i in [2, 3]:
        # Child gets f_L with prob transition_f[1,0]
        d_matrix[i, 0] = transition_f[1, 0] * p_a_child[0]
        d_matrix[i, 1] = transition_f[1, 0] * p_a_child[1]
        # Child gets f_H with prob transition_f[1,1]
        d_matrix[i, 2] = transition_f[1, 1] * p_a_child[0]
        d_matrix[i, 3] = transition_f[1, 1] * p_a_child[1]

    # 3. Aggregate Transition (P)
    p_matrix = (1.0 - mu) * s_matrix + mu * d_matrix
    
    return s_matrix, d_matrix, p_matrix

def calculate_k_grid(
    k_min: float, 
    k_max: float, 
    k_size: int, 
    k_grid_exp: float
) -> np.ndarray:
    """
    Constructs an exponential grid for capital to capture non-linear 
    behavior near the borrowing constraint.
    """
    grid_lin = np.linspace(0.0, 1.0, k_size)
    grid_exp = grid_lin ** k_grid_exp
    return k_min + (k_max - k_min) * grid_exp

def apply_calibration(config: Any) -> None:
    """
    Populates specific attributes of the EconomyConfig object based on 
    the logic required for Section 3 of the paper.
    
    Args:
        config: An instance of EconomyConfig class defined in config.py.
    """
    # 1. 5-Year Time Conversion
    # beta_period = beta_annual ^ 5
    # The config.yaml value beta_annual is typically stored in preferences
    # and accessed during config initialization.
    # We ensure model-period values are set.
    
    # 2. Labor Productivity Grid
    config.z_states = calculate_z_states(
        f_states=config._f_states, 
        a_states=config._a_states
    )
    
    # 3. Transition Matrices
    s_mat, d_mat, p_mat = calculate_transition_matrices(
        mu=config.mu,
        transition_f=config._trans_f_raw,
        transition_a_annual=config._trans_a_annual,
        pi_low=config._pi_newborn_low,
        period_years=config.period_years
    )
    config.S_matrix = s_mat
    config.D_matrix = d_mat
    config.transition_matrix = p_mat
    
    # 4. Capital Grid
    config.k_grid = calculate_k_grid(
        k_min=config.k_min,
        k_max=config.k_max,
        k_size=config.k_size,
        k_grid_exp=config.k_grid_exp
    )
    
    # 5. Fixed ratio
    # g_y_ratio is already set from yaml via config initialization
    pass

def verify_calibration(config: Any) -> bool:
    """
    Performs basic sanity checks on the calibrated parameters.
    Returns True if parameters are within plausible bounds.
    """
    # Check if transition matrix is stochastic
    if not np.allclose(np.sum(config.transition_matrix, axis=1), 1.0):
        return False
        
    # Check if beta and delta are in [0, 1]
    if not (0.0 < config.beta < 1.0) or not (0.0 < config.delta < 1.0):
        return False
        
    # Check if capital grid is monotonic
    if not np.all(np.diff(config.k_grid) > 0):
        return False
        
    return True
