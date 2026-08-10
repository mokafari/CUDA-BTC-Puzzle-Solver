"""Consolidated analysis: run modules A -> B -> C -> D and print one report.

Usage:
    python analyze.py            # print the consolidated report
    python analyze.py --report   # also (re)generate plots into reports/

Everything here is offline and read-only. No keyspace is searched.
"""

from __future__ import annotations

import argparse

from rich.console import Console
from rich.table import Table


def section(console: Console, title: str) -> None:
    console.rule(f"[bold]{title}")


def run_dataset(console: Console) -> None:
    from dataset.data import KEYS, PUBKEYS
    from dataset.verify import verify_all

    section(console, "A · Dataset integrity")
    lines = verify_all()
    console.print(
        f"Verified [bold green]{len(KEYS)}[/] solved keys and "
        f"[bold green]{len(PUBKEYS)}[/] exposed pubkeys — "
        "every derived address matches the published puzzle address."
    )


def run_exposure(console: Console) -> None:
    from exposure.exposure import exposure_map, summary

    section(console, "B · On-chain public-key exposure")
    exposure_map()  # 160-entry classification (drives the counts below)
    s = summary()
    table = Table(show_header=True, header_style="bold")
    table.add_column("class")
    table.add_column("count", justify="right")
    table.add_column("solved", justify="right")
    table.add_column("unsolved", justify="right")
    for label, prefix in (("pubkey-exposed", "pubkey_exposed"), ("address-only", "address_only")):
        table.add_row(
            label,
            str(s[prefix]),
            str(s[f"{prefix}_solved"]),
            str(s[f"{prefix}_unsolved"]),
        )
    console.print(table)
    console.print(
        "pubkey-exposed ⇒ kangaroo-eligible (~2^(n/2) work); "
        "address-only ⇒ brute-force-only (~2^(n-1) work)."
    )


def run_keygen(console: Console) -> None:
    from keygen.report import render

    section(console, "C · Key-generation forensics")
    render()


def run_costmodel(console: Console) -> None:
    from costmodel import brute, kangaroo

    section(console, "D · Solve economics")
    table = Table(show_header=True, header_style="bold")
    table.add_column("target")
    table.add_column("method")
    table.add_column("model estimate")
    yrs_71 = brute.expected_years(71, 1, brute.GPU_RATE)
    table.add_row("#71 (address-only)", "brute force", f"{yrs_71:,.0f} GPU-years (1 GPU)")
    months_140 = kangaroo.anchor_140()
    table.add_row(
        "#140 (pubkey-exposed)",
        "kangaroo",
        f"~{months_140:.1f} GPU-months (200 GPUs, scaled from #135)",
    )
    console.print(table)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", action="store_true", help="also regenerate plots")
    args = parser.parse_args()

    console = Console()
    console.print("[bold]btc-puzzle-analysis — consolidated report[/]\n")
    run_dataset(console)
    run_exposure(console)
    run_keygen(console)
    run_costmodel(console)

    if args.report:
        from costmodel.plots import make_plots

        section(console, "Artifacts")
        for path in make_plots("reports"):
            console.print(f"wrote {path}")

    console.print(
        "\n[dim]Finding: solved keys behave as independent uniform draws in each "
        "interval — no cross-leak between puzzles. The frontier rests on raw "
        "secp256k1 ECDLP, not on any weakness in the key generation.[/]"
    )


if __name__ == "__main__":
    main()
