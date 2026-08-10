"""Module C report — a rich table summarizing the keygen forensics.

Run with ``python -m keygen.report``.
"""

from __future__ import annotations

from rich.console import Console
from rich.table import Table

from keygen.keygen import (
    bit_length_ok,
    consecutive_ratios,
    mean_low_bits_differ,
    mean_position_in_interval,
    nesting_hits,
)


def render() -> None:
    """Print a rich table with one row per finding."""
    ratios = consecutive_ratios()
    hits = nesting_hits()
    bl = bit_length_ok()
    mlb = mean_low_bits_differ()
    pos = mean_position_in_interval()

    table = Table(
        title="Keygen forensics — creator's claim vs. the solved keys",
        title_style="bold",
        header_style="bold",
    )
    table.add_column("Finding")
    table.add_column("Metric")
    table.add_column("Measured", justify="right")
    table.add_column("Random-model expectation", justify="right")
    table.add_column("Verdict")

    table.add_row(
        "Bit-length",
        "KEYS[N].bit_length() == N for all solved N",
        str(bl),
        "True (mask fixes difficulty)",
        "PASS" if bl else "FAIL",
    )
    table.add_row(
        "Nesting disproof",
        "solved pairs with KEYS[M] % 2**N == KEYS[N] (N>=12)",
        str(len(hits)),
        "0 (no cross-leak)",
        "PASS — not nested" if hits == [] else f"FAIL — {hits}",
    )
    table.add_row(
        "Independence",
        "mean differing bits, low 16, consecutive keys",
        f"{mlb:.2f}",
        "8.0 (uniform 16-bit)",
        "PASS — independent" if 6.0 <= mlb <= 9.5 else "FAIL",
    )
    table.add_row(
        "Independence",
        "consecutive ratio KEYS[N+1]/KEYS[N] spread",
        f"{min(ratios):.2f}–{max(ratios):.2f}",
        "wide (not ~1.0)",
        "PASS — not sequential"
        if (max(ratios) - min(ratios) > 1.0 and max(ratios) > 2.0)
        else "FAIL",
    )
    table.add_row(
        "Uniformity",
        "mean position (k - 2**(N-1)) / 2**(N-1)",
        f"{pos:.3f}",
        "0.500 (uniform)",
        "PASS — uniform" if 0.4 < pos < 0.6 else "FAIL",
    )

    Console().print(table)


if __name__ == "__main__":
    render()
