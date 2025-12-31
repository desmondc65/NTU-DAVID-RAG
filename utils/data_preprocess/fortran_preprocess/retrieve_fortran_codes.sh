#!/bin/bash

python3 utils/data_preprocess/remove_non_fortran.py "data/drive-download-20251228T091828Z-3-001/Accounting for Wealth Concentration in the United States/coding" \
    -o "data/drive-download-20251228T091828Z-3-001/Accounting for Wealth Concentration in the United States/codes_fortran" 


python3 utils/data_preprocess/remove_non_fortran.py "data/drive-download-20251228T091828Z-3-001/Consumption Smoothing and Welfare Implications of Redistributive and Insurance Systems/coding" \
    -o "data/drive-download-20251228T091828Z-3-001/Consumption Smoothing and Welfare Implications of Redistributive and Insurance Systems/codes_fortran"

python3 utils/data_preprocess/remove_non_fortran.py "data/drive-download-20251228T091828Z-3-001/The Welfare Implications of Top Marginal Tax Reform in Taiwan" \
    -o "data/drive-download-20251228T091828Z-3-001/The Welfare Implications of Top Marginal Tax Reform in Taiwan/codes_fortran"