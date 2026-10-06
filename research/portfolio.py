"""Bulk portfolio: ops/sqrt(W) (K) and memory for interval-DLP algorithms in a generic group (exponent-line model).
BSGS family is simulated exactly; kangaroo numbers come from sim.cpp (see search_sim.py). Run: python3 -I portfolio.py"""
import random, math
random.seed(1); W = 1 << 30; SQ = math.sqrt(W); T = 4000
def bsgs(m, sym, trials=T):
    """baby table of m points; giant steps stride (2m if sym else m). returns (mean ops, worst ops)."""
    ops = []
    for _ in range(trials):
        k = random.randrange(W) - (W // 2 if sym else 0)             # sym: key centered at 0
        stride = 2 * m if sym else m
        # probe i covers k in [i*stride - (m if sym else 0), +stride); giants walk outward from the centre (sym: both ways, alternate)
        if sym:
            d = abs(k); i = (d + m) // stride                         # probes at +-i*stride, ordered by |i|: 1 + 2*i probes worst-case order
            probes = 1 if i == 0 else 2 * i                           # +i and -i alternate (average: hit on first of pair half the time)
            probes -= random.random() < .5 and i > 0
        else: probes = k // m + 1
        ops.append(m + probes)
    return sum(ops) / len(ops) / SQ, (m + (W // (2 * m) + 1 if sym else W // m + 1)) / SQ
print(f'{"algorithm":34s} {"K mean":>7s} {"K worst":>8s} {"memory (entries)":>18s}')
rows = []
for name, sym in (('BSGS plain', 0), ('BSGS +/- symmetry', 1)):
    best = min(((bsgs(int(c * SQ), sym), c) for c in (.2, .3, .4, .5, .7, 1.0, 1.4)), key=lambda t: t[0][0])
    (km, kw), c = best; rows.append((name, km, kw, f'{c:.1f}*sqrt(W)'))
for c in (.05, .1, .2):
    km, kw = bsgs(int(c * SQ), 1); rows.append((f'BSGS sym, memory capped {c}*sqrt(W)', km, kw, f'{c}*sqrt(W)'))
rows += [('kangaroo classic (sim.cpp)', 2.4, None, 'DP: tiny'), ('kangaroo +/- sym (sim.cpp, tuned)', 1.25, None, 'DP: tiny'),
         ('SOTA 3-family (literature)', 1.15, None, 'DP: tiny')]
for r in rows: print(f'{r[0]:34s} {r[1]:7.2f} {"" if r[2] is None else format(r[2], "8.2f"):>8s} {r[3]:>18s}')
sw = 2 ** 69.5; print(f'\npuzzle 140 (W=2^139): BSGS-sym K=1.0 needs ~{0.5*sw:.1e} stored points (~{0.5*sw*32/1e18:.0e} EB at 32B each); kangaroo needs DP table of ~GBs.')
