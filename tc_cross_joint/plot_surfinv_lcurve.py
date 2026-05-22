#!/usr/bin/env python3

import argparse
import csv
import math
import re
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np


def parse_args():
    root = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(
        description="Build an L-curve summary from surf_inv smooth-sweep exports."
    )
    parser.add_argument(
        "--exports-root",
        type=Path,
        default=root / "exports",
        help="Directory containing sm_* export folders.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=root / "exports" / "lcurve_summary",
        help="Where to write CSV and figures.",
    )
    parser.add_argument(
        "--highlight-smooth",
        type=float,
        default=8.0,
        help="Smooth value to highlight in the annotation labels.",
    )
    return parser.parse_args()


def parse_numeric_config(path: Path) -> List[List[float]]:
    numeric_lines = []
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if re.match(r"^[0-9eE+.\-\s]+$", line):
            numeric_lines.append([float(x) for x in line.split()])
    return numeric_lines


def parse_dsurf_params(path: Path) -> Dict[str, float]:
    numeric = parse_numeric_config(path)
    if len(numeric) < 16:
        raise ValueError(f"Unexpected DSurfTomo.in layout: {path}")
    dims = numeric[0]
    smooth_damp = numeric[5]
    max_iter = numeric[7]
    noise = numeric[15]
    return {
        "nlat": int(dims[0]),
        "nlon": int(dims[1]),
        "nz": int(dims[2]),
        "smooth": float(smooth_damp[0]),
        "damp": float(smooth_damp[1]),
        "max_iter": int(max_iter[0]),
        "sigma": float(noise[0]),
    }


def parse_info_metrics(path: Path) -> Dict[str, float]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    ns_match = re.search(r"The number of traveltime measurements =\s*(\d+)", text)
    rms_matches = re.findall(
        r"mean and rms .*?:\s*([0-9eE+.\-]+)\s+([0-9eE+.\-]+)",
        text,
    )
    surf_mean, surf_rms = (math.nan, math.nan)
    if rms_matches:
        surf_mean = float(rms_matches[-1][0])
        surf_rms = float(rms_matches[-1][1])
    return {
        "ns": int(ns_match.group(1)) if ns_match else math.nan,
        "surf_mean": surf_mean,
        "surf_rms": surf_rms,
    }


def load_model_values(path: Path, nlat: int, nlon: int, nz: int) -> np.ndarray:
    values = np.loadtxt(path, usecols=3)
    expected = nlat * nlon * nz
    if values.size != expected:
        raise ValueError(
            f"{path} has {values.size} values but expected {expected} "
            f"for nlat={nlat}, nlon={nlon}, nz={nz}"
        )
    return values.reshape((nz, nlon, nlat))


def laplacian_like_norm(values: np.ndarray) -> float:
    nz1, nx1, ny1 = values.shape
    out = np.zeros_like(values)
    for iz in range(nz1):
        for ix in range(nx1):
            for iy in range(ny1):
                if (
                    iz == 0
                    or iz == nz1 - 1
                    or ix == 0
                    or ix == nx1 - 1
                    or iy == 0
                    or iy == ny1 - 1
                ):
                    out[iz, ix, iy] = 2.0 * values[iz, ix, iy]
                else:
                    out[iz, ix, iy] = (
                        6.0 * values[iz, ix, iy]
                        - values[iz, ix - 1, iy]
                        - values[iz, ix + 1, iy]
                        - values[iz, ix, iy - 1]
                        - values[iz, ix, iy + 1]
                        - values[iz - 1, ix, iy]
                        - values[iz + 1, ix, iy]
                    )
    return float(np.sqrt(np.sum(out * out)))


def residual_norm_from_file(path: Path, sigma: float) -> Tuple[float, int]:
    residual = np.loadtxt(path, usecols=(1, 2))
    ns = residual.shape[0]
    sum_sq = float(np.sum((residual[:, 1] - residual[:, 0]) ** 2))
    return math.sqrt(sum_sq / (sigma * sigma)), ns


def build_row(run_dir: Path) -> Dict[str, float]:
    param_path = run_dir / "params" / "DSurfTomo.in"
    info_path = run_dir / "logs" / "info_surf.txt"
    residual_path = run_dir / "logs" / "res1.dat"
    mod0_path = run_dir / "models" / "mod_iter0.dat"
    mod1_path = run_dir / "models" / "mod_iter1.dat"
    if not all(p.exists() for p in (param_path, info_path, residual_path, mod0_path, mod1_path)):
        raise FileNotFoundError(f"Missing required files in {run_dir}")

    params = parse_dsurf_params(param_path)
    info = parse_info_metrics(info_path)
    weighted_res, ns = residual_norm_from_file(residual_path, params["sigma"])
    mod0 = load_model_values(mod0_path, params["nlat"], params["nlon"], params["nz"])
    mod1 = load_model_values(mod1_path, params["nlat"], params["nlon"], params["nz"])
    delta = mod1 - mod0
    update_l2 = float(np.sqrt(np.sum(delta * delta)))
    update_lm = laplacian_like_norm(delta)
    final_model_lm = laplacian_like_norm(mod1)

    return {
        "run_name": run_dir.name,
        "smooth": params["smooth"],
        "damp": params["damp"],
        "max_iter": params["max_iter"],
        "sigma": params["sigma"],
        "ns": ns if math.isfinite(ns) else info["ns"],
        "surf_rms": info["surf_rms"],
        "weighted_res": weighted_res,
        "weighted_res_sq": weighted_res * weighted_res,
        "update_l2": update_l2,
        "update_lm": update_lm,
        "update_lm_sq": update_lm * update_lm,
        "final_model_lm": final_model_lm,
    }


def maybe_plot(rows: List[Dict[str, float]], output_path: Path, highlight_smooth: float) -> bool:
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        return False

    if not rows:
        return False

    rows = sorted(rows, key=lambda row: row["smooth"])
    x_raw = [row["weighted_res_sq"] for row in rows]
    y = [row["update_lm_sq"] for row in rows]
    x_max = max(abs(value) for value in x_raw)
    x_power = int(math.floor(math.log10(x_max))) if x_max > 0 else 0
    x_scale = 10 ** x_power if x_power >= 3 else 1.0
    x = [value / x_scale for value in x_raw]

    fig, ax = plt.subplots(figsize=(8.5, 6.0), dpi=160)
    ax.plot(x, y, color="#ff0000", linewidth=1.8, zorder=1)
    for row in rows:
        x_value = row["weighted_res_sq"] / x_scale
        ax.scatter(x_value, row["update_lm_sq"], s=48, color="#ff0000", zorder=2)
        ax.annotate(
            f"{row['smooth']:g}",
            (x_value, row["update_lm_sq"]),
            xytext=(6, 6),
            textcoords="offset points",
            fontsize=12,
            color="#0000cc" if abs(row["smooth"] - highlight_smooth) < 1e-9 else "black",
        )

    ax.set_xlabel(r"$||Wr_s||_2^2$", fontsize=15)
    ax.set_ylabel(r"$||Dm_s||_2^2$", fontsize=15)
    ax.set_title("L-curve", fontsize=17)
    ax.tick_params(axis="both", labelsize=12)
    if x_scale > 1.0:
        ax.text(
            0.985,
            -0.06,
            rf"$\times 10^{{{x_power}}}$",
            transform=ax.transAxes,
            ha="right",
            va="top",
            fontsize=12,
        )
    ax.grid(False)
    fig.tight_layout()
    fig.savefig(output_path, bbox_inches="tight")
    plt.close(fig)
    return True


def write_csv(rows: List[Dict[str, float]], path: Path) -> None:
    if not rows:
        return
    fieldnames = list(rows[0].keys())
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main():
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    rows = []
    skipped = []
    for run_dir in sorted(args.exports_root.iterdir()):
        if not run_dir.is_dir():
            continue
        if run_dir.name == args.output_dir.name and run_dir.parent == args.output_dir.parent:
            continue
        try:
            row = build_row(run_dir)
        except Exception as exc:
            skipped.append((run_dir.name, str(exc)))
            continue
        rows.append(row)

    rows.sort(key=lambda row: row["smooth"])
    csv_path = args.output_dir / "lcurve_metrics.csv"
    write_csv(rows, csv_path)

    plot_path = args.output_dir / "lcurve.png"
    plotted = maybe_plot(rows, plot_path, args.highlight_smooth)

    print(f"Exports root: {args.exports_root}")
    print(f"Output CSV: {csv_path}")
    if plotted:
        print(f"Output figure: {plot_path}")
    else:
        print("Output figure: skipped (matplotlib unavailable or no rows)")
    print(f"Included runs: {len(rows)}")
    for row in rows:
        print(
            f"{row['run_name']}: smooth={row['smooth']}, "
            f"weighted_res={row['weighted_res']:.6f}, "
            f"update_lm={row['update_lm']:.6f}, surf_rms={row['surf_rms']:.6f}"
        )
    if skipped:
        print("Skipped runs:")
        for name, reason in skipped:
            print(f"  {name}: {reason}")


if __name__ == "__main__":
    main()
