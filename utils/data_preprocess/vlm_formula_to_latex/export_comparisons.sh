#!/bin/bash

# Export all quality comparison HTMLs to a single shareable directory

# Determine the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
DATA_DIR="${PROJECT_ROOT}/data"
EXPORT_DIR="${PROJECT_ROOT}/formula_quality_comparisons"

# Create export directory
mkdir -p "$EXPORT_DIR"

echo "Exporting quality comparison HTMLs..."
echo "Export directory: $EXPORT_DIR"
echo ""

# Counter
count=0

# Find all comparison.html files
for html_file in "$DATA_DIR"/*/vlm_formula_latex/quality_comparison/comparison.html; do
    if [ -f "$html_file" ]; then
        # Get paper name from path
        paper_dir=$(dirname $(dirname $(dirname "$html_file")))
        paper_name=$(basename "$paper_dir")
        
        # Create safe filename (replace spaces with underscores)
        safe_name=$(echo "$paper_name" | tr ' ' '_' | tr -cd '[:alnum:]_-')
        
        # Copy HTML file with paper name
        cp "$html_file" "$EXPORT_DIR/${safe_name}_comparison.html"
        
        echo "✓ Exported: ${safe_name}_comparison.html"
        ((count++))
    fi
done

echo ""
echo "=================================================="
echo "Export complete!"
echo "Total files exported: $count"
echo "Location: $EXPORT_DIR"
echo ""
echo "To share with others:"
echo "1. Zip the folder: cd '$PROJECT_ROOT' && zip -r formula_comparisons.zip formula_quality_comparisons/"
echo "2. Share the zip file via email, cloud storage, etc."
echo "3. Recipients can extract and open any HTML file in their browser"
echo "=================================================="
