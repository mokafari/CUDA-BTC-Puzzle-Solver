"""Module C — keygen forensics (SPEC section 5).

Read-only statistical tests of the puzzle creator's key-generation claim against
the *solved* private keys. The creator described the keys as "consecutive private
keys from a single deterministic wallet, then masked with leading 000...0001 to
set the difficulty." If that were true in a way that *nested* (a low-difficulty
key being the low bits of a higher one, i.e. ``KEYS[M] % 2**N == KEYS[N]``), then
solving a high puzzle would leak all lower ones. It does not: the keys behave as
independent uniform draws in each interval ``[2**(N-1), 2**N)``, so there is no
cross-leak — which is why #71 stays unsolved while #135 is solved.

Every function here is pure and returns a computed value from the real dataset;
no conclusions are hardcoded. The findings are pinned as pytest assertions in
``tests/test_keygen.py``.
"""

from __future__ import annotations

from dataset.data import KEYS


def _solved() -> list[int]:
    """Sorted list of solved puzzle numbers present in KEYS."""
    return sorted(KEYS)


def _consecutive_pairs() -> list[tuple[int, int]]:
    """Solved pairs (N, N+1) where both N and N+1 are solved."""
    return [(n, n + 1) for n in _solved() if (n + 1) in KEYS]


def _hamming(a: int, b: int, width: int) -> int:
    """Number of differing bits between the low ``width`` bits of a and b."""
    mask = (1 << width) - 1
    return ((a ^ b) & mask).bit_count()


def bit_length_ok() -> bool:
    """True iff every solved N has ``KEYS[N].bit_length() == N``.

    Puzzle #N's key lives in ``[2**(N-1), 2**N)``, so its MSB sits exactly at
    bit N-1. This is the one structural claim that *does* hold — the "difficulty
    mask" simply fixes the bit-length; it says nothing about the lower bits.
    """
    return all(KEYS[n].bit_length() == n for n in _solved())


def nesting_hits(min_n: int = 12) -> list[tuple[int, int]]:
    """All solved pairs (N, M), N < M, N >= min_n, with ``KEYS[M] % 2**N == KEYS[N]``.

    This is the nesting disproof. If the keys were the low bits of a single
    growing sequence, every such pair would hit; empirically the list is empty.
    N < min_n is ignored: with a tiny modulus a collision is a meaningless
    small-number coincidence, not evidence of nesting.
    """
    solved = _solved()
    hits: list[tuple[int, int]] = []
    for i, n in enumerate(solved):
        if n < min_n:
            continue
        mod = 1 << n
        kn = KEYS[n]
        for m in solved[i + 1:]:
            if KEYS[m] % mod == kn:
                hits.append((n, m))
    return hits


def mean_low_bits_differ(width: int = 16) -> float:
    """Mean Hamming distance between the low ``width`` bits of consecutive keys.

    Over consecutive solved pairs (N, N+1). For independent uniform values the
    expectation is ``width / 2`` (~8 for 16 bits); the measured value (~7.33)
    sits right there. Truly sequential keys would differ in only a bit or two.
    """
    pairs = _consecutive_pairs()
    total = sum(_hamming(KEYS[n], KEYS[m], width) for n, m in pairs)
    return total / len(pairs)


def consecutive_ratios() -> list[float]:
    """``KEYS[N+1] / KEYS[N]`` for consecutive solved pairs.

    A deterministic +1 counter would pin every ratio near 1.0. Instead they
    spread widely across the doubling interval (measured ~1.10 to ~3.37),
    consistent with independent uniform draws.
    """
    return [KEYS[m] / KEYS[n] for n, m in _consecutive_pairs()]


def mean_position_in_interval() -> float:
    """Mean of ``(KEYS[N] - 2**(N-1)) / 2**(N-1)`` over all solved N.

    Each key's fractional position within its own ``[2**(N-1), 2**N)`` interval.
    For uniform draws this averages 0.5 (measured ~0.504).
    """
    solved = _solved()
    positions = [(KEYS[n] - (1 << (n - 1))) / (1 << (n - 1)) for n in solved]
    return sum(positions) / len(positions)


def run() -> dict:
    """All headline keygen findings as computed values."""
    ratios = consecutive_ratios()
    return {
        "bit_length_ok": bit_length_ok(),
        "nesting_hits": nesting_hits(),
        "mean_low_bits_differ": mean_low_bits_differ(),
        "mean_position_in_interval": mean_position_in_interval(),
        "ratio_min": min(ratios),
        "ratio_max": max(ratios),
    }
