"""Algebraic invariants behind the known ECDLP attacks, checked for secp256k1. python3 -I curve_invariants.py"""
import math
p = 2**256 - 2**32 - 977; n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
t = p + 1 - n
print('trace t = p+1-n =', t, f'({t.bit_length()} bits)  -> anomalous (t=1, Smart attack)?', t == 1, '| supersingular (t=0)?', t == 0)
# MOV / Frey-Ruck: smallest k with n | p^k - 1
k = next((k for k in range(1, 200000) if pow(p, k, n) == 1), None)
print('embedding degree k <= 200000:', k if k else 'none found (k > 200000; pairing attack needs small k)')
print('n is prime to Miller-Rabin:', all(pow(a, n - 1, n) == 1 for a in (2, 3, 5, 7, 11, 13, 17, 19, 23)), '| cofactor 1 (prime order, no Pohlig-Hellman subgroup)')
# smoothness of n-1 (relevant to Pollard p-1-style / Cheon-type attacks) and n+1
def trial(m, B=2*10**6):
    f = []; d = 2
    while d < B and d * d <= m:
        while m % d == 0: f.append(d); m //= d
        d += 1 if d == 2 else 2
    return f, m
for name, v in (('n-1', n - 1), ('n+1', n + 1), ('p-1', p - 1), ('p+1', p + 1)):
    f, r = trial(v); print(f'{name}: small factors {dict((x, f.count(x)) for x in set(f))}, cofactor {r.bit_length()} bits')
# Cheon's attack needs the oracle g^(a^i) (strong-DH), which no puzzle provides; n-1 has only small factors 2^6*3*149*631 (~2^24), so no usable divisor either.
# CM discriminant: j=0, D=-3, class number 1 (known); endomorphism ring Z[(1+sqrt(-3))/2]
D = t * t - 4 * p; print('4p - t^2 = 3*f^2 ?', (-D) % 3 == 0 and math.isqrt(-D // 3) ** 2 == -D // 3, '(j=0 CM by sqrt(-3): the GLV endomorphism, already used; gives only the 6-fold full-group symmetry)')
