"""Sanity-bound tests for the cost model (module D)."""

from __future__ import annotations

import os

from costmodel import brute, kangaroo
from costmodel.kangaroo import anchor_140, break_even, dp_table
from costmodel.plots import make_plots


def test_brute_71_single_gpu_huge():
    # A single 1 Gkey/s GPU brute-forcing #71 is ~1.9e4 years.
    years = brute.expected_years(71, 1, brute.GPU_RATE)
    assert years > 1e4


def test_prob_monotone():
    n, workers, rate = 71, 100, brute.GPU_RATE
    p_small = brute.prob_by_time(n, workers, rate, 1e3)
    p_large = brute.prob_by_time(n, workers, rate, 1e6)
    assert p_large > p_small
    # Capped at 1.0 for an absurdly long time.
    assert brute.prob_by_time(n, workers, rate, 1e40) == 1.0
    assert 0.0 <= p_small <= 1.0


def test_dp_table_140():
    tbl = dp_table(1e8, 140)
    assert tbl["d_bits"] == 43
    assert abs(tbl["table_gb"] - 6.0) < 1e-9


def test_kangaroo_beats_brute():
    kg = kangaroo.wall_seconds(140, 200, 1e9)
    bf = brute.expected_seconds(140, 200, 1e9)
    # Kangaroo (~2**70 ops) is astronomically cheaper than brute (~2**139 keys).
    assert kg < bf
    assert kg / bf < 1e-15


def test_anchor_140():
    assert 20 < anchor_140() < 40


def test_break_even_positive():
    res = break_even(prize_btc=13.0, gpu_cost_per_hr=1.0, btc_price=60000)
    assert res["break_even_gpu_hours"] > 0


def test_plots_written(tmp_path):
    paths = make_plots(str(tmp_path))
    assert paths
    for p in paths:
        assert os.path.exists(p)
        assert os.path.getsize(p) > 0
