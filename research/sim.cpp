// Generic-group kangaroo simulator: positions are integers (exponents), hash stands in for x-coordinate.
// Measures K = steps/sqrt(W) with ideal collision detection (DP overhead is separate engineering cost).
// usage: sim <mode:0 classic|1 sym> <bits> <N per type> <meanMult> <trials> [J] [wildSpread] [ring]
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <vector>
#include <unordered_map>
#include <cstdint>
#include <algorithm>
typedef int64_t i64; typedef uint64_t u64;
static inline u64 mix(u64 z) { z += 0x9E3779B97F4A7C15ULL; z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL; z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL; return z ^ (z >> 31); }
int main(int argc, char** argv) {
  int mode = atoi(argv[1]), bits = atoi(argv[2]), N = atoi(argv[3]); double mm = atof(argv[4]); int trials = atoi(argv[5]);
  int J = argc > 6 ? atoi(argv[6]) : 32; double spread = argc > 7 ? atof(argv[7]) : 0.25; int ringOn = argc > 8 ? atoi(argv[8]) : 1;
  double W = std::ldexp(1.0, bits), sq = std::sqrt(W); u64 seed = 12345; auto rnd = [&]() { return mix(seed++); };
  std::vector<double> Ks; int fails = 0;
  for (int t = 0; t < trials; t++) {
    double mean = mm * (mode ? (W / 4 * std::sqrt(2.0 * N / sq)) : (2.0 * N * sq / 4)); if (mean > W / 8) mean = W / 8; if (mean < 1) mean = 1;
    int DPB = getenv("DPB") ? atoi(getenv("DPB")) : 0; double TS = getenv("TS") ? atof(getenv("TS")) : 1.0, RAMP = getenv("RAMP") ? atof(getenv("RAMP")) : 1.0;
    int JD = getenv("JD") ? atoi(getenv("JD")) : 0, RS = getenv("RS") ? atoi(getenv("RS")) : 0; double TW = getenv("TW") ? atof(getenv("TW")) : 0.5;
    std::vector<i64> js(J); for (auto& j : js) { double u = (rnd() >> 11) * (1.0 / 9007199254740992.0);
      double v = JD == 0 ? 2 * u : JD == 1 ? -std::log(1 - u) : (rnd() & 1) ? 0.2 * 2 * u : 1.8 * 2 * u; j = 1 + (i64)(v * mean); }
    i64 Wi = (i64)W; i64 k = mode ? (i64)(rnd() % Wi) - Wi / 2 : (i64)(rnd() % Wi);
    std::vector<i64> jt(J); for (int q = 0; q < J; q++) jt[q] = std::max<i64>(1, (i64)(js[q] * TS));
    int M = 2 * N; std::vector<i64> x(M); std::vector<int> wild(M); std::vector<u64> ring((size_t)M * 8, ~0ULL);
    for (int i = 0; i < M; i++) { wild[i] = (i % 100) < (int)(TW * 100) ? 1 : 0;
      if (mode) x[i] = wild[i] ? k + (i64)(rnd() % (u64)(spread * W)) - (i64)(spread * W / 2) : (i64)(rnd() % (u64)(W / 2));
      else x[i] = wild[i] ? k + (i64)(rnd() % (u64)(spread * W)) : Wi / 2 + (i64)(rnd() % (u64)(spread * W)); }
    std::unordered_map<i64, char> seen; seen.reserve(1 << 20); u64 steps = 0, cap = (u64)(40 * sq) + 100000; bool hit = false;
    auto cls = [&](i64 v) { return mode ? (v < 0 ? -v : v) : v; };
    auto rep = [&](i64 v) { if (!mode) return v; i64 c = v < 0 ? -v : v; return (mix(c) & 1) ? c : -c; };
    for (int i = 0; i < M; i++) { x[i] = rep(x[i]); i64 c = cls(x[i]); auto r = seen.emplace(c, wild[i]); if (!r.second && r.first->second != wild[i]) hit = true; }
    while (!hit && steps < cap) for (int i = 0; i < M && !hit; i++) {
      i64 c = cls(x[i]); u64 h = mix(c ^ 0x55); int j = h % J;
      if (ringOn) { u64* r = &ring[(size_t)i * 8]; for (int q = 0; q < 8; q++) if (r[q] == (u64)c) { j = (j + 1 + (steps % 5)) % J; break; } r[(steps / M) & 7] = c; }
      i64 jj = (wild[i] ? js[j] : jt[j]); if (RAMP != 1.0 && steps > (u64)(0.6 * sq)) jj = (i64)(jj * RAMP) + 1; x[i] = rep(x[i] + jj); steps++; i64 nc = cls(x[i]); if (DPB && (mix(nc ^ 0x77) & ((1ULL << DPB) - 1))) continue;
      auto r = seen.emplace(nc, wild[i]);
      if (!r.second && r.first->second != wild[i]) hit = true;
      else if (!r.second && RS) { // same-type merge: respawn at fresh start
        x[i] = rep(mode ? (wild[i] ? k + (i64)(rnd() % (u64)(spread * W)) - (i64)(spread * W / 2) : (i64)(rnd() % (u64)(W / 2)))
                        : (wild[i] ? k + (i64)(rnd() % (u64)(spread * W)) : Wi / 2 + (i64)(rnd() % (u64)(spread * W))));
        i64 c2 = cls(x[i]); auto r2 = seen.emplace(c2, wild[i]); if (!r2.second && r2.first->second != wild[i]) hit = true; }
    }
    if (getenv("DBG")) fprintf(stderr, "steps=%lu uniq=%zu hit=%d k=%ld\n", steps, seen.size(), (int)hit, (long)k);
    if (hit) Ks.push_back(steps / sq); else fails++;
  }
  if (Ks.empty()) { printf("mode=%d mm=%.2f all %d trials failed\n", mode, mm, fails); return 0; }
  std::sort(Ks.begin(), Ks.end()); double s = 0; for (double v : Ks) s += v;
  printf("mode=%d N=%d mm=%.2f J=%d spr=%.2f ring=%d  meanK=%.3f median=%.3f p90=%.3f fails=%d/%d\n", mode, N, mm, J, spread, ringOn, s / Ks.size(), Ks[Ks.size() / 2], Ks[Ks.size() * 9 / 10], fails, trials);
}
