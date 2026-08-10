# btc-puzzle-analysis

Read-only forensic analysis of the public **Bitcoin Puzzle Transaction** — the
~1000 BTC challenge in which an anonymous creator funded 160 addresses whose
private keys sit in successively larger intervals (`#N` in `[2**(N-1), 2**N)`).

This toolkit **verifies** the solved keys, **maps** which puzzles have had their
public keys exposed on-chain, **tests** the creator's key-generation claims
against the real data, and **models** the cost of solving. Everything is computed
from a script and reproducible — there are no hardcoded conclusions in prose.

> ### What this is not
> This is public-data forensics on a public challenge. It **does not** search any
> keyspace, sweep funds, or attempt to recover an unsolved private key. Unsolved
> keys are unknowable — that is precisely the finding module C makes rigorous.
> Requests to add a keyspace search, kangaroo/BitCrack execution, or worker-pool
> orchestration aimed at an unsolved key are out of scope by design.

## Layout

| module | proves / provides |
|---|---|
| `dataset/` | Source of truth. Solved private keys #1–#70, #75, #80 and the every-5th series through #135, plus exposed compressed pubkeys for #135/140/145/150/155/160. `verify.py` derives each key's P2PKH address and asserts it equals the published puzzle address — the end-to-end integrity check. |
| `exposure/` | On-chain map. Encodes the funding/spend history and classifies every puzzle 1–160 as `address-only` (brute-force-only) or `pubkey-exposed` (kangaroo-eligible), derived from the every-5th-from-65 rule — not hand-tabulated. |
| `keygen/` | Forensics. Tests the creator's "consecutive deterministic-wallet keys, masked to set difficulty" claim against the solved set as reproducible pytest assertions. |
| `costmodel/` | Economics. Expected-time models for brute force and Pollard kangaroo, a distinguished-point table sizer, the #140 projection anchored on the real #135 solve, and a break-even helper. |
| `common.py` | Shared secp256k1 params and key→pubkey→address derivation (wraps `coincurve`). |
| `analyze.py` | Runs A→B→C→D and prints one consolidated report. |

## Quick start

```bash
make install     # venv + pinned deps (coincurve, pytest, rich, matplotlib, requests)
make test        # full offline suite
make report      # regenerate tables + plots into reports/
make analyze     # consolidated A->B->C->D report
```

Or directly, from this directory (with the deps installed):

```bash
python -m dataset.verify      # print the integrity check
python -m keygen.report       # the four keygen findings as a table
python -m costmodel.plots     # write reports/walltime_vs_workers.png
python analyze.py --report
```

## The key-generation finding (plain language)

The creator described the keys as consecutive private keys from one deterministic
wallet, masked with a leading `000…0001` to set each puzzle's difficulty. A
natural but **wrong** reading of that is that the keys *nest* — that a low
puzzle's key is just the low bits of a higher one, so cracking a big puzzle would
leak the small ones. Module C tests this directly on the solved keys and finds:

- **Bit-length holds.** Every solved `#N` has its most-significant bit at exactly
  bit `N-1` — the one structural property the masking claim predicts.
- **No nesting.** For every solved pair `N < M` (with `N ≥ 12`),
  `KEYS[M] mod 2**N ≠ KEYS[N]`. Solving a high puzzle reveals **nothing** about a
  lower one. This is why `#71` remains unsolved while `#135` has fallen.
- **Independence.** Consecutive keys differ in ~half their low 16 bits (measured
  ≈ 7.3 of 16, the random expectation is 8), and the ratios `k(N+1)/k(N)` spread
  widely (≈ 1.1 to 3.4) instead of clustering near a fixed step.
- **Uniformity.** The normalized position of each key within its interval,
  `(k − 2**(N-1)) / 2**(N-1)`, averages ≈ 0.50 — consistent with uniform draws.

**Conclusion:** within each interval the keys behave as independent, uniform
random values. There is no cross-leak between puzzles, so the unsolved frontier
rests on the raw secp256k1 discrete-log problem — brute force for the
address-only targets, Pollard kangaroo for the pubkey-exposed ones — and nothing
about the key generation shortcuts it. All four results are pinned as tests in
`tests/test_keygen.py`, so the claim is reproducible rather than asserted.

## Data provenance

Solved keys and puzzle addresses are cross-checked against public puzzle trackers
and, critically, against each other: the suite refuses to pass unless every
private key derives to its published address and every exposed public key hashes
to its published address. The optional `exposure/fetch.py` can refresh cached
chain metadata into `data/txs.json`, but the test suite always reads the cache
and never touches the network.
