"""Brute-force cost model for address-only puzzle targets.

An address-only puzzle exposes no public key, so the only attack is an exhaustive
search of the private-key interval. Puzzle #n lives in the half-open interval
[2**(n-1), 2**n), so its width is W(n) = 2**(n-1) candidate keys. On average the
key is found after scanning half the interval.

This module is pure analysis math: it estimates expected time and hit-probability
for a given amount of compute. It never searches or enumerates any key.
"""

from __future__ import annotations

import math

# Default per-worker scan rates (keys/sec).
GPU_RATE = 1e9  # 1 Gkey/s — a strong single GPU for this workload.
CPU_RATE = 1e7  # 10 Mkey/s — a fast single CPU core.

SECONDS_PER_YEAR = 31_557_600  # Julian year (365.25 days).


def interval_width(n: int) -> int:
    """Number of candidate keys in puzzle #n's interval [2**(n-1), 2**n)."""
    return 2 ** (n - 1)


def expected_seconds(n: int, workers: float, rate: float) -> float:
    """Expected wall-clock seconds to hit the key.

    Expected search depth is half the interval width; total throughput is
    workers * rate keys/sec.
    """
    return (interval_width(n) / 2) / (workers * rate)


def expected_years(n: int, workers: float, rate: float) -> float:
    """Expected wall-clock years to hit the key."""
    return expected_seconds(n, workers, rate) / SECONDS_PER_YEAR


def prob_by_time(n: int, workers: float, rate: float, t: float) -> float:
    """Probability the key is found within t seconds.

    Under a uniform-prior model the fraction of the interval scanned by time t is
    workers * rate * t / W(n), capped at 1.0.
    """
    return min(1.0, workers * rate * t / interval_width(n))
