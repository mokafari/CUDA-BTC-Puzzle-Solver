"""Shared constants and crypto helpers for btc-puzzle-analysis.

All modules import from here. Elliptic-curve math is delegated to coincurve
(libsecp256k1); this module only wraps key -> pubkey -> P2PKH derivation and
Base58Check. See SPEC.md sections 1-2.
"""

from __future__ import annotations

import hashlib

from coincurve import PublicKey

# secp256k1 domain parameters (SPEC section 1).
P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
Gx = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
Gy = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8

# Mainnet P2PKH version byte.
P2PKH_VERSION = b"\x00"

_B58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"


def hash160(data: bytes) -> bytes:
    """RIPEMD160(SHA256(data))."""
    return hashlib.new("ripemd160", hashlib.sha256(data).digest()).digest()


def b58check(payload: bytes) -> str:
    """Base58Check-encode a version-prefixed payload."""
    checksum = hashlib.sha256(hashlib.sha256(payload).digest()).digest()[:4]
    full = payload + checksum
    n = int.from_bytes(full, "big")
    out = ""
    while n > 0:
        n, rem = divmod(n, 58)
        out = _B58_ALPHABET[rem] + out
    # Preserve leading zero bytes as leading '1's.
    pad = len(full) - len(full.lstrip(b"\x00"))
    return "1" * pad + out


def privkey_to_pubkey(k: int, compressed: bool = True) -> bytes:
    """SEC-encoded public key for scalar k on secp256k1.

    Raises ValueError if k is not a valid secret (0 < k < N).
    """
    if not 0 < k < N:
        raise ValueError(f"private key out of range: {k}")
    pub = PublicKey.from_valid_secret(k.to_bytes(32, "big"))
    return pub.format(compressed)


def pubkey_to_p2pkh(pub: bytes) -> str:
    """Mainnet P2PKH Base58Check address for a SEC-encoded public key."""
    return b58check(P2PKH_VERSION + hash160(pub))


def privkey_to_address(k: int, compressed: bool = True) -> str:
    """Convenience: private key -> P2PKH address."""
    return pubkey_to_p2pkh(privkey_to_pubkey(k, compressed))


def normalize_pubkey(pub_hex: str) -> bytes:
    """Parse a hex pubkey (compressed or uncompressed) into compressed SEC bytes."""
    return PublicKey(bytes.fromhex(pub_hex)).format(True)
