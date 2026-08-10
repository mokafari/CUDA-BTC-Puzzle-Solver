"""Tests for module B — on-chain exposure classification (no network)."""

import sys
from unittest import mock

import pytest

from dataset.data import KEYS
from exposure import (
    classify,
    exposure_map,
    is_solved,
    pubkey_exposed,
    summary,
    tx_history,
)
from exposure import fetch

EXPOSED = list(range(65, 161, 5))  # 65, 70, ..., 160


@pytest.mark.parametrize("n", [135, 140, 145, 150, 155, 160])
def test_high_multiples_are_pubkey_exposed(n):
    assert classify(n) == "pubkey-exposed"
    assert pubkey_exposed(n) is True


@pytest.mark.parametrize("n", [71, 72, 73, 74])
def test_non_multiples_are_address_only(n):
    assert classify(n) == "address-only"
    assert pubkey_exposed(n) is False


def test_boundary_65_and_70_exposed_66_to_69_not():
    assert classify(65) == "pubkey-exposed"
    assert classify(70) == "pubkey-exposed"
    for n in (66, 67, 68, 69):
        assert classify(n) == "address-only"


def test_below_65_multiples_of_five_not_exposed():
    # #60 is a multiple of 5 but below the 65 threshold.
    assert classify(60) == "address-only"
    assert pubkey_exposed(60) is False


def test_exposure_map_has_160_entries():
    emap = exposure_map()
    assert len(emap) == 160
    assert set(emap) == set(range(1, 161))
    assert set(emap.values()) <= {"pubkey-exposed", "address-only"}


def test_classify_rejects_out_of_range():
    for n in (0, 161, 256):
        with pytest.raises(ValueError):
            classify(n)


def test_2019_event_affected_puzzles_are_every_fifth_65_to_160():
    events = [e for e in tx_history() if e["date"] == "2019-05-31"]
    assert len(events) == 1
    event = events[0]
    assert event["reveals_pubkeys"] is True
    assert event["affected_puzzles"] == EXPOSED
    # Cross-check against the derived rule.
    assert event["affected_puzzles"] == [
        n for n in range(1, 161) if pubkey_exposed(n)
    ]


def test_tx_history_covers_known_events():
    dates = {e["date"] for e in tx_history()}
    assert "2015-01-15" in dates  # initial funding
    assert "2017-07-11" in dates  # consolidation #161-256
    assert "2019-05-31" in dates  # pubkey exposure
    assert any(d.startswith("2023") for d in dates)  # prize bump


def test_is_solved_matches_dataset():
    assert is_solved(1) is True
    assert is_solved(135) is True  # solved every-5th series ends at 135
    assert is_solved(140) is False
    for n in range(1, 161):
        assert is_solved(n) == (n in KEYS)


def test_fetch_reads_cache_without_network():
    # Guard: any attempt to import/use requests must fail the test.
    def _boom(*args, **kwargs):
        raise AssertionError("network access attempted in cached-read path")

    with mock.patch.dict(sys.modules, {"requests": mock.MagicMock(get=_boom)}):
        txs = fetch.fetch_txs(write=False)
    assert isinstance(txs, list)
    assert len(txs) > 0
    for rec in txs:
        assert "date" in rec and "affected_puzzles" in rec


def test_summary_counts_internally_consistent():
    s = summary()
    assert s["active_total"] == 160
    assert s["pubkey_exposed"] + s["address_only"] == 160
    assert s["pubkey_exposed"] == len(EXPOSED)  # 20
    assert s["address_only"] == 160 - len(EXPOSED)
    assert (
        s["pubkey_exposed_solved"] + s["pubkey_exposed_unsolved"]
        == s["pubkey_exposed"]
    )
    assert (
        s["address_only_solved"] + s["address_only_unsolved"]
        == s["address_only"]
    )
    # Solved counts must agree with the dataset directly.
    total_solved = s["pubkey_exposed_solved"] + s["address_only_solved"]
    assert total_solved == sum(1 for n in range(1, 161) if n in KEYS)
