"""Cost / expected-time model for solving Bitcoin Puzzle targets.

Analysis math only: estimates the compute and wall-time to solve address-only
(brute-force) and pubkey-exposed (Pollard kangaroo) puzzles. Performs no key
search of any kind.
"""

from costmodel import brute, kangaroo
from costmodel.brute import (
    CPU_RATE,
    GPU_RATE,
    expected_seconds,
    expected_years,
    interval_width,
    prob_by_time,
)
from costmodel.kangaroo import (
    ANCHOR,
    anchor_140,
    break_even,
    dp_table,
    expected_ops,
    project_months,
    wall_seconds,
)

__all__ = [
    "brute",
    "kangaroo",
    # brute
    "interval_width",
    "expected_seconds",
    "expected_years",
    "prob_by_time",
    "GPU_RATE",
    "CPU_RATE",
    # kangaroo
    "expected_ops",
    "wall_seconds",
    "dp_table",
    "project_months",
    "anchor_140",
    "break_even",
    "ANCHOR",
]
