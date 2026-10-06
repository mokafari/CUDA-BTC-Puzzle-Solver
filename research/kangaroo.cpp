// Parallel Pollard kangaroo (distinguished points, batched affine inversion) for secp256k1.
// usage: kangaroo <compressed-pubkey-hex> <lo-hex> <bits> [threads] [herd]   (key in [lo, lo+2^bits))
// build: g++ -O3 -march=native -pthread -o kangaroo kangaroo.cpp
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <vector>
#include <thread>
#include <mutex>
#include <atomic>
#include <random>
#include <unordered_map>
#include <chrono>
typedef uint64_t u64; typedef unsigned __int128 u128; typedef __int128 i128;
static const u64 C = 0x1000003D1ULL;
static const u64 P[4] = {0xFFFFFFFEFFFFFC2FULL, ~0ULL, ~0ULL, ~0ULL};
struct fe { u64 v[4]; };
static inline bool ge_p(const fe& a) {
  return a.v[3] == ~0ULL && a.v[2] == ~0ULL && a.v[1] == ~0ULL && a.v[0] >= P[0];
}
static inline void red(fe& a) {  // a < 2^256 < 2p
  if (!ge_p(a)) return;
  u128 c = (u128)a.v[0] + C; a.v[0] = (u64)c; c >>= 64;
  for (int i = 1; i < 4; i++) { c += a.v[i]; a.v[i] = (u64)c; c >>= 64; }
}
static inline fe add(const fe& a, const fe& b) {
  fe r; u128 c = 0;
  for (int i = 0; i < 4; i++) { c += (u128)a.v[i] + b.v[i]; r.v[i] = (u64)c; c >>= 64; }
  if (c) { u128 d = (u128)r.v[0] + C; r.v[0] = (u64)d; d >>= 64; for (int i = 1; i < 4; i++) { d += r.v[i]; r.v[i] = (u64)d; d >>= 64; } }
  red(r); return r;
}
static inline fe sub(const fe& a, const fe& b) {
  fe r; i128 c = 0;
  for (int i = 0; i < 4; i++) { c += (i128)a.v[i] - b.v[i]; r.v[i] = (u64)c; c >>= 64; }
  if (c) { u64 br = C; for (int i = 0; i < 4 && br; i++) { u64 o = r.v[i]; r.v[i] = o - br; br = o < br; } }
  return r;
}
static inline fe mul(const fe& a, const fe& b) {
  u64 t[8] = {0};
  for (int i = 0; i < 4; i++) { u128 c = 0; for (int j = 0; j < 4; j++) { c += (u128)a.v[i] * b.v[j] + t[i + j]; t[i + j] = (u64)c; c >>= 64; } t[i + 4] = (u64)c; }
  fe r; u128 c = 0;
  for (int i = 0; i < 4; i++) { c += (u128)t[4 + i] * C + t[i]; r.v[i] = (u64)c; c >>= 64; }
  c *= C; c += r.v[0]; r.v[0] = (u64)c; c >>= 64;
  for (int i = 1; i < 4; i++) { c += r.v[i]; r.v[i] = (u64)c; c >>= 64; }
  if (c) { u128 d = (u128)r.v[0] + C; r.v[0] = (u64)d; d >>= 64; for (int i = 1; i < 4; i++) { d += r.v[i]; r.v[i] = (u64)d; d >>= 64; } }
  red(r); return r;
}
static fe fpow(fe a, const u64 e[4]) {
  fe r = {{1, 0, 0, 0}};
  for (int i = 255; i >= 0; i--) { r = mul(r, r); if ((e[i >> 6] >> (i & 63)) & 1) r = mul(r, a); }
  return r;
}
static fe inv(const fe& a) { u64 e[4] = {P[0] - 2, P[1], P[2], P[3]}; return fpow(a, e); }
static bool eq(const fe& a, const fe& b) { return !memcmp(a.v, b.v, 32); }
struct pt { fe x, y; };
static const pt G = {{{0x59F2815B16F81798ULL, 0x029BFCDB2DCE28D9ULL, 0x55A06295CE870B07ULL, 0x79BE667EF9DCBBACULL}},
                     {{0x9C47D08FFB10D4B8ULL, 0xFD17B448A6855419ULL, 0x5DA4FBFC0E1108A8ULL, 0x483ADA7726A3C465ULL}}};
static inline void padd(pt& p, const pt& q, const fe& dxinv) {  // p += q (distinct x), dxinv = 1/(q.x-p.x)
  fe l = mul(sub(q.y, p.y), dxinv), x3 = sub(sub(mul(l, l), p.x), q.x);
  p.y = sub(mul(l, sub(p.x, x3)), p.y); p.x = x3;
}
// batch: p[i] += q[i] for all i with a single inversion
static void batch_add(pt* p, const pt* const* q, int n, fe* tmp) {
  fe acc = {{1, 0, 0, 0}};
  for (int i = 0; i < n; i++) { fe d = sub(q[i]->x, p[i].x); if (!d.v[0] && !(d.v[1] | d.v[2] | d.v[3])) d.v[0] = 1; tmp[i] = acc; acc = mul(acc, d); }
  acc = inv(acc);
  for (int i = n - 1; i >= 0; i--) { fe d = sub(q[i]->x, p[i].x); if (!d.v[0] && !(d.v[1] | d.v[2] | d.v[3])) d.v[0] = 1;
    fe di = mul(acc, tmp[i]); acc = mul(acc, d); padd(p[i], *q[i], di); }
}
static pt dbl(const pt& p) {
  fe x2 = mul(p.x, p.x), l = mul(add(add(x2, x2), x2), inv(add(p.y, p.y)));
  pt r; r.x = sub(sub(mul(l, l), p.x), p.x); r.y = sub(mul(l, sub(p.x, r.x)), p.y); return r;
}
static pt smul(u128 k) {  // k*G, k > 0
  pt r = G; int top = 127; while (!((k >> top) & 1)) top--;
  for (int i = top - 1; i >= 0; i--) { r = dbl(r); if ((k >> i) & 1) { fe d = inv(sub(G.x, r.x)); padd(r, G, d); } }
  return r;
}
static bool parse_pub(const char* h, pt& q) {
  if (strlen(h) != 66) return false;
  u64 w[4] = {0}; for (int i = 0; i < 64; i++) { char c = h[2 + i]; int d = c <= '9' ? c - '0' : (c | 32) - 'a' + 10; w[3 - i / 16] = (w[3 - i / 16] << 4) | d; }
  memcpy(q.x.v, w, 32); fe x2 = mul(q.x, q.x), r = add(mul(x2, q.x), fe{{7, 0, 0, 0}});
  u64 e[4];
  // (p+1)/4: p+1 has low limb P[0]+1, no carry; shift right 2
  u64 t[4] = {P[0] + 1, P[1], P[2], P[3]}; for (int i = 0; i < 4; i++) e[i] = (t[i] >> 2) | (i < 3 ? t[i + 1] << 62 : 0);
  q.y = fpow(r, e); if (!eq(mul(q.y, q.y), r)) return false;
  if ((q.y.v[0] & 1) != (unsigned)(h[1] - '0' == 3)) { fe z = {{0, 0, 0, 0}}; q.y = sub(z, q.y); }
  return true;
}
// ---------------------------------------------------------------------------------------------
struct DP { fe x; i128 d; bool wild; };
static std::mutex mu; static std::unordered_map<u64, DP> tbl;
static std::atomic<bool> done{false}; static std::atomic<u64> steps{0}; static u128 found; static bool hit = false;
static i128 W2;  // W/2 offset; found key' = W2 + dt - dw
static const int J = 64;
static std::vector<pt> jp; static std::vector<u128> js;

static void worker(int id, pt Q, int herd, u64 dpmask, int bits) {
  std::mt19937_64 rng(0xC0FFEE + id * 7919);
  std::vector<pt> p(herd); std::vector<i128> d(herd); std::vector<const pt*> q(herd); std::vector<fe> tmp(herd);
  // starts: random subset sums of 32 random points (batched); wild offset relative to Q
  int B = 32; std::vector<pt> R(B); std::vector<u128> Rs(B); u128 Wr = (u128)1 << bits;
  for (int b = 0; b < B; b++) { Rs[b] = (rng() | 1) % (Wr / B) + 1; R[b] = smul(Rs[b]); }
  std::vector<bool> wild(herd);
  for (int i = 0; i < herd; i++) { wild[i] = i & 1; p[i] = wild[i] ? Q : smul((u128)W2); d[i] = 0; }
  for (int b = 0; b < B; b++) {
    std::vector<int> idx; for (int i = 0; i < herd; i++) if (rng() & 1) idx.push_back(i);
    for (size_t o = 0; o < idx.size(); o += 256) { int m = std::min<size_t>(256, idx.size() - o);
      std::vector<pt> sub(m); std::vector<const pt*> qq(m, &R[b]); for (int k = 0; k < m; k++) sub[k] = p[idx[o + k]];
      batch_add(sub.data(), qq.data(), m, tmp.data()); for (int k = 0; k < m; k++) { p[idx[o + k]] = sub[k]; d[idx[o + k]] += Rs[b]; } }
  }
  std::vector<u64> pend; u64 local = 0;
  while (!done) {
    for (int i = 0; i < herd; i++) { int j = p[i].x.v[0] & (J - 1); q[i] = &jp[j]; d[i] += js[j]; }
    batch_add(p.data(), q.data(), herd, tmp.data()); local += herd;
    for (int i = 0; i < herd; i++) if (!(p[i].x.v[0] & dpmask)) {
      std::lock_guard<std::mutex> g(mu); u64 key = p[i].x.v[1];
      auto it = tbl.find(key);
      if (it == tbl.end()) tbl[key] = {p[i].x, d[i], wild[i]};
      else if (it->second.wild != wild[i] && eq(it->second.x, p[i].x)) {
        i128 dt = wild[i] ? it->second.d : d[i], dw = wild[i] ? d[i] : it->second.d;
        found = (u128)(W2 + dt - dw); hit = true; done = true; }
    }
    if (local >= 4096) { steps += local; local = 0; }
  }
  steps += local;
}

int main(int argc, char** argv) {
  if (argc < 4) { fprintf(stderr, "usage: %s pub lo_hex bits [threads] [herd]\n", argv[0]); return 2; }
  pt Q0; if (!parse_pub(argv[1], Q0)) { fprintf(stderr, "bad pubkey\n"); return 2; }
  u128 lo = 0; for (const char* c = argv[2]; *c; c++) lo = lo << 4 | (*c <= '9' ? *c - '0' : (*c | 32) - 'a' + 10);
  int bits = atoi(argv[3]); int T = argc > 4 ? atoi(argv[4]) : std::thread::hardware_concurrency(); int herd = argc > 5 ? atoi(argv[5]) : 512;
  auto t0 = std::chrono::steady_clock::now();
  // shift: Q = target - lo*G  =>  key' in [0, 2^bits)
  pt Q = Q0; { pt L = smul(lo); fe z = {{0, 0, 0, 0}}; L.y = sub(z, L.y); fe d = inv(sub(L.x, Q.x)); padd(Q, L, d); }
  W2 = (i128)1 << (bits - 1);
  double N = (double)T * herd, mean = N * std::sqrt(std::ldexp(1.0, bits)) / 4; if (mean > std::ldexp(1.0, bits - 3)) mean = std::ldexp(1.0, bits - 3);
  std::mt19937_64 r(1); for (int i = 0; i < J; i++) { u128 s = (u128)(r() % (u64)(2 * mean)) + 1; js.push_back(s); jp.push_back(smul(s)); }
  double per = std::sqrt(std::ldexp(1.0, bits)) / N / 8; u64 dpmask = 0; while (dpmask < (u64)per) dpmask = dpmask * 2 + 1; dpmask >>= 1;
  std::vector<std::thread> th; for (int i = 0; i < T; i++) th.emplace_back(worker, i, Q, herd, dpmask, bits);
  for (auto& t : th) t.join();
  double sec = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
  double expect = 2.08 * std::sqrt(std::ldexp(1.0, bits));
  if (hit) { u128 k = lo + found; pt c = smul(k); bool ok = eq(c.x, Q0.x);
    printf("key=%lx%016lx %s steps=%.3g (%.2fx of 2sqrt(W)) %.2fs %.2f Mstep/s dps=%zu\n", (u64)(k >> 64), (u64)k, ok ? "VERIFIED" : "MISMATCH",
           (double)steps, steps / expect, sec, steps / sec / 1e6, tbl.size()); return ok ? 0 : 1; }
  return 1;
}
