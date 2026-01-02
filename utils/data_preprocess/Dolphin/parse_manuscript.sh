#!/bin/bash

# Change to the Dolphin directory
cd "$(dirname "$0")"

# Activate virtual environment
source .venv/bin/activate

# python3 ./demo_page.py --model_path ./hf_model/ \
#     --save_dir "/home/desmond/Documents/econs_rag/NTU-DAVID-RAG/data/Consumption Smoothing and Welfare Implications of Redistributive and Insurance Systems/manuscript_parsed_dolphin" \
#     --input_path "/home/desmond/Documents/econs_rag/NTU-DAVID-RAG/data/Consumption Smoothing and Welfare Implications of Redistributive and Insurance Systems/Manuscript.pdf"

python3 ./demo_page.py --model_path ./hf_model/ \
    --save_dir "/home/desmond/Documents/econs_rag/NTU-DAVID-RAG/data/The Welfare Implications of Top Marginal Tax Reform in Taiwan/manuscript_parsed_dolphin" \
    --input_path "/home/desmond/Documents/econs_rag/NTU-DAVID-RAG/data/The Welfare Implications of Top Marginal Tax Reform in Taiwan/Manuscript.pdf"