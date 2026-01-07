#!/bin/bash

# Change to the Dolphin directory
cd "$(dirname "$0")"

# Activate virtual environment
source .venv/bin/activate

# python3 ./demo_page.py --model_path ./hf_model/ \
#     --save_dir "/home/desmond/Documents/econs_rag/NTU-DAVID-RAG/data/Consumption Smoothing and Welfare Implications of Redistributive and Insurance Systems/manuscript_parsed_dolphin" \
#     --input_path "/home/desmond/Documents/econs_rag/NTU-DAVID-RAG/data/Consumption Smoothing and Welfare Implications of Redistributive and Insurance Systems/Manuscript.pdf"

# python3 ./demo_page.py --model_path ./hf_model/ \
#     --save_dir "/home/desmond/Documents/econs_rag/NTU-DAVID-RAG/data/The Welfare Implications of Top Marginal Tax Reform in Taiwan/manuscript_parsed_dolphin" \
#     --input_path "/home/desmond/Documents/econs_rag/NTU-DAVID-RAG/data/The Welfare Implications of Top Marginal Tax Reform in Taiwan/Manuscript.pdf"

python3 ./demo_page.py --model_path ./hf_model/ \
    --save_dir "/home/desmond/Documents/econs_rag/NTU-DAVID-RAG/data/The Joint Labor Supply Decision of Married Couples and the Social Security Pension System/manuscript_parsed_dolphin" \
    --input_path "/home/desmond/Documents/econs_rag/NTU-DAVID-RAG/data/The Joint Labor Supply Decision of Married Couples and the Social Security Pension System/The Joint Labor Supply Decision of Married Couples and the Social Security Pension System (published).pdf"

python3 ./demo_page.py --model_path ./hf_model/ \
    --save_dir "/home/desmond/Documents/econs_rag/NTU-DAVID-RAG/data/Transitional Dynamics and the Optimal Progressivity of Income Redistribution/manuscript_parsed_dolphin" \
    --input_path "/home/desmond/Documents/econs_rag/NTU-DAVID-RAG/data/Transitional Dynamics and the Optimal Progressivity of Income Redistribution/Transitional dynamics and the optimal progressivity of redistribution.pdf"