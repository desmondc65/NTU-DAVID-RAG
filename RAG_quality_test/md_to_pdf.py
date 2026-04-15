#!/usr/bin/env python3
"""Convert the RAG quality-test markdown result into a PDF with rendered LaTeX,
no header/footer, and a page break before every question section."""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import markdown


MATHJAX = r"""
<script>
window.MathJax = {
  tex: {
    inlineMath: [['$', '$'], ['\\(', '\\)']],
    displayMath: [['$$', '$$'], ['\\[', '\\]']],
    processEscapes: true,
    processEnvironments: true
  },
  svg: { fontCache: 'global' },
  startup: {
    ready: () => {
      MathJax.startup.defaultReady();
      MathJax.startup.promise.then(() => { window.__mathjaxDone = true; });
    }
  }
};
</script>
<script id="MathJax-script" async
  src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
"""


CSS = r"""
@page { size: A4; margin: 18mm 16mm; }
html, body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
               "Helvetica Neue", Arial, sans-serif;
  font-size: 11pt;
  line-height: 1.45;
  color: #111;
}
h1 { font-size: 20pt; margin: 0 0 8pt 0; }
h2 { font-size: 15pt; margin-top: 12pt; }
h3 { font-size: 12pt; margin-top: 10pt; }
code, pre { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
pre {
  background: #f6f8fa;
  border: 1px solid #e5e7eb;
  padding: 8px 10px;
  border-radius: 4px;
  font-size: 9.5pt;
  white-space: pre-wrap;
  word-break: break-word;
}
code { background: #f6f8fa; padding: 1px 4px; border-radius: 3px; font-size: 90%; }
pre code { background: transparent; padding: 0; }
table { border-collapse: collapse; margin: 6pt 0; }
th, td { border: 1px solid #d0d7de; padding: 4px 8px; font-size: 10pt; }
th { background: #f6f8fa; }
blockquote {
  border-left: 3px solid #d0d7de;
  margin: 4pt 0;
  padding: 2pt 10pt;
  color: #444;
  background: #fafbfc;
}
hr { border: none; border-top: 1px solid #d0d7de; margin: 10pt 0; }
a { color: #0366d6; text-decoration: none; }
ul, ol { padding-left: 22px; }

/* Break before every question section */
h2[id^="q-"], a[id^="q-"] { page-break-before: always; break-before: page; }
/* Don't break right after a heading */
h1, h2, h3 { page-break-after: avoid; break-after: avoid-page; }
/* Avoid splitting small blocks */
pre, table, blockquote { page-break-inside: avoid; break-inside: avoid; }

/* MathJax display math shouldn't overflow */
mjx-container[display="true"] { overflow-x: auto; overflow-y: hidden; }
"""


def md_to_html(md_text: str) -> str:
    # Protect math so markdown doesn't mangle underscores/asterisks inside.
    placeholders = {}

    def stash(match):
        key = f"@@MATH{len(placeholders)}@@"
        placeholders[key] = match.group(0)
        return key

    # $$...$$ (possibly multi-line)
    md_text = re.sub(r"\$\$[\s\S]+?\$\$", stash, md_text)
    # \[...\]
    md_text = re.sub(r"\\\[[\s\S]+?\\\]", stash, md_text)
    # Inline $...$ (non-greedy, single line, avoid $$)
    md_text = re.sub(r"(?<!\$)\$(?!\$)([^\n$]+?)(?<!\$)\$(?!\$)", stash, md_text)
    # \(...\)
    md_text = re.sub(r"\\\([\s\S]+?\\\)", stash, md_text)

    html = markdown.markdown(
        md_text,
        extensions=["extra", "toc", "sane_lists", "tables", "fenced_code"],
    )

    for key, val in placeholders.items():
        html = html.replace(key, val)

    return html


def build_page(md_path: Path) -> str:
    md_text = md_path.read_text(encoding="utf-8")
    body = md_to_html(md_text)
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{md_path.stem}</title>
<style>{CSS}</style>
{MATHJAX}
</head>
<body>
{body}
</body>
</html>
"""


def find_chrome() -> str:
    for name in ("google-chrome", "chromium", "chromium-browser", "chrome"):
        path = shutil.which(name)
        if path:
            return path
    raise SystemExit("No Chrome/Chromium binary found on PATH")


def html_to_pdf(html_path: Path, pdf_path: Path) -> None:
    chrome = find_chrome()
    with tempfile.TemporaryDirectory() as profile:
        cmd = [
            chrome,
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            "--hide-scrollbars",
            "--virtual-time-budget=20000",
            f"--user-data-dir={profile}",
            "--no-pdf-header-footer",
            f"--print-to-pdf={pdf_path}",
            html_path.as_uri(),
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0 or not pdf_path.exists():
            sys.stderr.write(res.stdout + "\n" + res.stderr + "\n")
            raise SystemExit(f"Chrome failed: exit {res.returncode}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("input_md")
    ap.add_argument("output_pdf")
    args = ap.parse_args()

    md_path = Path(args.input_md).resolve()
    pdf_path = Path(args.output_pdf).resolve()
    if not md_path.exists():
        raise SystemExit(f"Missing input: {md_path}")

    html = build_page(md_path)
    with tempfile.NamedTemporaryFile(
        suffix=".html", delete=False, mode="w", encoding="utf-8",
        dir=str(md_path.parent)
    ) as tf:
        tf.write(html)
        html_path = Path(tf.name)

    try:
        html_to_pdf(html_path, pdf_path)
        print(f"Wrote {pdf_path}")
    finally:
        try:
            os.unlink(html_path)
        except OSError:
            pass


if __name__ == "__main__":
    main()
