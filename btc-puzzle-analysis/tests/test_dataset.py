"""Tests for module A — the dataset is the source of truth for everything else."""

import pytest

from common import normalize_pubkey, pubkey_to_p2pkh
from dataset.data import ADDRS, KEYS, PUBKEYS
from dataset.verify import address_for_key, verify_all

SOLVED_REQUIRED = list(range(1, 71)) + [75, 80]
PUBKEY_EXPOSED = [135, 140, 145, 150, 155, 160]


def test_required_solved_keys_present():
    for n in SOLVED_REQUIRED:
        assert n in KEYS, f"missing solved key #{n}"


def test_required_pubkeys_present():
    for n in PUBKEY_EXPOSED:
        assert n in PUBKEYS, f"missing exposed pubkey #{n}"
        assert len(PUBKEYS[n]) == 66 and PUBKEYS[n][:2] in ("02", "03")


@pytest.mark.parametrize("n", sorted(KEYS))
def test_key_in_bit_interval(n):
    # Puzzle #N key lies in [2**(N-1), 2**N): bit_length is exactly N.
    assert 2 ** (n - 1) <= KEYS[n] < 2 ** n
    assert KEYS[n].bit_length() == n


@pytest.mark.parametrize("n", sorted(KEYS))
def test_derived_address_matches_published(n):
    comp, uncomp = address_for_key(KEYS[n])
    assert ADDRS[n] in (comp, uncomp), (
        f"#{n}: derived {comp}/{uncomp} != {ADDRS[n]}"
    )


@pytest.mark.parametrize("n", PUBKEY_EXPOSED)
def test_exposed_pubkey_hashes_to_address(n):
    assert pubkey_to_p2pkh(normalize_pubkey(PUBKEYS[n])) == ADDRS[n]


def test_every_address_has_a_source():
    # No dangling addresses: every ADDRS entry is backed by a key or a pubkey.
    for n in ADDRS:
        assert n in KEYS or n in PUBKEYS


def test_verify_all_runs_clean():
    lines = verify_all()
    assert len(lines) == len(KEYS) + len(PUBKEYS)
