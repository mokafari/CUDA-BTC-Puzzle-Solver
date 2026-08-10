# SPEC — `btc-puzzle-analysis`

Single source of coordination for the four analysis modules. Every module reads
this file for shared constants, the dataset schema, and the interfaces it must
expose. Modules import shared crypto from `common.py` and never re-implement it.

> **Scope.** This toolkit is *read-and-compute forensics* on the public Bitcoin
> Puzzle Transaction. It verifies solved keys, maps on-chain public-key exposure,
> tests the creator's key-generation claims, and models solve economics. It does
> **not** search any live keyspace, sweep funds, or attempt to recover an unsolved
> private key — those are unknowable and out of scope by design (see README).

---

## 1. secp256k1 parameters (`common.py`)

```
P  = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
N  = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
Gx = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
Gy = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8
```

Elliptic-curve math is delegated to `coincurve` (libsecp256k1). We do not hand-roll
point arithmetic; `common.py` only wraps key→pubkey→address derivation.

## 2. Shared helpers (`common.py`)

| function | signature | contract |
|---|---|---|
| `privkey_to_pubkey(k, compressed)` | `(int, bool=True) -> bytes` | SEC-encoded pubkey via coincurve; raises on `k<=0` or `k>=N`. |
| `pubkey_to_p2pkh(pub)` | `(bytes) -> str` | Base58Check P2PKH mainnet address (version `0x00`) of SHA256→RIPEMD160(pub). |
| `privkey_to_address(k, compressed)` | `(int, bool=True) -> str` | Convenience: pub then address. |
| `hash160(b)` | `(bytes) -> bytes` | RIPEMD160(SHA256(b)). |
| `b58check(payload)` | `(bytes) -> str` | Base58Check of `payload` (already version-prefixed). |

Address version byte is `0x00` (mainnet P2PKH). All puzzle addresses are P2PKH.

## 3. Dataset schema (module A, `dataset/`)

Puzzle #N private key `k` lives in the half-open interval `[2**(N-1), 2**N)`, i.e.
`k.bit_length() == N`. Module A exposes exactly:

```
KEYS:    dict[int, int]   # N -> private key (solved puzzles only)
ADDRS:   dict[int, str]   # N -> published P2PKH address (all N present in KEYS or PUBKEYS)
PUBKEYS: dict[int, str]   # N -> exposed compressed pubkey hex (66 chars), pubkey-exposed puzzles
```

Solved keys present in `KEYS`: **#1–#70, #75, #80, #85, #90, #95, #100, #105,
#110, #115, #120, #125, #130, #135** (the every-5th series is solved through #135).
Exposed compressed pubkeys present in `PUBKEYS`: **#135, #140, #145, #150, #155, #160**.
Every entry has been verified: each private key derives to its published address,
and each exposed pubkey hashes to its published address.

`dataset.verify.verify_all() -> list[str]` returns human-readable PASS lines and
raises `AssertionError` on any mismatch. This is the end-to-end integrity check.

## 4. Exposure schema (module B, `exposure/`)

A puzzle's public key is on-chain-exposed iff it is a multiple of 5 that is **≥ 65**
(the 2019-05-31 outgoing transaction spent from #65,#70,…,#160, revealing those
pubkeys), **or** its private key is otherwise known (a solved key's pubkey is public).
Classification is *derived*, never hand-tabulated per puzzle:

```
classify(n) -> "pubkey-exposed" | "address-only"
exposure_map() -> dict[int, str]      # for n in 1..160
```

`pubkey-exposed` ⇒ kangaroo-eligible (~`2**(n/2)` work). `address-only` ⇒
brute-force-only over the full interval (~`2**(n-1)` work).

## 5. Keygen forensics (module C, `keygen/`)

Tests the creator's claim (deterministic-wallet consecutive keys, masked to set
difficulty) against the real solved keys, as pytest assertions:

- **Bit-length**: `KEYS[N].bit_length() == N` for all solved N.
- **Nesting disproof**: for solved `N < M` with `N >= 12`, `KEYS[M] % 2**N != KEYS[N]`.
- **Independence**: mean differing bits in low-16 between consecutive solved keys ≈ 8.
- **Uniformity**: mean of `(k - 2**(N-1)) / 2**(N-1)` over solved N ≈ 0.5.

`keygen.report.run() -> dict` returns the four computed statistics;
`keygen.report.render()` prints a `rich` table.

## 6. Cost model (module D, `costmodel/`)

- `brute.expected_seconds(n, workers, rate)` and `brute.prob_by_time(n, workers, rate, t)`.
- `kangaroo.expected_ops(n)` ≈ `1.15 * sqrt(2**n)`; `kangaroo.wall_seconds(n, workers, rate)`.
- `kangaroo.dp_table(target_dp, n)` -> `{d_bits, table_gb, worker_ceiling}`.
- `#140` anchored on the real `#135` datapoint (200 GPUs, ~5 months) scaled by `2**((140-135)/2)`.
- `break_even(prize_btc, gpu_cost_per_hr, btc_price, ...)`.
- `plots.py` writes log-log wall-time-vs-workers charts for #71 and #140 to `reports/`.

## 7. Conventions

- Python 3.11+. Deterministic and offline after the optional one-time fetch.
- Cached chain data in `data/*.json`; tests never hit the network.
- Import style inside the package: `from common import ...`, `from dataset.data import KEYS`.
- `make test` runs pytest; `make report` regenerates `reports/` artifacts.
- Each module owns its files and its `tests/test_<module>.py`; no module edits another's files.
