# RAG quality test — questions

Each question below exercises a different facet of retrieval and context
engineering. The script `rag_quality_test.py` parses this file, issues every
question to the RAG service, and writes a timestamped results markdown with
the retrieved sources and the generated answer side-by-side.

Questions are grouped by test category using `##` headings. Individual
questions start with a numeric list marker (`1.`, `2.`, …). Sub-bullets
beneath a question are author notes — they are ignored by the parser.

---

## A. Single-paper factual (local retrieval)

1. What rate-of-return process does the wealth-concentration paper assume, and how is the transition matrix structured?
2. In the Japan consumption-smoothing paper, which household survey is used to estimate the earnings process, and what does it cover?
3. What is the empirical target Gini coefficient for earnings used in the US joint-labor-supply paper's calibration?
4. What is the top-marginal tax reform proposed in the Taiwan paper?
5. Which demographic states does the US joint-labor-supply model track for a married household?

## B. Single-paper methodology

6. How does the Japan paper calibrate its medical expenditure process?
7. In the US wealth-concentration paper, how does productivity state influence the probability of entering the highest return state?
8. How does the Taiwan paper set up its benchmark calibration before simulating the tax reform?
9. What algorithm does the US joint-labor-supply paper use to find labor-force participation decisions when markets are incomplete?

## C. Cross-paper comparative (global retrieval / profile index)

10. Which papers in the corpus use an overlapping-generations model?
11. Which papers solve their model with value function iteration?
12. Do any two papers share the same empirical data source?
13. Which papers study tax policy, and how do they differ in scope?
14. Compare how the US wealth-concentration paper and the Taiwan tax-reform paper handle idiosyncratic income risk.
15. How does the Japan paper differ from the US joint-labor-supply paper in its treatment of household structure?
16. Which pair of papers has the largest methodological overlap, and what exactly do they share?
17. Do the four papers agree on the role of progressive taxation for reducing inequality, or do their conclusions diverge?

## D. Fortran / computational code

18. Which subroutine in the US joint-labor-supply Fortran code handles the transition-path computation, and what does it persist to disk?
19. What does the `AGE_PARTITION` subroutine do in the Japan paper's code, and how does it fit into the broader pipeline?
20. Describe the role of `rw_decision` and when it is called.
21. How does the tax-moment calculation in the Japan code relate to the economic concept of tax progressivity?

## E. Equation / formula retrieval

22. Write out the household value function with home-production utility used in the US joint-labor-supply paper.
23. Show the stochastic transition matrix for idiosyncratic returns on capital in the wealth-concentration paper.
24. What is the Euler equation or first-order condition characterising household savings in the Japan paper's model?

## F. Table / numeric retrieval

25. What share of wealth is held by the top 1% in the US wealth-concentration paper's benchmark calibration, and what empirical moment is this targeting?
26. What is the effective tax-rate schedule used in the Taiwan paper's benchmark, before the reform is applied?

## G. Robustness — negative / out-of-scope

27. Which paper uses the Krusell-Smith aggregate-shocks algorithm? (Expected: none of the four papers in the corpus.)
28. Does any paper in this corpus study German pension reform? (Expected: no.)

## H. Mixed cross-domain

29. How does each paper's Fortran implementation reflect the economic model it solves — pick any two papers and compare.
30. Where equations differ across papers, what is the economic intuition behind the differences? Focus on Euler/Bellman equations.
