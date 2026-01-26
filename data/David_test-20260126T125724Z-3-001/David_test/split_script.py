import os
import re

def split_fortran_code():
    # Configuration
    source_file = 'main_code.f90'
    output_dir = 'RAG_Chunks'
    os.makedirs(output_dir, exist_ok=True)

    # Dictionary of summaries for File 6 (Analysis Stats)
    # Keys must be lowercase to match robustly
    subroutine_summaries = {
        "profile01": "Calculates longitudinal and cross-sectional age profiles for assets, labor, and income.",
        "wealthshare": "Computes the share of total wealth held by various percentiles of the population.",
        "compute_gini": "Calculates the Gini coefficient for wealth inequality.",
        "age_wealth_gini": "Calculates the Gini coefficient for wealth within specific age cohorts.",
        "wageshare": "Computes the distribution and share of labor income (wages) across the population.",
        "totalincomeshare": "Computes the distribution of total income (labor + capital + transfers).",
        "consumptionshare": "Computes the distribution of consumption expenditures across the population.",
        "avg_return_wealthgroups": "Calculates the average rate of return on assets for different wealth quantiles.",
        "skewness": "Calculates the statistical skewness of the wealth and earnings distributions.",
        "age_partition": "Analyzes economic variables (wealth, income) partitioned by age group.",
        "income_partition": "Analyzes wealth and consumption partitioned by income deciles.",
        "bequest": "Calculates aggregate statistics and distribution metrics for bequests.",
        "joint_dist": "Computes the joint distribution of income and wealth or other paired variables.",
        "tax_moment": "Calculates aggregate tax revenue and effective tax rates from the model.",
        "correlation": "Computes correlation coefficients between key economic variables (e.g., income vs wealth).",
        "calidiff": "Computes the sum of squared errors between model moments and calibration targets.",
        "beq_distribution": "Computes the detailed probability distribution of bequests received by agents.",
        "avg_return": "Calculates the aggregate average return and asset-weighted average return on capital.",
        "avg_return_incomegroups": "Calculates the average rate of return for different income groups.",
        "top_shares_age_partition": "Analyzes the age composition of individuals in the top wealth/income shares.",
        "earnings_growth_moments": "Calculates the mean, standard deviation, skewness, and kurtosis of earnings growth.",
        "intergenerational": "Computes intergenerational correlations for wealth and income status.",
        "bequest_exemption": "Computes the threshold for the top 2% bequest tax exemption.",
        "income_partition_sort_by_wealth": "Analyzes income metrics when the population is sorted by wealth ranking."
    }

    # Allocation of subroutines to specific files
    # Keys are filenames, Values are lists of subroutine names (lowercase)
    file_allocations = {
        '02_Policy_Solvers.f90': [
            'srchfive01', 'a_srchfive01', 'n_srchfive01', 
            'bracket01', 'check_bracket01', 'utility'
        ],
        '03_Policy_Iterator.f90': [
            'decrule01'
        ],
        '04_Distribution_Calc.f90': [
            'invar01', 'compute_distributions'
        ]
        # '05_Analysis_Stats.f90' will act as the 'else' bucket
    }

    print(f"Reading {source_file}...")
    try:
        with open(source_file, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"Error: {source_file} not found in the current directory.")
        return

    # --- Step 1: Split Global Context vs Subroutines (at CONTAINS) ---
    # We look for the main CONTAINS that separates the Program scope from Subroutines.
    # Regex looks for CONTAINS on its own line, ignoring comments/whitespace.
    split_match = re.search(r'\n\s*CONTAINS\s*\n', content, re.IGNORECASE)
    
    if not split_match:
        print("Error: Could not find the main 'CONTAINS' statement to split the file.")
        return

    main_program_block = content[:split_match.start()]
    subroutine_block = content[split_match.end():]

    # --- Step 2: Split 00_Global_Context and 01_Main_Driver ---
    # We look for the specific comment block indicating the start of the Logic/Loop
    driver_marker = "!**********************************\n! 	Solve the General Equilibrium"
    
    if driver_marker in main_program_block:
        parts = main_program_block.split(driver_marker)
        chunk_00 = parts[0]
        chunk_01 = driver_marker + parts[1]
    else:
        # Fallback split point if exact comment isn't found
        fallback_marker = "SELECT CASE (compute_eqm)"
        if fallback_marker in main_program_block:
            parts = main_program_block.split(fallback_marker)
            chunk_00 = parts[0]
            chunk_01 = fallback_marker + parts[1]
        else:
            print("Warning: Could not find split point for Main Driver. Saving all to 00.")
            chunk_00 = main_program_block
            chunk_01 = "! [Main Driver logic not identified separately]"

    # Save 00 and 01
    with open(os.path.join(output_dir, '00_Global_Context.f90'), 'w') as f:
        f.write(chunk_00.strip() + "\n")
    with open(os.path.join(output_dir, '01_Main_Driver.f90'), 'w') as f:
        f.write(chunk_01.strip() + "\n")

    # --- Step 3: Parse and Sort Subroutines ---
    # Regex to capture SUBROUTINE or FUNCTION blocks
    # Captures: 1=Recursive?, 2=Type, 3=Name
    start_re = re.compile(r'^\s*(RECURSIVE\s+)?(SUBROUTINE|FUNCTION)\s+([A-Za-z0-9_]+)', re.IGNORECASE)
    end_re = re.compile(r'^\s*END\s+(SUBROUTINE|FUNCTION)', re.IGNORECASE)

    lines = subroutine_block.splitlines()
    
    extracted_routines = {} # Name -> Code
    current_code = []
    current_name = None
    in_routine = False

    for line in lines:
        if not in_routine:
            match = start_re.match(line)
            if match:
                in_routine = True
                current_name = match.group(3).lower()
                current_code = [line]
        else:
            current_code.append(line)
            if end_re.match(line):
                in_routine = False
                extracted_routines[current_name] = "\n".join(current_code)
                current_name = None
                current_code = []

    # --- Step 4: Allocate and Inject Comments ---
    chunks_content = {
        '02_Policy_Solvers.f90': [],
        '03_Policy_Iterator.f90': [],
        '04_Distribution_Calc.f90': [],
        '05_Analysis_Stats.f90': []
    }

    count = 0
    for name, code in extracted_routines.items():
        count += 1
        assigned_file = None
        
        # Check specific allocations
        for filename, names_list in file_allocations.items():
            if name in names_list:
                assigned_file = filename
                break
        
        # Default to 05 if not assigned
        if not assigned_file:
            assigned_file = '05_Analysis_Stats.f90'

        # Inject Summary ONLY for File 05
        if assigned_file == '05_Analysis_Stats.f90':
            summary = subroutine_summaries.get(name, f"Calculates metrics related to {name}.")
            
            # Injection Logic: Insert before the definition line
            code_lines = code.splitlines()
            # Find the index of the SUBROUTINE line
            insert_idx = 0
            for i, l in enumerate(code_lines):
                if start_re.match(l):
                    insert_idx = i
                    break
            
            injection_block = (
                f"! [SUBROUTINE SUMMARY]\n"
                f"! FUNCTION: {name}\n"
                f"! DESCRIPTION: {summary}\n"
                f"! ---------------------------------------------------"
            )
            code_lines.insert(insert_idx, injection_block)
            code = "\n".join(code_lines)

        chunks_content[assigned_file].append(code)

    # --- Step 5: Save Remaining Files ---
    for filename, blocks in chunks_content.items():
        filepath = os.path.join(output_dir, filename)
        with open(filepath, 'w') as f:
            f.write("\n\n".join(blocks))
        print(f"Saved {filename} ({len(blocks)} subroutines)")

    print(f"\nProcessing complete. Processed {count} subroutines.")

if __name__ == "__main__":
    split_fortran_code()