"""Cost-model plots for the Bitcoin Puzzle analysis.

Produces a log-log wall-time (years) vs worker-count chart contrasting an
address-only brute-force target (#71) with a pubkey-exposed kangaroo target
(#140). Analysis math only — no key search.
"""

from __future__ import annotations

import os

import matplotlib

matplotlib.use("Agg")  # non-interactive backend; must precede pyplot import.
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

from costmodel import brute, kangaroo  # noqa: E402


def make_plots(outdir: str = "reports") -> list[str]:
    """Write the wall-time-vs-workers log-log chart; return written paths."""
    os.makedirs(outdir, exist_ok=True)

    workers = np.logspace(0, 5)  # 1 .. 100000 workers.

    # #71: address-only brute force. Per-worker GPU rate; time ~ 1/workers, but
    # the absolute magnitude is astronomical (flat/high on a log-log plot).
    brute_years = np.array(
        [brute.expected_years(71, w, brute.GPU_RATE) for w in workers]
    )

    # #140: pubkey-exposed kangaroo. Ops/sec per worker ~ GPU_RATE.
    kangaroo_years = np.array(
        [
            kangaroo.wall_seconds(140, w, brute.GPU_RATE) / brute.SECONDS_PER_YEAR
            for w in workers
        ]
    )

    fig, ax = plt.subplots(figsize=(8, 6))
    ax.loglog(workers, brute_years, label="#71 address-only (brute force)", lw=2)
    ax.loglog(workers, kangaroo_years, label="#140 pubkey-exposed (kangaroo)", lw=2)

    ax.set_xlabel("workers (GPUs)")
    ax.set_ylabel("expected wall-time (years)")
    ax.set_title("Expected solve time vs worker count")
    ax.grid(True, which="both", ls=":", alpha=0.5)
    ax.legend()
    fig.tight_layout()

    out = os.path.join(outdir, "walltime_vs_workers.png")
    fig.savefig(out, dpi=120)
    plt.close(fig)
    return [out]


if __name__ == "__main__":
    print(make_plots())
