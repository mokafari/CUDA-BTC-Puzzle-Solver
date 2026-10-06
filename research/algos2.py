"""Round 2: exact inter-key relations + bit statistics. Run: python3 -I research/algos2.py"""
import sys, os, hashlib, hmac, itertools
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from algos import K, mask
import numpy as np
from scipy import stats
ns = sorted(K)
# E1 shared-master hypothesis: low (a-1) bits of k_b equal low bits of k_a for a<b (exact, any pair)
def lowagree(a, b): m = (1 << (a - 1)) - 1; return (K[a] ^ K[b]) & m
agree = [(a, b) for a, b in itertools.combinations(ns, 2) if a >= 12 and lowagree(a, b) == 0]
print('E1 exact shared low bits (a>=12):', agree or 'none')
# E1b same with high-aligned bits (top bits after leading 1)
hi = lambda k, n: k ^ (1 << (n - 1))
hagree = [(a, b) for a, b in itertools.combinations(ns, 2) if a >= 12 and hi(K[b], b) >> (b - a) == hi(K[a], a)]
print('E1b exact shared top bits (a>=12):', hagree or 'none')
# E2 hash chains: k_{n+1} = mask(H(enc(k_n)))
encs = [lambda k, n: k.to_bytes(32, 'big'), lambda k, n: k.to_bytes(32, 'little'), lambda k, n: format(k, 'x').encode(), lambda k, n: format(k, '064x').encode(),
        lambda k, n: str(k).encode(), lambda k, n: k.to_bytes((n + 7) // 8, 'big'), lambda k, n: k.to_bytes(8, 'big')]
Hs = {'sha256': hashlib.sha256, 'sha1': hashlib.sha1, 'md5': hashlib.md5, 'sha512': hashlib.sha512, 'rmd': lambda b: hashlib.new('ripemd160', b), 'blake2b': hashlib.blake2b, 'sha3': hashlib.sha3_256,
      'sha256d': lambda b: hashlib.sha256(hashlib.sha256(b).digest())}
def tomask(d, n):
    v = int.from_bytes(d, 'big'); w = int.from_bytes(d, 'little'); return [mask(v, n), mask(w, n), mask(v >> max(0, len(d) * 8 - n + 1), n), mask(w >> max(0, len(d) * 8 - n + 1), n)]
ch = []
for hn, H in Hs.items():
    for ei, e in enumerate(encs):
        for n in range(16, 40):
            if n in K and n + 1 in K and K[n + 1] in tomask(H(e(K[n], n)).digest(), n + 1): ch.append((hn, ei, n))
print('E2 chain hits:', ch or 'none', f'({len(Hs)*len(encs)*26*4} tests)')
# E3 KDFs of n: pbkdf2/hmac/hkdf with common salts/keys
kd = []
for salt in (b'', b'bitcoin', b'puzzle', b'btc', b'satoshi', b'Bitcoin seed', b'key', b'secp256k1', b'mnemonic'):
    for n in range(16, 40):
        if n not in K: continue
        cands = [hmac.new(salt, str(n).encode(), 'sha256').digest(), hmac.new(salt, str(n).encode(), 'sha512').digest(), hmac.new(salt, n.to_bytes(4, 'big'), 'sha512').digest(),
                 hashlib.pbkdf2_hmac('sha256', str(n).encode(), salt, 1), hashlib.pbkdf2_hmac('sha512', str(n).encode(), salt, 2048)]
        if any(K[n] in tomask(c, n) for c in cands): kd.append((salt, n))
print('E3 KDF hits:', kd or 'none')
# E4 bit statistics (Bonferroni over tests)
bits = {n: [(K[n] >> i) & 1 for i in range(n - 1)] for n in ns if n >= 8}
tests = {}
pc = [(sum(b), len(b)) for b in bits.values()]; z = [(s - l / 2) / (l / 4) ** .5 for s, l in pc]
tests['popcount z-mean'] = stats.ttest_1samp(z, 0).pvalue
runs = []
for b in bits.values():
    r = 1 + sum(b[i] != b[i + 1] for i in range(len(b) - 1)); l = len(b); m = (l + 1) / 2; v = (l - 1) / 4; runs.append((r - m) / v ** .5)
tests['runs z-mean'] = stats.ttest_1samp(runs, 0).pvalue
for j in range(1, 6):  # lag-j autocorrelation pooled
    a = np.concatenate([np.array(b[:-j]) for b in bits.values()]); c = np.concatenate([np.array(b[j:]) for b in bits.values()])
    tests[f'bit lag{j} corr'] = stats.pearsonr(a, c)[1]
for i in range(7):  # absolute low-bit position bias
    v = [b[i] for b in bits.values()]; tests[f'low bit {i}'] = stats.binomtest(sum(v), len(v)).pvalue
for m in (3, 5, 7, 9, 11, 13):  # residue uniformity for odd moduli (bias in LCG/mod artefacts)
    cnt = np.bincount([K[n] % m for n in ns if n > 16], minlength=m); tests[f'key mod {m}'] = stats.chisquare(cnt).pvalue
for n_ in (2, 3):  # key vs n relations
    tests[f'k_n mod n for n>16 (chi2 mod 8)'] = stats.chisquare(np.bincount([K[n] % 8 for n in ns if n > 16], minlength=8)).pvalue
nt = len(tests); best = sorted(tests.items(), key=lambda t: t[1])[:4]
print(f'E4 {nt} bit-stat tests; smallest p (Bonferroni threshold {0.05/nt:.4f}):'); [print(f'   {k:28s} p={v:.4f}') for k, v in best]
