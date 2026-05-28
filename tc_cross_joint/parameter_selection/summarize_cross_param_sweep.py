#!/usr/bin/env python3

import argparse
import csv
import math
import re
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np


def parse_args():
    script_dir = Path(__file__).resolve().parent
    root = script_dir.parent
    parser = argparse.ArgumentParser(
        description="Summarize tc_cross_joint cross-parameter sweep exports."
    )
    parser.add_argument(
        "--exports-root",
        type=Path,
        default=root / "exports" / "cross_param_sweep",
        help="Directory containing the cross-parameter export folders.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=root / "exports" / "cross_param_sweep" / "summary",
        help="Where to write the summary CSV and plots.",
    )
    parser.add_argument(
        "--primary-metric",
        choices=["beta_t", "alpha_g"],
        default="beta_t",
        help="Which parameter to place on the x-axis in the optional plots.",
    )
    return parser.parse_args()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def parse_key_value_file(path: Path) -> Dict[str, float]:
    values: Dict[str, float] = {}
    for raw in read_text(path).splitlines():
        line = raw.strip()
        if not line or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = float(value.strip())
    return values


def parse_last_pair(path: Path, pattern: str) -> Tuple[float, float]:
    matches = re.findall(pattern, read_text(path))
    if not matches:
        return (math.nan, math.nan)
    a, b = matches[-1]
    return float(a), float(b)


def parse_last_scalar(path: Path, pattern: str) -> float:
    matches = re.findall(pattern, read_text(path))
    if not matches:
        return math.nan
    return float(matches[-1])


def model_stats(mod_path: Path, joint_path: Path) -> Tuple[float, float]:
    mod = np.loadtxt(mod_path, usecols=3)
    joint = np.loadtxt(joint_path, usecols=3)
    diff = joint - mod
    rms = float(np.sqrt(np.mean(diff * diff)))
    maxabs = float(np.max(np.abs(diff)))
    return rms, maxabs


def build_row(run_dir: Path) -> Dict[str, float]:
    params_path = run_dir / "params" / "cross_sweep_params.txt"
    surf_info = run_dir / "logs" / "info_surf10.txt"
    joint_info = run_dir / "logs" / "info_joint10.txt"
    terminal_log = run_dir / "logs" / "terminal_output.log"
    mod_path = run_dir / "models" / "mod_iter.dat"
    joint_path = run_dir / "models" / "joint_mod_iter.dat"

    if not all(
        path.exists()
        for path in (params_path, surf_info, joint_info, terminal_log, mod_path, joint_path)
    ):
        raise FileNotFoundError(f"Missing required files in {run_dir}")

    params = parse_key_value_file(params_path)
    _, standalone_surf_rms = parse_last_pair(
        surf_info,
        r"mean and rms of traveltime residuals.*?:\s*([0-9eE+.\-]+)\s+([0-9eE+.\-]+)",
    )
    _, joint_surf_rms = parse_last_pair(
        joint_info,
        r"mean and rms of traveltime residuals after inversion\s*(?:\([^)]*\))?:\s*([0-9eE+.\-]+)\s+([0-9eE+.\-]+)",
    )
    _, joint_grav_rms = parse_last_pair(
        joint_info,
        r"mean and rms of gravity residuals after inversion\s*(?:\([^)]*\))?:\s*([0-9eE+.\-]+)\s+([0-9eE+.\-]+)",
    )
    rel_rms_change_s = parse_last_scalar(
        terminal_log,
        r"DEBUG: rel_rms_change_s\s*=\s*([0-9eE+.\-]+)",
    )
    rel_rms_change_g = parse_last_scalar(
        terminal_log,
        r"DEBUG: rel_rms_change_(?:g|rho_g)\s*=\s*([0-9eE+.\-]+)",
    )
    model_diff_rms, model_diff_maxabs = model_stats(mod_path, joint_path)

    return {
        "run_name": run_dir.name,
        "alpha_s": params["alpha_s"],
        "alpha_g": params["alpha_g"],
        "beta_t": params["beta_t"],
        "standalone_surf_rms": standalone_surf_rms,
        "joint_surf_rms": joint_surf_rms,
        "joint_grav_rms": joint_grav_rms,
        "rel_rms_change_s": rel_rms_change_s,
        "rel_rms_change_g": rel_rms_change_g,
        "model_diff_rms": model_diff_rms,
        "model_diff_maxabs": model_diff_maxabs,
    }


def write_csv(rows: List[Dict[str, float]], path: Path) -> None:
    if not rows:
        return
    fieldnames = list(rows[0].keys())
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def maybe_plot(rows: List[Dict[str, float]], output_dir: Path, primary_metric: str) -> bool:
    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        return False

    if not rows:
        return False

    rows = sorted(rows, key=lambda row: (row["alpha_s"], row["alpha_g"], row["beta_t"]))
    group_key = "alpha_g" if primary_metric == "beta_t" else "beta_t"
    metric_key = primary_metric
    grouped: Dict[float, List[Dict[str, float]]] = {}
    for row in rows:
        grouped.setdefault(row[group_key], []).append(row)

    colors = ["#1f77b4", "#d62728", "#2ca02c", "#ff7f0e", "#9467bd", "#8c564b"]
    plot_specs = [
        ("rel_rms_change_s", "rel_rms_change_s"),
        ("rel_rms_change_g", "rel_rms_change_g"),
        ("model_diff_rms", "model_diff_rms"),
        ("joint_grav_rms", "joint_grav_rms"),
        ("joint_surf_rms", "joint_surf_rms"),
    ]

    for value_name, y_key in plot_specs:
        fig, ax = plt.subplots(figsize=(8.0, 5.2), dpi=150)
        for idx, (group_value, group_rows) in enumerate(sorted(grouped.items())):
            group_rows = sorted(group_rows, key=lambda row: row[metric_key])
            x = [row[metric_key] for row in group_rows]
            y = [row[y_key] for row in group_rows]
            label = f"{group_key}={group_value:g}"
            ax.plot(x, y, marker="o", linewidth=1.6, color=colors[idx % len(colors)], label=label)
        ax.set_xlabel(metric_key, fontsize=12)
        ax.set_ylabel(y_key, fontsize=12)
        ax.set_title(f"{y_key} vs {metric_key}", fontsize=13)
        ax.grid(True, linestyle="--", linewidth=0.5, alpha=0.4)
        ax.legend(fontsize=9)
        fig.tight_layout()
        fig.savefig(output_dir / f"{value_name}_vs_{metric_key}.png", bbox_inches="tight")
        plt.close(fig)
    return True


def print_recommendation(rows: List[Dict[str, float]]) -> None:
    if not rows:
        return

    def score(row: Dict[str, float]) -> float:
        return (
            3.0 * abs(row["standalone_surf_rms"] - row["joint_surf_rms"])
            + 1.5 * row["rel_rms_change_s"]
            + 1.0 * row["rel_rms_change_g"]
            + 0.5 * row["model_diff_rms"]
        )

    ranked = sorted(rows, key=score)
    print("Recommended low-tension candidates:")
    for row in ranked[:5]:
        print(
            f"  {row['run_name']}: alpha_s={row['alpha_s']:g}, "
            f"alpha_g={row['alpha_g']:g}, beta_t={row['beta_t']:g}, "
            f"surf_rms={row['joint_surf_rms']:.6f}, grav_rms={row['joint_grav_rms']:.6f}, "
            f"rel_s={row['rel_rms_change_s']:.6f}, rel_g={row['rel_rms_change_g']:.6f}, "
            f"model_diff_rms={row['model_diff_rms']:.6f}"
        )


def main():
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    rows: List[Dict[str, float]] = []
    skipped = []
    for run_dir in sorted(args.exports_root.iterdir()):
        if not run_dir.is_dir():
            continue
        if run_dir.name == args.output_dir.name and run_dir.parent == args.output_dir.parent:
            continue
        try:
            rows.append(build_row(run_dir))
        except Exception as exc:
            skipped.append((run_dir.name, str(exc)))

    rows.sort(key=lambda row: (row["alpha_s"], row["alpha_g"], row["beta_t"]))
    csv_path = args.output_dir / "cross_param_metrics.csv"
    write_csv(rows, csv_path)
    plotted = maybe_plot(rows, args.output_dir, args.primary_metric)

    print(f"Exports root: {args.exports_root}")
    print(f"Output CSV: {csv_path}")
    if plotted:
        print(f"Output plots: {args.output_dir}")
    else:
        print("Output plots: skipped (matplotlib unavailable or no rows)")
    print(f"Included runs: {len(rows)}")
    print_recommendation(rows)
    if skipped:
        print("Skipped runs:")
        for name, reason in skipped:
            print(f"  {name}: {reason}")


if __name__ == "__main__":
    main()
