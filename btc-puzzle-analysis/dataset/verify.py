"""End-to-end integrity check on the dataset (module A).

For every solved key we derive both the compressed and uncompressed P2PKH
address and assert one matches the published puzzle address. For every exposed
public key we assert it hashes to the published address. This is the single
check that the whole dataset is internally consistent and matches the chain.
"""

from __future__ import annotations

from common import normalize_pubkey, privkey_to_address, pubkey_to_p2pkh
from dataset.data import ADDRS, KEYS, PUBKEYS


def address_for_key(k: int) -> tuple[str, str]:
    """Return (compressed_address, uncompressed_address) for a private key."""
    return privkey_to_address(k, True), privkey_to_address(k, False)


def key_matches(n: int) -> bool:
    """True iff KEYS[n] derives (compressed or uncompressed) to ADDRS[n]."""
    comp, uncomp = address_for_key(KEYS[n])
    return ADDRS[n] in (comp, uncomp)


def pubkey_matches(n: int) -> bool:
    """True iff PUBKEYS[n] hashes to ADDRS[n]."""
    return pubkey_to_p2pkh(normalize_pubkey(PUBKEYS[n])) == ADDRS[n]


def in_range(n: int) -> bool:
    """True iff KEYS[n] lies in the puzzle interval [2**(n-1), 2**n)."""
    return 2 ** (n - 1) <= KEYS[n] < 2 ** n


def verify_all() -> list[str]:
    """Verify the entire dataset. Returns PASS lines; raises on any mismatch."""
    lines: list[str] = []
    for n in sorted(KEYS):
        assert in_range(n), f"#{n}: key outside [2**{n-1}, 2**{n})"
        comp, uncomp = address_for_key(KEYS[n])
        assert ADDRS[n] in (comp, uncomp), (
            f"#{n}: derived {comp}/{uncomp} != published {ADDRS[n]}"
        )
        lines.append(f"#{n:<3} key  OK  {ADDRS[n]}")
    for n in sorted(PUBKEYS):
        assert pubkey_matches(n), f"#{n}: pubkey does not hash to {ADDRS[n]}"
        lines.append(f"#{n:<3} pub  OK  {ADDRS[n]}")
    return lines


if __name__ == "__main__":
    for line in verify_all():
        print(line)
    print(f"\nAll {len(KEYS)} keys and {len(PUBKEYS)} pubkeys verified.")
