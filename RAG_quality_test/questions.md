# RAG quality test — questions

Each question below exercises a different facet of retrieval and context
engineering. The script `rag_quality_test.py` parses this file, issues every
question to the RAG service, and writes a timestamped results markdown with
the retrieved sources and the generated answer side-by-side.

Questions are grouped by test category using `##` headings. Individual
questions start with a numeric list marker (`1.`, `2.`, …). Sub-bullets
beneath a question are author notes — they are ignored by the parser.

This is the slimmed 10-question set, chosen so each question stresses a
distinct facet of the pipeline:
single-paper factual retrieval, methodology synthesis, cross-paper
comparative reasoning (global / profile path), Fortran code retrieval,
LaTeX equation retrieval, table / numeric retrieval, and out-of-scope
robustness.

---

## A. Single-paper factual (local retrieval)

1. What rate-of-return process does the wealth-concentration paper assume, and how is the transition matrix structured?
2. What is the top-marginal tax reform proposed in the Taiwan paper?

## B. Single-paper methodology

3. What algorithm does the US joint-labor-supply paper use to find labor-force participation decisions when markets are incomplete?

## C. Cross-paper comparative (global retrieval / profile index)

4. Which papers solve their model with value function iteration?
5. Compare how the US wealth-concentration paper and the Taiwan tax-reform paper handle idiosyncratic income risk.
6. Which pair of papers has the largest methodological overlap, and what exactly do they share?

## D. Fortran / computational code

7. Describe the role of `rw_decision` and when it is called.

## E. Equation / formula retrieval

8. Show the stochastic transition matrix for idiosyncratic returns on capital in the wealth-concentration paper.

## F. Table / numeric retrieval

9. What share of wealth is held by the top 1% in the US wealth-concentration paper's benchmark calibration, and what empirical moment is this targeting?

## G. Robustness — negative / out-of-scope

10. Which paper uses the Krusell-Smith aggregate-shocks algorithm? (Expected: none of the four papers in the corpus.)
