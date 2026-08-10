"""Module B — on-chain exposure history and derived classification.

This module encodes the *public* funding/spend history of the Bitcoin Puzzle
Transaction and derives, per puzzle, whether its public key has been revealed
on-chain.

Why exposure matters
---------------------
A puzzle address publishes only a P2PKH ``hash160(pubkey)``. As long as the
address has only ever *received* coins, the public key is not on-chain: an
attacker must brute-force the private key over the whole interval
``[2**(n-1), 2**n)`` — about ``2**(n-1)`` work.

Once an address *spends*, its compressed public key is revealed in the input
script. With the public key known, the discrete-log can be attacked with
Pollard's kangaroo (lambda) method over the ``n``-bit interval, costing only
about ``2**(n/2)`` group operations. That is the difference between
"astronomically infeasible" and "a GPU cluster for a few months".

So:

* ``pubkey-exposed``  => kangaroo-eligible, ~``2**(n/2)`` work.
* ``address-only``    => brute-force-only, ~``2**(n-1)`` work.

The exposure set
----------------
On 2019-05-31 the creator broadcast a single outgoing transaction that spent a
dust amount from every 5th puzzle from #65 through #160
(#65, #70, #75, ..., #160), revealing those 20 compressed public keys. That —
and only that — is what makes those puzzles kangaroo-eligible. The rule is
therefore purely arithmetic (``n % 5 == 0 and 65 <= n <= 160``) and is *never*
hand-tabulated per puzzle.

Classification is over the *active* puzzle range 1..160. Puzzles #161..#256 were
consolidated away by the creator in 2017 and are not part of the active game.
"""

from __future__ import annotations

from dataset.data import KEYS

# ---------------------------------------------------------------------------
# On-chain transaction history (public metadata).
# ---------------------------------------------------------------------------

# The active puzzle range after the 2017 consolidation.
ACTIVE_MIN = 1
ACTIVE_MAX = 160

# Every-5th puzzle from 65 through 160 — the pubkeys revealed on 2019-05-31.
_EXPOSED_PUZZLES = list(range(65, ACTIVE_MAX + 1, 5))


def _exposed_puzzles() -> list[int]:
    """The exact set of puzzles whose pubkeys were revealed on 2019-05-31."""
    return list(_EXPOSED_PUZZLES)


TX_HISTORY: list[dict] = [
    {
        "date": "2015-01-15",
        "event": "initial-funding",
        "description": (
            "Creator funded the puzzle addresses #1-256 in a single initial "
            "transaction, each address receiving a small amount scaling with "
            "the puzzle index."
        ),
        "affected_puzzles": list(range(1, 257)),
        "reveals_pubkeys": False,
    },
    {
        "date": "2017-07-11",
        "event": "consolidation",
        "description": (
            "Creator emptied puzzles #161-256, consolidating those funds and "
            "redistributing them to increase the per-puzzle amounts of the "
            "remaining active puzzles #1-160. This reduced the active game to "
            "#1-160."
        ),
        "affected_puzzles": list(range(161, 257)),
        "reveals_pubkeys": False,
    },
    {
        "date": "2019-05-31",
        "event": "pubkey-exposure",
        "description": (
            "A single outgoing transaction spent from every 5th puzzle from "
            "#65 through #160 (#65, #70, ..., #160), revealing those 20 "
            "compressed public keys on-chain and making them kangaroo-eligible "
            "(~2**(n/2) work instead of ~2**(n-1))."
        ),
        "affected_puzzles": _exposed_puzzles(),
        "reveals_pubkeys": True,
    },
    {
        "date": "2023-01-01",
        "event": "prize-bump",
        "description": (
            "The prize amounts for the active puzzles were multiplied roughly "
            "10x, substantially raising the economic incentive to solve them."
        ),
        "affected_puzzles": list(range(1, ACTIVE_MAX + 1)),
        "reveals_pubkeys": False,
    },
]


def tx_history() -> list[dict]:
    """Return the structured on-chain funding/spend history of the puzzle.

    Each entry is a dict with ``date`` (ISO), ``event``, ``description``,
    ``affected_puzzles`` (list of ints), and ``reveals_pubkeys`` (bool).
    """
    return [dict(entry, affected_puzzles=list(entry["affected_puzzles"]))
            for entry in TX_HISTORY]


# ---------------------------------------------------------------------------
# Derived classification.
# ---------------------------------------------------------------------------


def pubkey_exposed(n: int) -> bool:
    """True iff puzzle #n's compressed public key is exposed on-chain.

    The every-5th-from-65 rule: the 2019-05-31 transaction spent from
    #65, #70, ..., #160, so a puzzle is pubkey-exposed iff
    ``n % 5 == 0 and 65 <= n <= 160``.

    Pubkey-exposed puzzles are kangaroo-eligible (~``2**(n/2)`` work).
    """
    return n % 5 == 0 and 65 <= n <= ACTIVE_MAX


def classify(n: int) -> str:
    """Classify puzzle #n (1..160) as ``"pubkey-exposed"`` or ``"address-only"``.

    * ``"pubkey-exposed"`` => kangaroo-eligible, ~``2**(n/2)`` work.
    * ``"address-only"``   => brute-force-only over the full interval,
      ~``2**(n-1)`` work.
    """
    if not ACTIVE_MIN <= n <= ACTIVE_MAX:
        raise ValueError(f"puzzle #{n} outside active range {ACTIVE_MIN}..{ACTIVE_MAX}")
    return "pubkey-exposed" if pubkey_exposed(n) else "address-only"


def is_solved(n: int) -> bool:
    """True iff puzzle #n has a known private key (present in the dataset)."""
    return n in KEYS


def exposure_map() -> dict[int, str]:
    """Map every active puzzle 1..160 to its exposure classification."""
    return {n: classify(n) for n in range(ACTIVE_MIN, ACTIVE_MAX + 1)}


def summary() -> dict:
    """Return counts of each exposure class, split by solved/unsolved.

    Keys: ``pubkey_exposed``, ``address_only`` (totals) and their
    ``*_solved`` / ``*_unsolved`` breakdowns, plus ``active_total``.
    Invariant: ``pubkey_exposed + address_only == active_total == 160``.
    """
    emap = exposure_map()
    pk = [n for n, c in emap.items() if c == "pubkey-exposed"]
    ao = [n for n, c in emap.items() if c == "address-only"]
    pk_solved = sum(1 for n in pk if is_solved(n))
    ao_solved = sum(1 for n in ao if is_solved(n))
    return {
        "active_total": len(emap),
        "pubkey_exposed": len(pk),
        "pubkey_exposed_solved": pk_solved,
        "pubkey_exposed_unsolved": len(pk) - pk_solved,
        "address_only": len(ao),
        "address_only_solved": ao_solved,
        "address_only_unsolved": len(ao) - ao_solved,
    }
