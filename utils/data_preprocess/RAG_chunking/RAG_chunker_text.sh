#!/bin/bash

# Define the base directory relative to the script execution location (assuming run from project root)
# Or absolute path. Let's assume running from project root /home/desmond/Documents/econs_rag/NTU-DAVID-RAG
DATA_DIR="data"
SCRIPT_PATH="utils/data_preprocess/RAG_chunking/RAG_chunker_text.py"

# Check if the python script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Error: Python script not found at $SCRIPT_PATH"
    echo "Please run this script from the project root directory."
    exit 1
fi

echo "Starting RAG chunking process..."
echo "Searching for 'Manuscript_parsed_docling.md' files in '$DATA_DIR'..."

# Find all Manuscript_parsed_docling.md files
find "$DATA_DIR" -name "Manuscript_parsed_docling.md" | while read -r input_file; do
    echo "---------------------------------------------------"
    echo "Found manuscript: $input_file"
    
    # Get the directory containing the manuscript (e.g., .../manuscript_parsed_docling)
    manuscript_dir=$(dirname "$input_file")
    
    # Get the paper directory (parent of manuscript_dir)
    paper_dir=$(dirname "$manuscript_dir")
    
    # Define the new RAG_data directory path
    rag_data_dir="$paper_dir/RAG_data"
    
    # Create the RAG_data directory if it doesn't exist
    if [ ! -d "$rag_data_dir" ]; then
        echo "Creating directory: $rag_data_dir"
        mkdir -p "$rag_data_dir"
    fi
    
    # Define the output file path
    output_file="$rag_data_dir/manuscript_chunks.jsonl"
    
    echo "Processing..."
    # Call the Python script with input and output paths
    python3 "$SCRIPT_PATH" "$input_file" "$output_file"
    
    # Check if the python script executed successfully
    if [ $? -eq 0 ]; then
        echo "Success: Output saved to $output_file"
    else
        echo "Error: Failed to process $input_file"
    fi
done

echo "---------------------------------------------------"
echo "Batch processing complete."
