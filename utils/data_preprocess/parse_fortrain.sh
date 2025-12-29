#!/bin/bash

python3 utils/data_preprocess/fortran_parser.py \
    "data/Accounting for Wealth Concentration in the United States/codes_fortran" \
    -o "data/Accounting for Wealth Concentration in the United States/codes_fortran_json"

python3 utils/data_preprocess/fortran_parser.py \
    "data/Consumption Smoothing and Welfare Implications of Redistributive and Insurance Systems/codes_fortran" \
    -o "data/Consumption Smoothing and Welfare Implications of Redistributive and Insurance Systems/codes_fortran_json"

python3 utils/data_preprocess/fortran_parser.py \
    "data/The Welfare Implications of Top Marginal Tax Reform in Taiwan/codes_fortran" \
    -o "data/The Welfare Implications of Top Marginal Tax Reform in Taiwan/codes_fortran_json"