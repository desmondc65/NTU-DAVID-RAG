#!/usr/bin/env bash
# Build the technical report -> main.pdf
# Requires the figures in ../drawings (run ../drawings/build.sh first).
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f ../drawings/rag_pipeline.pdf ] || [ ! -f ../drawings/rag_deployment.pdf ]; then
    echo "Figures missing — building them first..."
    ( cd ../drawings && ./build.sh )
fi

pdflatex -interaction=nonstopmode -halt-on-error main.tex >/dev/null
pdflatex -interaction=nonstopmode -halt-on-error main.tex >/dev/null   # 2nd pass: ToC + refs
rm -f ./*.aux ./*.log ./*.out ./*.toc
echo "Built: main.pdf"
