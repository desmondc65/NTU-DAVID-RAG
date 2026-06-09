#!/usr/bin/env bash
# Build the setup manual -> manual.pdf
set -euo pipefail
cd "$(dirname "$0")"

pdflatex -interaction=nonstopmode -halt-on-error manual.tex >/dev/null
pdflatex -interaction=nonstopmode -halt-on-error manual.tex >/dev/null   # 2nd pass: ToC
rm -f ./*.aux ./*.log ./*.out ./*.toc
echo "Built: manual.pdf"
