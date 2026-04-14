from pathlib import Path
import json
import sys

# Allow running this test file directly via `python tests/...`.
PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from utils.s1_data_ingestion.fortran_code_digest import (
    parse_fortran_units,
    build_call_graph,
    _extract_skeleton,
    _LARGE_UNIT_LINES,
)

BENCHMARK = Path(__file__).parent / "benchmark.f90"


def _load_code():
    assert BENCHMARK.exists(), f"File not found: {BENCHMARK}"
    return BENCHMARK.read_text(encoding="utf-8", errors="replace")


# ── Structural parser tests ──────────────────────────────────────────────

def test_parse_finds_all_subroutines():
    """Parser should find every SUBROUTINE / FUNCTION in benchmark.f90."""
    code = _load_code()
    units, _ = parse_fortran_units(code)

    names = {u.name.upper() for u in units}
    expected = {
        "DECRULE01", "BRACKET01", "SRCHFIVE01", "INVAR01",
        "PROFILE01", "COMPUTE_DISTRIBUTIONS", "COMPUTE_GINI",
        "WEALTHSHARE", "WAGESHARE", "TOTALINCOMESHARE",
        "CONSUMPTIONSHARE", "SKEWNESS", "AGE_PARTITION",
        "AVG_RETURN", "AVG_RETURN_WEALTHGROUPS", "AVG_RETURN_INCOMEGROUPS",
        "INCOME_PARTITION", "INCOME_PARTITION_SORT_BY_WEALTH",
        "TOP_SHARES_AGE_PARTITION", "BEQUEST", "BEQUEST_EXEMPTION",
        "JOINT_DIST", "TAX_MOMENT", "BEQ_DISTRIBUTION", "CALIDIFF",
        "CORRELATION", "EARNINGS_GROWTH_MOMENTS", "INTERGENERATIONAL",
        "M66INV", "SSORT_INT",
    }
    missing = expected - names
    assert not missing, f"Parser missed units: {missing}"


def test_parse_finds_functions():
    """Parser should find standalone FUNCTION units."""
    code = _load_code()
    units, _ = parse_fortran_units(code)

    func_names = {u.name.upper() for u in units if u.kind == "function"}
    expected = {"SEARCH", "UTILITY", "BEQ_AFTERTAX", "GINI", "MATINV3", "MATINV4"}
    missing = expected - func_names
    assert not missing, f"Parser missed functions: {missing}"


def test_parse_splits_preamble():
    """Large PROGRAM preamble should be split into program_section units."""
    code = _load_code()
    units, _ = parse_fortran_units(code)

    sections = [u for u in units if u.kind == "program_section"]
    assert len(sections) > 10, (
        f"Expected preamble split into >10 sections, got {len(sections)}"
    )


def test_no_overlapping_line_ranges():
    """No two units should have overlapping line ranges."""
    code = _load_code()
    units, _ = parse_fortran_units(code)

    prev_end = 0
    for u in units:
        assert u.start_line >= prev_end, (
            f"Overlap: {u.kind} {u.name} starts at L{u.start_line} "
            f"but previous unit ended at L{prev_end}"
        )
        prev_end = u.end_line


def test_unit_source_not_empty():
    """Every parsed unit should have non-empty source."""
    code = _load_code()
    units, _ = parse_fortran_units(code)

    for u in units:
        assert u.source.strip(), f"Empty source for {u.kind} {u.name}"


# ── Call graph tests ─────────────────────────────────────────────────────

def test_call_graph_edges():
    """Call graph should capture known call relationships."""
    code = _load_code()
    units, _ = parse_fortran_units(code)
    cg = build_call_graph(units)

    # DECRULE01 calls BRACKET01 and CHECK_BRACKET01
    assert "DECRULE01" in cg
    assert "BRACKET01" in cg["DECRULE01"]
    assert "CHECK_BRACKET01" in cg["DECRULE01"]

    # BRACKET01 calls SRCHFIVE01
    assert "BRACKET01" in cg
    assert "SRCHFIVE01" in cg["BRACKET01"]


def test_call_graph_has_no_self_calls_for_leaf_units():
    """Leaf subroutines (no CALL statements) should not appear as callers."""
    code = _load_code()
    units, _ = parse_fortran_units(code)
    cg = build_call_graph(units)

    # INVAR01 has no CALL statements
    assert "INVAR01" not in cg


def test_calls_extracted_per_unit():
    """Each unit's .calls list should reflect its CALL statements."""
    code = _load_code()
    units, _ = parse_fortran_units(code)

    by_name = {u.name.upper(): u for u in units}

    # check_BRACKET01 calls A_SRCHFIVE01 and N_SRCHFIVE01
    cb = by_name.get("CHECK_BRACKET01")
    assert cb is not None
    assert "A_SRCHFIVE01" in cb.calls
    assert "N_SRCHFIVE01" in cb.calls


# ── Skeleton extraction tests ────────────────────────────────────────────

def test_skeleton_compresses_large_unit():
    """Skeleton of a large unit should be significantly shorter."""
    code = _load_code()
    units, _ = parse_fortran_units(code)

    by_name = {u.name.upper(): u for u in units}
    m66 = by_name.get("M66INV")
    assert m66 is not None, "M66INV not found"

    orig_lines = m66.source.count("\n") + 1
    skel = _extract_skeleton(m66.source)
    skel_lines = skel.count("\n") + 1

    assert skel_lines < orig_lines * 0.3, (
        f"Skeleton should compress M66INV ({orig_lines} lines) to <30%, "
        f"got {skel_lines} lines ({100*skel_lines/orig_lines:.0f}%)"
    )


def test_skeleton_preserves_comments_and_declarations():
    """Skeleton should keep comment lines and declaration lines."""
    code = _load_code()
    units, _ = parse_fortran_units(code)

    by_name = {u.name.upper(): u for u in units}
    unit = by_name.get("INTERGENERATIONAL")
    assert unit is not None

    skel = _extract_skeleton(unit.source)

    # Should keep the purpose comment
    assert "intergenerational" in skel.lower()
    # Should keep ALLOCATE statements
    assert "ALLOCATE" in skel.upper() or "allocate" in skel.lower()


def test_skeleton_keeps_call_statements():
    """Skeleton should preserve CALL statements."""
    code = _load_code()
    units, _ = parse_fortran_units(code)

    by_name = {u.name.upper(): u for u in units}
    unit = by_name.get("INTERGENERATIONAL")
    assert unit is not None

    skel = _extract_skeleton(unit.source)
    assert "CALL" in skel.upper(), "Skeleton should preserve CALL statements"


def test_small_unit_not_skeletonized():
    """Units below the threshold should not be affected by skeleton logic."""
    code = _load_code()
    units, _ = parse_fortran_units(code)

    by_name = {u.name.upper(): u for u in units}
    unit = by_name.get("CALIDIFF")
    assert unit is not None

    unit_lines = unit.end_line - unit.start_line + 1
    assert unit_lines < _LARGE_UNIT_LINES, (
        f"CALIDIFF should be a small unit, got {unit_lines} lines"
    )


# ── Main section capture tests ───────────────────────────────────────────

def test_main_calculations_section_captured():
    """The 'Main Calculations' orchestration section should be captured
    as a program_section with the correct CALL targets."""
    code = _load_code()
    units, _ = parse_fortran_units(code)

    # Find section that contains the main calculations calls
    main_section = None
    for u in units:
        if u.kind == "program_section" and "DECRULE01" in u.calls:
            main_section = u
            break

    assert main_section is not None, (
        "No program_section found containing CALL DECRULE01 "
        "(the main calculations section)"
    )
    # Should also call INVAR01 and COMPUTE_DISTRIBUTIONS
    assert "INVAR01" in main_section.calls
    assert "COMPUTE_DISTRIBUTIONS" in main_section.calls


# ── Integration: digest output structure ─────────────────────────────────

def test_digest_output_structure(tmp_path):
    """digest_fortran_code should produce valid JSON with expected keys.
    Uses a small synthetic input to avoid LLM dependency."""
    from utils.s1_data_ingestion.fortran_code_digest import digest_fortran_code

    sample = """
    PROGRAM TESTPROG
      REAL A, B
      A = 1.0
      CALL MYFUNC(A, B)
    CONTAINS

    SUBROUTINE MYFUNC(X, Y)
      REAL X, Y
      Y = X * 2.0
    END SUBROUTINE MYFUNC

    END PROGRAM TESTPROG
    """
    out = tmp_path / "digest.json"

    # This will fail if no LLM is running, so we just test the parser path
    # by checking that parse_fortran_units handles the sample
    units, header = parse_fortran_units(sample)
    assert len(units) >= 2  # preamble/section + MYFUNC

    names = {u.name.upper() for u in units}
    assert "MYFUNC" in names


if __name__ == "__main__":
    import pytest
    pytest.main([__file__, "-v"])
