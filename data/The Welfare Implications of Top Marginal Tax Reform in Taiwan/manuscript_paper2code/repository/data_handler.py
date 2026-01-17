## data_handler.py
import numpy as np
import pandas as pd
import yaml
import statsmodels.api as sm
from scipy.interpolate import interp1d
from typing import Dict, Any, List, Optional

class DataHandler:
    """
    Handles the empirical estimation and data processing required for the 
    Taiwanese life-cycle model. 
    
    This includes:
    1. Estimating Benabou tax progressivity parameters from HIES data.
    2. Processing survival probabilities from life tables.
    3. Generating age-efficiency profiles for labor productivity.
    """

    def __init__(self, config_path: str = "config.yaml"):
        """
        Initializes the DataHandler with configuration settings.
        
        Args:
            config_path: Path to the config.yaml file.
        """
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
            
        self.J: int = self.config['demographics']['total_periods']
        self.Jr: int = self.config['demographics']['retirement_period']
        self.period_len: int = self.config['demographics']['period_length']
        self.hies_df: Optional[pd.DataFrame] = None

    def load_hies_data(self, path: str) -> pd.DataFrame:
        """
        Loads and cleans household-level data from the Household Income and 
        Expenditure Survey (HIES).
        
        Args:
            path: Path to the data file (e.g., CSV or Parquet) containing 
                  multi-year HIES records (2014-2021).
                  
        Returns:
            A cleaned pandas DataFrame formatted for tax estimation.
        """
        # In a real-world scenario, this would load CSV/Stata files.
        # Here we define the logic for cleaning as described in Section 3.4.
        try:
            df = pd.read_csv(path)
        except FileNotFoundError:
            # Fallback/Placeholder if specific file not found for reproduction
            print(f"Warning: {path} not found. Returning empty structure for interface consistency.")
            return pd.DataFrame(columns=['household_type', 'pre_tax_income', 'tax_paid', 'disposable_income'])

        # 1. Selection: Focus on Single-person and Married core households
        # Mapping depends on HIES classification codes mentioned in the paper
        # Household type 1: Single, Type 2 & 4: Married/Core
        selection = df['household_type'].isin([1, 2, 4])
        df = df[selection].copy()

        # 2. Data Cleaning: Remove missing or non-positive tax/income data
        # Section 3.4: 'We removed households with tax amounts less than or equal to zero.'
        df = df[df['tax_paid'] > 0]
        df = df[df['pre_tax_income'] > 0]

        # 3. Calculate Disposable Income
        df['disposable_income'] = df['pre_tax_income'] - df['tax_paid']
        
        self.hies_df = df
        return df

    def estimate_tax_parameters(self) -> Dict[str, float]:
        """
        Estimates the Benabou (2002) tax progressivity parameters (tau, lambda)
        using OLS regression on HIES data.
        
        Logic: log(y_d) = log(lambda) + (1 - tau) * log(y)
        
        Returns:
            Dictionary containing estimated tau and lambda for single and married.
        """
        if self.hies_df is None:
            # If no data loaded, return calibrated values from config as default
            return {
                'tau_s': self.config['taxation']['progressivity']['single'],
                'tau_m': self.config['taxation']['progressivity']['married'],
                'lambda_s': 0.899, # Default targets to yield 10.1% avg tax
                'lambda_m': 0.855  # Default targets to yield 14.1% avg tax
            }

        results = {}
        for h_type in ['single', 'married']:
            # Filter by type
            type_code = 1 if h_type == 'single' else [2, 4]
            if h_type == 'single':
                sub_df = self.hies_df[self.hies_df['household_type'] == type_code].copy()
            else:
                sub_df = self.hies_df[self.hies_df['household_type'].isin(type_code)].copy()

            # 1. Partition into income brackets (deciles or as per Section 3.4)
            sub_df['bracket'] = pd.qcut(sub_df['pre_tax_income'], 100, duplicates='drop')
            bracket_data = sub_df.groupby('bracket', observed=True).agg({
                'pre_tax_income': 'mean',
                'disposable_income': 'mean'
            }).dropna()

            # 2. Prepare log-variables for OLS
            log_y = np.log(bracket_data['pre_tax_income'])
            log_yd = np.log(bracket_data['disposable_income'])
            
            # 3. OLS Regression: log(yd) = alpha + beta * log(y)
            X = sm.add_constant(log_y)
            model = sm.OLS(log_yd, X).fit()
            
            intercept = model.params['const']
            beta = model.params['pre_tax_income']
            
            tau_est = 1.0 - beta
            lambda_est = np.exp(intercept)
            
            # Store results
            results[f'tau_{h_type[0]}'] = tau_est
            results[f'lambda_{h_type[0]}'] = lambda_est

        return results

    def get_survival_probs(self) -> np.ndarray:
        """
        Processes 5-year survival probabilities based on Ministry of Interior 
        Life Tables (2009-2011).
        
        Returns:
            A (2, 15) numpy array: [0,:] for males, [1,:] for females.
        """
        # Array structure: rows (0=Male, 1=Female), cols (1 to 15 periods)
        s_probs = np.ones((2, self.J), dtype=np.float64)

        # Section 2.1: "During the working phase, survival is guaranteed"
        # Ages 25 to 64 (Periods 1 to 8 inclusive) -> probs = 1.0 (already default)

        # Retirement phase (Ages 65 to 99, Periods 9 to 15)
        # Probabilities calculated as 5-year conditional survival 
        # based on Ministry of Interior Life Table 2009-2011.
        
        # Approximate 5-year survival rates for retired cohorts in Taiwan:
        # P9 (65-69), P10 (70-74), P11 (75-79), P12 (80-84), P13 (85-89), P14 (90-94), P15 (95-99)
        male_retired_survival = [0.96, 0.92, 0.85, 0.75, 0.60, 0.40, 0.0]
        female_retired_survival = [0.98, 0.96, 0.91, 0.83, 0.72, 0.55, 0.0]

        # Fill retirement indices (8 to 14 in 0-based indexing)
        s_probs[0, self.Jr-1:] = male_retired_survival
        s_probs[1, self.Jr-1:] = female_retired_survival
        
        # Explicitly set last period survival to zero
        s_probs[:, -1] = 0.0

        return s_probs

    def get_age_efficiency_profiles(self) -> np.ndarray:
        """
        Generates deterministic age-efficiency profiles (epsilon) from Ministry 
        of Labor wage data.
        
        Returns:
            A (2, 15) numpy array: [0,:] for males, [1,:] for females.
        """
        # Age bins for raw data from Ministry of Labor (Figure 2)
        # Bins: 25-29, 30-34, 35-39, 40-44, 45-49, 50-54, 55-59, 60-64
        ages_raw = np.arange(27, 65, 5) # Mid-points of raw data bins
        
        # Efficiency values estimated from Figure 2: Age-Specific Labor Efficiency
        raw_male_eff = [0.85, 1.02, 1.15, 1.25, 1.28, 1.25, 1.15, 1.00]
        raw_female_eff = [0.82, 0.95, 1.05, 1.08, 1.06, 1.00, 0.90, 0.80]

        # Extended profiles for retirement (efficiency drops to 0 after retirement)
        all_ages = np.arange(27, 27 + 15 * 5, 5)
        
        epsilon = np.zeros((2, self.J), dtype=np.float64)
        
        # Interpolation / Fitting for working periods (1-8)
        f_m = interp1d(ages_raw, raw_male_eff, kind='cubic', fill_value="extrapolate")
        f_f = interp1d(ages_raw, raw_female_eff, kind='cubic', fill_value="extrapolate")
        
        working_ages = all_ages[:self.Jr-1]
        epsilon[0, :self.Jr-1] = f_m(working_ages)
        epsilon[1, :self.Jr-1] = f_f(working_ages)
        
        # Retirement periods (efficiency = 0)
        epsilon[:, self.Jr-1:] = 0.0
        
        # Normalize profiles to target Gender Wage Gap of 0.84 (Table 3)
        # Average efficiency ratio (Female/Male) should be 0.84
        mean_m = np.mean(epsilon[0, :self.Jr-1])
        mean_f = np.mean(epsilon[1, :self.Jr-1])
        current_gap = mean_f / mean_m
        
        target_gap = 0.84
        adjustment_factor = target_gap / current_gap
        epsilon[1, :] *= adjustment_factor
        
        # Final safety normalization: overall male average = 1.0
        scale = 1.0 / np.mean(epsilon[0, :self.Jr-1])
        epsilon *= scale

        return epsilon

    def get_pop_weights(self, s_probs: np.ndarray) -> np.ndarray:
        """
        Calculates the stationary population distribution (weights) across 
        age cohorts based on survival probabilities.
        
        Args:
            s_probs: Survival probabilities (2, J).
            
        Returns:
            A (15,) array of population shares by cohort.
        """
        # Average survival across genders
        s_avg = np.mean(s_probs, axis=0)
        
        weights = np.zeros(self.J)
        weights[0] = 1.0 # Base cohort size
        for j in range(1, self.J):
            weights[j] = weights[j-1] * s_avg[j-1]
            
        # Normalize sum to 1.0
        weights /= np.sum(weights)
        return weights

