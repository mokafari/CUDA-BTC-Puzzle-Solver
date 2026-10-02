"""Track C: test solved puzzle keys for generator bias. Fit on N<=50, validate on N>50."""
import json, numpy as np
from scipy import stats
P = [p for p in json.load(open(__file__.rsplit('/',1)[0] + '/data/puzzles.json')) if p['status']=='solved' and p['hex']]
K = {p['n']: int(p['hex'],16) for p in P}
ratio = lambda n: (K[n] - (1<<(n-1))) / (1<<(n-1))       # position in range, U[0,1) under H0
ns = sorted(n for n in K if n >= 8)                       # skip tiny, discretised ranges
r = np.array([ratio(n) for n in ns]); tr, te = r[np.array(ns) <= 50], r[np.array(ns) > 50]
out = {}
# C1 uniform position
out['C1 KS all'] = stats.kstest(r, 'uniform').pvalue
out['C1 mean r (exp .5)'] = (r.mean(), stats.ttest_1samp(r, .5).pvalue)
# C2 bit frequencies below top bit, pooled per relative bit position (msb-1 .. msb-8) and low bits
for j in range(1, 9):
    b = [(K[n] >> (n-1-j)) & 1 for n in ns if n-1-j >= 0]
    out[f'C2 bit msb-{j}'] = (np.mean(b), stats.binomtest(sum(b), len(b)).pvalue)
lo = [(K[n] >> i) & 1 for n in ns for i in range(n-1)]
out['C2 all non-top bits'] = (np.mean(lo), stats.binomtest(sum(lo), len(lo)).pvalue)
# C3 serial correlation of consecutive ratios
c = [n for n in ns if n+1 in K]
out['C3 spearman r_n,r_n+1'] = stats.spearmanr([ratio(n) for n in c], [ratio(n+1) for n in c])
# C4 shared low bits between consecutive keys (masking of one common value -> agreement 1.0)
agree = [np.mean([((K[n]>>i)&1)==((K[n+1]>>i)&1) for i in range(n-1)]) for n in c]
out['C4 low-bit agreement k_n vs k_n+1 (exp .5)'] = (np.mean(agree), stats.ttest_1samp(agree, .5).pvalue)
x = [((K[n]>>i)&1)^((K[n+1]>>i)&1) for n in c for i in range(n-1)]
out['C4 pooled xor ones'] = (np.mean(x), stats.binomtest(sum(x), len(x)).pvalue)
# C5 held-out: Beta fit on train, test log-likelihood vs uniform (LLR>0 => bias generalises)
a, b, _, _ = stats.beta.fit(tr, floc=0, fscale=1)
out['C5 beta fit train (a,b)'] = (a, b)
out['C5 heldout LLR nats (beta vs U)'] = stats.beta.logpdf(te, a, b).sum()
h, e = np.histogram(tr, bins=4, range=(0,1)); dens = (h+1)/(h.sum()+4)*4
out['C5 heldout LLR nats (4-bin hist vs U)'] = np.log(dens[np.minimum((te*4).astype(int),3)]).sum()
# C6 key mod small primes / low byte uniformity (PRNG artefacts)
for m in (2, 3, 4, 8, 256):
    cnt = np.bincount([K[n] % m for n in ns if n > 12], minlength=m)
    out[f'C6 chi2 key mod {m}'] = stats.chisquare(cnt).pvalue
out['n keys (N>=8)'] = len(ns); out['test ratios N>50'] = np.round(te, 3).tolist()
for k, v in out.items(): print(f'{k:45s} {v}')
