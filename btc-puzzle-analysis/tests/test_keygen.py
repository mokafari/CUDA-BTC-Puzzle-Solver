"""Tests for module C — the keygen forensics, pinned as reproducible assertions.

Each test encodes a finding about the solved keys. Tolerances are chosen so they
pass on the real (independent, uniform) data but would FAIL if the keys were
actually nested/sequential as the creator's literal wording would imply.
"""

from dataset.data import KEYS
from keygen.keygen import (
    bit_length_ok,
    consecutive_ratios,
    mean_low_bits_differ,
    mean_position_in_interval,
    nesting_hits,
    run,
)


def test_bit_length():
    # The one structural claim that holds: MSB of #N sits exactly at bit N-1.
    assert bit_length_ok() is True
    for n in KEYS:
        assert KEYS[n].bit_length() == n


def test_nesting_disproof():
    # No solved key is the low bits of a higher one => solving high leaks nothing.
    assert nesting_hits(12) == []


def test_independence():
    # Low 16 bits of consecutive keys differ like independent uniform draws (~8),
    # not like a +1 counter (which would differ in ~0-2 bits).
    mlb = mean_low_bits_differ(16)
    assert 6.0 <= mlb <= 9.5

    # Consecutive ratios spread widely across the doubling interval; a sequential
    # counter would pin them all near 1.0.
    ratios = consecutive_ratios()
    assert max(ratios) - min(ratios) > 1.0
    assert max(ratios) > 2.0


def test_uniformity():
    # Mean fractional position within each interval ~0.5 => uniform, not clustered.
    pos = mean_position_in_interval()
    assert 0.4 < pos < 0.6


def test_run_dict_shape():
    result = run()
    expected_keys = {
        "bit_length_ok",
        "nesting_hits",
        "mean_low_bits_differ",
        "mean_position_in_interval",
        "ratio_min",
        "ratio_max",
    }
    assert set(result) == expected_keys
    assert result["bit_length_ok"] is True
    assert result["nesting_hits"] == []
    assert result["ratio_min"] < result["ratio_max"]
