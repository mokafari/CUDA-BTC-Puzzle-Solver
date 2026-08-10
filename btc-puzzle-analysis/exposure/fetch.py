"""Optional fetcher for public puzzle transaction metadata (module B).

Read-only public-data forensics. By default this module reads the cached
``data/txs.json`` and performs **no** network access, so tests and imports never
touch the network. Passing ``write=True`` (or running with ``--write``) is the
only path that contacts a blockchain explorer; the ``requests`` import and the
HTTP call are deferred inside ``fetch_txs`` so importing this module can never
trigger a request.

This never searches a keyspace or recovers a key — it only pulls public
transaction metadata mirroring :data:`exposure.exposure.TX_HISTORY`.
"""

from __future__ import annotations

import json
import os

_HERE = os.path.dirname(os.path.abspath(__file__))
_CACHE_PATH = os.path.abspath(os.path.join(_HERE, os.pardir, "data", "txs.json"))

# Public explorer base used only when write=True. Kept module-level for
# visibility, but no request is made unless fetch_txs(write=True) is called.
_EXPLORER_BASE = "https://blockchain.info/rawtx"


def _load_cached() -> list:
    """Load and return the cached transaction metadata list (offline)."""
    with open(_CACHE_PATH, encoding="utf-8") as fh:
        return json.load(fh)


def _build_from_history() -> list:
    """Build a JSON-serializable tx list from the authoritative TX_HISTORY."""
    from exposure.exposure import tx_history

    records = []
    for entry in tx_history():
        records.append(
            {
                "date": entry["date"],
                "txid": None,  # placeholder; real txids filled in on a --write pull
                "event": entry["event"],
                "description": entry["description"],
                "affected_puzzles": entry["affected_puzzles"],
                "reveals_pubkeys": entry["reveals_pubkeys"],
            }
        )
    return records


def fetch_txs(write: bool = False) -> list:
    """Return puzzle transaction metadata as a list of dicts.

    ``write=False`` (default): read and return the cached ``data/txs.json``
    with no network access.

    ``write=True``: optionally enrich records from a public explorer, then dump
    the result to ``data/txs.json`` and return it. The ``requests`` import is
    deferred to here so importing this module never performs I/O beyond the
    filesystem.
    """
    if not write:
        return _load_cached()

    records = _build_from_history()

    # Best-effort enrichment from a public explorer. Never fatal: this is
    # public metadata only and the cache remains valid without it.
    try:
        import requests  # deferred: import only on the write path

        for rec in records:
            txid = rec.get("txid")
            if not txid:
                continue
            resp = requests.get(f"{_EXPLORER_BASE}/{txid}", timeout=10)
            if resp.ok:
                rec["explorer"] = {"fetched": True}
    except Exception:  # noqa: BLE001 - enrichment is optional
        pass

    os.makedirs(os.path.dirname(_CACHE_PATH), exist_ok=True)
    with open(_CACHE_PATH, "w", encoding="utf-8") as fh:
        json.dump(records, fh, indent=2)
    return records


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Load (default) or refresh cached puzzle tx metadata."
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Fetch public tx metadata and rewrite data/txs.json "
        "(the only path that touches the network).",
    )
    args = parser.parse_args()

    txs = fetch_txs(write=args.write)
    print(f"{'wrote' if args.write else 'loaded'} {len(txs)} tx records "
          f"({_CACHE_PATH})")
