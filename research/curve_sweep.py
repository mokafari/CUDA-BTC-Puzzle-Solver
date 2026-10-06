"""Sweep secp256k1 for a distinguisher: features of x(kG)/y(kG) vs properties of k. Bonferroni-corrected. python3 -I curve_sweep.py"""
import numpy as np, itertools, sys
from scipy import stats
p = 2**256 - 2**32 - 977; n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
Gx = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798; Gy = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A6855419C47D08FFB10D4B8
def add(P, Q):
    (x1, y1), (x2, y2) = P, Q
    l = (y2 - y1) * pow(x2 - x1, -1, p) % p if x1 != x2 else 3 * x1 * x1 * pow(2 * y1, -1, p) % p
    x3 = (l * l - x1 - x2) % p; return x3, (l * (x1 - x3) - y1) % p
def mulG(k):
    R = None; A = (Gx, Gy)
    while k:
        if k & 1: R = A if R is None else add(R, A)
        A = add(A, A); k >>= 1
    return R
N = int(sys.argv[1]) if len(sys.argv) > 1 else 40000
leg = lambda a: 1 if pow(a, (p - 1) // 2, p) == 1 else 0
FEATS = {**{f'x mod {m}': (lambda x, y, m=m: x % m) for m in (2, 3, 4, 5, 7, 8, 11, 13, 16)},
         'y parity': lambda x, y: y & 1, 'leg(x)': lambda x, y: leg(x), 'leg(x+7)': lambda x, y: leg((x + 7) % p),  # leg(x^3+7)=1 always
         'popcount(x) parity': lambda x, y: bin(x).count('1') & 1, 'x top byte>>5': lambda x, y: x >> 253, 'x low byte>>5': lambda x, y: (x & 255) >> 5,
         'x<p/2': lambda x, y: int(x < p // 2), 'y<p/2': lambda x, y: int(y < p // 2), 'leg(y)': lambda x, y: leg(y)}
TARG = {**{f'k mod {m}': (lambda k, m=m: k % m) for m in (2, 3, 4, 5, 7, 8)}, 'k bit1': lambda k: (k >> 1) & 1, 'k bit2': lambda k: (k >> 2) & 1,
        'k popcount parity': lambda k: bin(k).count('1') & 1, 'k leg(k)': lambda k: leg(k % p)}
pv = {}; tot = 0
for base in (1, 1 << 20, 1 << 40, 1 << 70):
    P = mulG(base); G = (Gx, Gy); pts = []
    for i in range(N): pts.append((base + i, P)); P = add(P, G)
    F = {f: np.array([fn(x, y) for _, (x, y) in pts]) for f, fn in FEATS.items()}
    T = {t: np.array([fn(k) for k, _ in pts]) for t, fn in TARG.items()}
    for (f, fa), (t, ta) in itertools.product(F.items(), T.items()):
        tab = np.zeros((fa.max() + 1, ta.max() + 1)); np.add.at(tab, (fa, ta), 1)
        tab = tab[tab.sum(1) > 0][:, tab.sum(0) > 0]
        if min(tab.shape) < 2: continue
        pv[(base.bit_length(), f, t)] = stats.chi2_contingency(tab)[1]
    # uniformity of each feature itself
    for f, fa in F.items():
        c = np.bincount(fa); c = c[c > 0]; pv[(base.bit_length(), f, 'uniform')] = stats.chisquare(c).pvalue
    print(f'block k~2^{base.bit_length()-1}: done', flush=True)
m = len(pv); best = sorted(pv.items(), key=lambda t: t[1])[:6]
print(f'\n{m} tests, Bonferroni threshold {0.05/m:.2e}; smallest p-values:'); [print(f'  {k}: {v:.3e}') for k, v in best]
print('SIGNIFICANT:', [k for k, v in pv.items() if v < 0.05 / m] or 'none')
# distribution sanity: expected number below 0.05 by chance
print(f'p<0.05: {sum(v<.05 for v in pv.values())} observed vs {0.05*m:.1f} expected by chance')
