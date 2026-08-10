"""Pollard kangaroo cost model for pubkey-exposed puzzle targets.

When a puzzle's public key is on-chain-exposed, the discrete-log can be attacked
with Pollard's kangaroo method over the known n-bit interval, costing on the order
of 1.15 * sqrt(2**n) group operations instead of the full 2**(n-1) brute force.

This module sizes that work, the distinguished-point (DP) table it needs, and
projects wall-time from the real #135 solve datapoint. It is analysis math only;
it performs no discrete-log search.
"""

from __future__ import annotations

import math

# A distinguished-point entry ~ 32-byte X coordinate + 8-byte distance + overhead.
BYTES_PER_DP = 60

# Real-world anchor: puzzle #135 was solved with ~200 GPUs in ~5 months.
ANCHOR = {"n": 135, "gpus": 200, "months": 5.0}


def expected_ops(n: int) -> float:
    """Expected number of group operations for kangaroo on an n-bit interval.

    The standard estimate is ~1.15 * sqrt(interval width). For puzzle #n the
    interval width is ~2**n, giving 1.15 * 2**(n/2).
    """
    return 1.15 * math.sqrt(2 ** n)


def wall_seconds(n: int, workers: float, rate: float) -> float:
    """Expected wall-clock seconds given `workers` each doing `rate` ops/sec."""
    return expected_ops(n) / (workers * rate)


def dp_table(target_dp: float, n: int) -> dict:
    """Size the distinguished-point table for kangaroo on puzzle #n.

    We pick a DP mask of `d_bits` bits so that roughly `target_dp` distinguished
    points are produced across the expected walk. `worker_ceiling` is the mean
    walk length (2**d_bits) between DPs — a heuristic: pushing far more workers
    than this means DPs are hit so rarely that DP-write/collision overhead starts
    to dominate the useful search work.
    """
    ops = expected_ops(n)
    # Mask bit-count: floor so the mean walk yields at least ~target_dp DPs
    # (rounding down keeps DP density >= the target rather than under-shooting).
    d_bits = int(math.log2(ops / target_dp))
    table_gb = target_dp * BYTES_PER_DP / 1e9
    worker_ceiling = int(2 ** d_bits)  # mean walk length between DPs (heuristic).
    return {
        "d_bits": d_bits,
        "table_gb": table_gb,
        "worker_ceiling": worker_ceiling,
        "expected_ops": ops,
    }


def project_months(n: int, gpus: float = 200) -> float:
    """Project GPU wall-months to solve puzzle #n, anchored on the #135 datapoint.

    Kangaroo work scales as 2**(n/2), so each 2 puzzle numbers doubles the work.
    Time inverse-scales with GPU count relative to the anchor's 200 GPUs.
    """
    scale = 2 ** ((n - ANCHOR["n"]) / 2)
    return ANCHOR["months"] * scale * (ANCHOR["gpus"] / gpus)


def anchor_140() -> float:
    """Projected #140 wall-months at the anchor's 200-GPU scale (~28 months)."""
    return ANCHOR["months"] * 2 ** ((140 - ANCHOR["n"]) / 2)


def break_even(prize_btc: float, gpu_cost_per_hr: float, btc_price: float) -> dict:
    """Compute the compute-budget ceiling that still profits from a solve.

    revenue = prize_btc * btc_price. Spending more than
    `revenue / gpu_cost_per_hr` GPU-hours means the compute cost exceeds the
    prize — so it is the ceiling that still profits.
    """
    revenue_usd = prize_btc * btc_price
    break_even_gpu_hours = revenue_usd / gpu_cost_per_hr
    return {
        "revenue_usd": revenue_usd,
        "break_even_gpu_hours": break_even_gpu_hours,
        "note": (
            "break_even_gpu_hours is the compute budget ceiling: spend fewer "
            "GPU-hours than this and a solve still profits after compute cost."
        ),
    }
