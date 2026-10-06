"""Fast harness: score predictors of puzzle keys out-of-sample.
Each predictor: f(train_ns, train_r, n) -> density on r in [0,1) (callable, vectorised, integrates to 1).
Score = mean log2 density at the true r over expanding-window one-step-ahead predictions
      = average bits of search space saved per puzzle (0 for uniform; >0 only if real structure).
Null: permute the r series (destroys any n-dependence) -> p-value for each predictor.
Run: python3 -I research/algos.py"""
import json, hashlib, hmac, random, itertools, sys, os
import numpy as np
D = os.path.dirname(os.path.abspath(__file__))
P = [p for p in json.load(open(f'{D}/data/puzzles.json')) if p['status'] == 'solved' and p['hex']]
K = {p['n']: int(p['hex'], 16) for p in P}
NS = np.array(sorted(n for n in K if n >= 10)); R = np.array([(K[n] - (1 << (n - 1))) / (1 << (n - 1)) for n in map(int, NS)])
X = np.linspace(0, 1, 1001)[:-1] + 5e-4
def kde(pts, h, w=None):  # circular-reflected KDE on [0,1), mixed with uniform (shrinkage keeps log-lik finite)
    pts = np.asarray(pts)
    def f(x):
        x = np.atleast_1d(x)[:, None]; g = 0
        for s in (-1, 0, 1): g = g + np.exp(-0.5 * ((x - pts[None] - s) / h) ** 2)
        d = g.sum(1) / (len(pts) * h * np.sqrt(2 * np.pi)); return 0.5 * d + 0.5
    return f
U = lambda tn, tr, n: (lambda x: np.ones_like(np.atleast_1d(x), float))
def mk_kde(h, m=None): return lambda tn, tr, n: kde(tr[-m:] if m else tr, h)
def ar1(h):  # r_n near r_{n-1} (needs adjacent train point)
    def a(tn, tr, n):
        if tn[-1] != n - 1: return U(tn, tr, n)
        return kde([tr[-1]], h)
    return a
def weyl(grid=20000, h=0.05):  # r_n = frac(a*n + b): fit on train by max resultant length over a grid of a
    A = np.linspace(0, 1, grid, endpoint=False)
    def w(tn, tr, n):
        z = np.exp(2j * np.pi * (A[:, None] * tn[None] - tr[None])).mean(1); i = np.abs(z).argmax()
        b = np.angle(z[i]) / 2 / np.pi; pred = (A[i] * n + b) % 1; return kde([pred], h)
    return w
def mode_hist(bins):  # histogram of train ratios
    def m(tn, tr, n):
        c = np.bincount(np.minimum((tr * bins).astype(int), bins - 1), minlength=bins) + 1.0
        return lambda x: c[np.minimum((np.atleast_1d(x) * bins).astype(int), bins - 1)] / c.sum() * bins
    return m
def ratio_ar_drift(h):  # r_n ~ 1-r_{n-1} (anti-persistence)
    def a(tn, tr, n): return kde([1 - tr[-1]], h) if tn[-1] == n - 1 else U(tn, tr, n)
    return a
ALGOS = {'uniform': U, 'kde.15': mk_kde(.15), 'kde.08': mk_kde(.08), 'kde.15/last20': mk_kde(.15, 20),
         'hist4': mode_hist(4), 'hist8': mode_hist(8), 'ar1.15': ar1(.15), 'anti-ar1.15': ratio_ar_drift(.15), 'weyl': weyl()}

def score(algo, ns, r, start=20):
    s = []
    for i in range(len(ns)):
        if ns[i] < start: continue
        s.append(np.log2(algo(ns[:i], r[:i], ns[i])(r[i])[0]))
    return np.mean(s)
def perm_p(algo, ns, r, obs, nperm=100, seed=0):
    g = np.random.default_rng(seed); return (1 + sum(score(algo, ns, g.permutation(r)) >= obs for _ in range(nperm))) / (nperm + 1)

# --- exact generator hypotheses: key_n == mask(gen(n)) ? probability of a chance hit at n is 2^-(n-1)
def gens():
    enc = lambda n: [str(n).encode(), f'puzzle {n}'.encode(), f'Puzzle {n}'.encode(), f'#{n}'.encode(), n.to_bytes(4, 'big'), n.to_bytes(4, 'little'), n.to_bytes(32, 'big'), n.to_bytes(32, 'little')]
    for name, H in (('sha256', lambda b: hashlib.sha256(b)), ('sha256d', lambda b: hashlib.sha256(hashlib.sha256(b).digest())),
                    ('sha1', hashlib.sha1), ('md5', hashlib.md5), ('sha512', hashlib.sha512), ('ripemd', lambda b: hashlib.new('ripemd160', b)),
                    ('blake2', hashlib.blake2b), ('sha3', hashlib.sha3_256)):
        for j in range(8):
            yield f'{name}/enc{j}', lambda n, H=H, j=j: int.from_bytes(H(enc(n)[j]).digest(), 'big')
    for name, mk in (('py.seed(n)', lambda n: random.Random(n)), ('py.seed(n+base1000)', lambda n: random.Random(1000 + n))):
        yield name, lambda n, mk=mk: mk(n).getrandbits(256)
    yield 'py.single-stream', None
    yield 'np.RandomState(n)', lambda n: int.from_bytes(np.random.RandomState(n).bytes(32), 'big')
def mask(v, n): return (v & ((1 << (n - 1)) - 1)) | (1 << (n - 1))
def mask_hi(v, n): return (v >> (256 - (n - 1)) if v.bit_length() > 255 else v >> max(0, v.bit_length() - (n - 1))) | (1 << (n - 1))
def gen_scan():
    hits = []; n_lo, n_hi = 8, 40; tried = 0
    for name, g in gens():
        if g is None: continue
        for mname, m in (('low', mask), ('high', mask_hi)):
            tried += 1
            ok = sum(m(g(n), n) == K[n] for n in range(n_lo, n_hi) if n in K)
            if ok > 1: hits.append((name, mname, ok))
    # one random.Random(seed) stream: key_n = mask(getrandbits(256)) in order, scan 2^16 seeds, n=1..4 match
    for seed in range(1 << 16):
        rg = random.Random(seed); ok = all(mask(rg.getrandbits(256), n) == K[n] for n in (1, 2, 3, 4, 5, 6)); tried += 1
        if ok: hits.append(('py.stream seed', seed, 6))
    return hits, tried

if __name__ == '__main__':
    print(f'{len(NS)} solved keys n>=10, evaluating n>=20 one-step-ahead\n{"algo":18s} bits/puzzle  perm-p')
    base = {}
    for name, a in ALGOS.items():
        s = score(a, NS, R); p = '-' if name == 'uniform' else f'{perm_p(a, NS, R, s):.2f}'
        print(f'{name:18s} {s:+.4f}     {p}', flush=True)
    h, t = gen_scan(); print(f'\nexact generator scan: {t} hypotheses, hits (>1 match): {h or "none"}')
