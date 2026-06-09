#!/usr/bin/env bash
# Build all TikZ drawings -> PDF + transparent PNG (300 dpi).
# Usage: ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

DPI=300
for tex in *.tex; do
    base="${tex%.tex}"
    echo "==> $base"
    pdflatex -interaction=nonstopmode -halt-on-error "$tex" >/dev/null
    # transparent-background PNG via Ghostscript's pngalpha device
    gs -dSAFER -dBATCH -dNOPAUSE -sDEVICE=pngalpha -r"$DPI" \
       -o "${base}.png" "${base}.pdf" >/dev/null
    echo "    ${base}.pdf  ${base}.png"
done

# tidy LaTeX aux files
rm -f ./*.aux ./*.log
echo "Done."
