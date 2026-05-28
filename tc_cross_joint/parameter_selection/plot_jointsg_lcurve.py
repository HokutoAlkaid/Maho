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
        description="Build an L-curve summary from tc_cross_joint export directories."
    )
    parser.add_argument(
        "--exports-root",
        type=Path,
        default=root / "exports",
        help="Directory containing run_* exports.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=root / "exports" / "lcurve_summary",
        help="Where to write CSV and figures.",
    )
    parser.add_argument(
        "--workflow-mode",
        choices=["all", "vs_seed", "density_seed"],
        default="all",
        help="Optionally filter exports by parameterization mode.",
    )
    parser.add_argument(
        "--annotate",
        choices=["smooth_joint", "beta_t", "alpha_g", "run_name", "workflow_mode"],
        default="smooth_joint",
        help="Point labels used in the plot.",
    )
    parser.add_argument(
        "--plot-style",
        choices=["sample", "loglog"],
        default="sample",
        help="Use the sample-style linear squared-norm plot or the older log-log plot.",
    )
    parser.add_argument(
        "--highlight-smooth",
        type=float,
        default=10.0,
        help="Smooth value to highlight in the annotation labels.",
    )
    return parser.parse_args()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def parse_crossgradient_params(path: Path) -> Dict[str, float]:
    text = read_text(path)
    params = {}
    for key in ("ALPHA_S", "ALPHA_G", "BETA_T"):
        match = re.search(rf"^{key}\s*=\s*([0-9eE+.\-]+)", text, re.MULTILINE)
        params[key.lower()] = float(match.group(1)) if match else math.nan
    return params


def parse_workflow_mode(path: Path) -> str:
    text = read_text(path)
    if "veltodensi.py" in text:
        return "density_seed"
    return "vs_seed"


def parse_numeric_config(path: Path) -> list:
    numeric_lines = []
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if re.match(r"^[0-9eE+.\-\s]+$", line):
            numeric_lines.append([float(x) for x in line.split()])
    return numeric_lines


def parse_jointsg_params(path: Path) -> Dict[str, float]:
    numeric = parse_numeric_config(path)
    if len(numeric) < 18:
        raise ValueError(f"Unexpected JointSG.in layout: {path}")
    dims = numeric[0]
    smooth_damp = numeric[5]
    noise = numeric[15]
    p_line = numeric[16]
    std_line = numeric[17]
    return {
        "nlat": int(dims[0]),
        "nlon": int(dims[1]),
        "nz": int(dims[2]),
        "smooth_joint": float(smooth_damp[0]),
        "damp_joint": float(smooth_damp[1]),
        "noise_traveltime": float(noise[0]),
        "noise_gravity": float(noise[1]),
        "p": float(p_line[0]),
        "sigmat": float(std_line[0]),
        "sigmag": float(std_line[1]),
    }


def find_last_float_pair(pattern: str, text: str) -> Tuple[float, float]:
    matches = re.findall(pattern, text)
    if not matches:
        return (math.nan, math.nan)
    mean_s, rms_s = matches[-1]
    return float(mean_s), float(rms_s)


def parse_info_metrics(path: Path) -> Dict[str, float]:
    text = read_text(path)
    ns_match = re.search(r"The number of traveltime measurements =\s*(\d+)", text)
    ng_match = re.search(r"The number of gravity measurements =\s*(\d+)", text)
    surf_mean, surf_rms = find_last_float_pair(
        r"mean and rms of traveltime residuals .*?:\s*([0-9eE+.\-]+)\s+([0-9eE+.\-]+)",
        text,
    )
    grav_mean, grav_rms = find_last_float_pair(
        r"mean and rms of gravity residuals .*?:\s*([0-9eE+.\-]+)\s+([0-9eE+.\-]+)",
        text,
    )
    return {
        "ns": int(ns_match.group(1)) if ns_match else math.nan,
        "ng": int(ng_match.group(1)) if ng_match else math.nan,
        "surf_mean": surf_mean,
        "surf_rms": surf_rms,
        "grav_mean": grav_mean,
        "grav_rms": grav_rms,
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


def residual_norm_from_files(
    surf_path: Path,
    grav_path: Path,
    p: float,
    sigmat: float,
    sigmag: float,
) -> Tuple[float, float, float]:
    surf = np.loadtxt(surf_path, usecols=(1, 2))
    grav = np.loadtxt(grav_path, usecols=(2, 3))
    ns = surf.shape[0]
    ng = grav.shape[0]
    surf_sq = float(np.sum((surf[:, 1] - surf[:, 0]) ** 2))
    grav_sq = float(np.sum((grav[:, 1] - grav[:, 0]) ** 2))
    res_s = math.sqrt(p * surf_sq / (sigmat * sigmat))
    res_g = math.sqrt((1.0 - p) * ns * grav_sq / (ng * sigmag * sigmag))
    res_all = math.sqrt(res_s * res_s + res_g * res_g)
    return res_s, res_g, res_all


def residual_norm_from_rms(
    ns: int,
    ng: int,
    surf_rms: float,
    grav_rms: float,
    p: float,
    sigmat: float,
    sigmag: float,
) -> Tuple[float, float, float]:
    surf_sq = ns * surf_rms * surf_rms
    grav_sq = ng * grav_rms * grav_rms
    res_s = math.sqrt(p * surf_sq / (sigmat * sigmat))
    res_g = math.sqrt((1.0 - p) * ns * grav_sq / (ng * sigmag * sigmag))
    res_all = math.sqrt(res_s * res_s + res_g * res_g)
    return res_s, res_g, res_all


def build_row(run_dir: Path) -> Dict[str, float]:
    run_name = run_dir.name
    cg_path = run_dir / "scripts" / "crossgradient_inversion.py"
    run_script = run_dir / "scripts" / "run.sh"
    jointsg_path = run_dir / "params" / "gravity_JointSG.in"
    joint_info = run_dir / "logs" / "info_joint10.txt"
    surf_info = run_dir / "logs" / "info_surf10.txt"
    joint_model = run_dir / "models" / "joint_mod_iter.dat"
    initial_model = run_dir / "models" / "initial_joint_model.dat"
    surf_residual = run_dir / "residuals" / "res_surf_final.dat"
    grav_residual = run_dir / "residuals" / "res_grav_final.dat"

    if not (cg_path.exists() and jointsg_path.exists() and joint_info.exists() and joint_model.exists()):
        raise FileNotFoundError(f"Missing required files in {run_dir}")

    cg_params = parse_crossgradient_params(cg_path)
    joint_params = parse_jointsg_params(jointsg_path)
    joint_metrics = parse_info_metrics(joint_info)
    surf_metrics = parse_info_metrics(surf_info) if surf_info.exists() else {}
    workflow_mode = parse_workflow_mode(run_script) if run_script.exists() else "unknown"

    if surf_residual.exists() and grav_residual.exists():
        res_s, res_g, res_all = residual_norm_from_files(
            surf_residual,
            grav_residual,
            joint_params["p"],
            joint_params["sigmat"],
            joint_params["sigmag"],
        )
        residual_source = "raw_residual_files"
    else:
        res_s, res_g, res_all = residual_norm_from_rms(
            int(joint_metrics["ns"]),
            int(joint_metrics["ng"]),
            joint_metrics["surf_rms"],
            joint_metrics["grav_rms"],
            joint_params["p"],
            joint_params["sigmat"],
            joint_params["sigmag"],
        )
        residual_source = "info_log_rms"

    final_values = load_model_values(
        joint_model,
        joint_params["nlat"],
        joint_params["nlon"],
        joint_params["nz"],
    )
    final_model_l2 = float(np.sqrt(np.sum(final_values * final_values)))
    final_model_lm = laplacian_like_norm(final_values)

    update_l2 = math.nan
    update_lm = math.nan
    update_source = ""
    if initial_model.exists():
        init_values = load_model_values(
            initial_model,
            joint_params["nlat"],
            joint_params["nlon"],
            joint_params["nz"],
        )
        delta = final_values - init_values
        update_l2 = float(np.sqrt(np.sum(delta * delta)))
        update_lm = laplacian_like_norm(delta)
        update_source = "initial_joint_model.dat"

    row = {
        "run_name": run_name,
        "workflow_mode": workflow_mode,
        "alpha_s": cg_params["alpha_s"],
        "alpha_g": cg_params["alpha_g"],
        "beta_t": cg_params["beta_t"],
        "smooth_joint": joint_params["smooth_joint"],
        "damp_joint": joint_params["damp_joint"],
        "p": joint_params["p"],
        "sigmat": joint_params["sigmat"],
        "sigmag": joint_params["sigmag"],
        "ns": joint_metrics["ns"],
        "ng": joint_metrics["ng"],
        "standalone_surf_rms": surf_metrics.get("surf_rms", math.nan),
        "joint_surf_rms": joint_metrics["surf_rms"],
        "joint_grav_rms": joint_metrics["grav_rms"],
        "weighted_res_s": res_s,
        "weighted_res_g": res_g,
        "weighted_res_all": res_all,
        "weighted_res_all_sq": res_all * res_all,
        "residual_source": residual_source,
        "final_model_l2": final_model_l2,
        "final_model_lm": final_model_lm,
        "final_model_lm_sq": final_model_lm * final_model_lm,
        "update_l2": update_l2,
        "update_lm": update_lm,
        "update_lm_sq": update_lm * update_lm if math.isfinite(update_lm) else math.nan,
        "update_source": update_source,
    }
    return row


def choose_model_field(rows: List[Dict[str, float]]) -> str:
    if rows and all(math.isfinite(row["update_lm"]) for row in rows):
        return "update_lm"
    return "final_model_lm"


def label_for(row: Dict[str, float], annotate: str) -> str:
    if annotate == "smooth_joint":
        return f"{row['smooth_joint']:g}"
    if annotate == "beta_t":
        return f"bt={row['beta_t']:g}"
    if annotate == "alpha_g":
        return f"ag={row['alpha_g']:g}"
    if annotate == "workflow_mode":
        return row["workflow_mode"]
    return row["run_name"].replace("run_", "")


def maybe_plot(
    rows: List[Dict[str, float]],
    output_path: Path,
    model_field: str,
    annotate: str,
    plot_style: str,
    highlight_smooth: float,
) -> bool:
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        return False

    if not rows:
        return False

    rows = sorted(rows, key=lambda row: row["smooth_joint"])
    if plot_style == "sample":
        x = [row["weighted_res_all_sq"] for row in rows]
        y_field = "update_lm_sq" if model_field == "update_lm" else "final_model_lm_sq"
        y = [row[y_field] for row in rows]
        line_color = "#ff0000"
        point_color = "#ff0000"
        xlabel = r"$||Wr||_2^2$"
        ylabel = r"$||Dm||_2^2$" if model_field == "update_lm" else r"$||Lm||_2^2$"
    else:
        x = [row[model_field] for row in rows]
        y_field = "weighted_res_all"
        y = [row[y_field] for row in rows]
        line_color = "#444444"
        point_color = None
        xlabel = "Model-update norm" if model_field == "update_lm" else "Final-model roughness"
        ylabel = "Weighted residual norm"

    colors = {
        "vs_seed": "#1f77b4",
        "density_seed": "#d62728",
        "unknown": "#7f7f7f",
    }

    fig, ax = plt.subplots(figsize=(8.5, 6.0), dpi=160)
    ax.plot(x, y, color=line_color, linewidth=1.8, zorder=1)
    for row in rows:
        x_value = row["weighted_res_all_sq"] if plot_style == "sample" else row[model_field]
        y_value = row[y_field]
        marker_color = point_color or colors.get(row["workflow_mode"], "#7f7f7f")
        ax.scatter(
            x_value,
            y_value,
            s=48,
            color=marker_color,
            zorder=2,
        )
        ax.annotate(
            label_for(row, annotate),
            (x_value, y_value),
            xytext=(6, 6),
            textcoords="offset points",
            fontsize=12,
            color="#0000cc"
            if annotate == "smooth_joint" and abs(row["smooth_joint"] - highlight_smooth) < 1e-9
            else "black",
        )

    if plot_style == "loglog":
        ax.set_xscale("log")
        ax.set_yscale("log")
    ax.set_xlabel(xlabel, fontsize=15)
    ax.set_ylabel(ylabel, fontsize=15)
    ax.set_title("L-curve", fontsize=17)
    ax.tick_params(axis="both", labelsize=12)
    if plot_style == "sample":
        ax.grid(False)
    else:
        ax.grid(True, which="both", linestyle="--", linewidth=0.5, alpha=0.4)
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
        if args.workflow_mode != "all" and row["workflow_mode"] != args.workflow_mode:
            continue
        rows.append(row)

    rows.sort(key=lambda row: (row["beta_t"], row["alpha_g"], row["run_name"]))

    csv_path = args.output_dir / "lcurve_metrics.csv"
    write_csv(rows, csv_path)

    model_field = choose_model_field(rows)
    plot_path = args.output_dir / "lcurve.png"
    plotted = maybe_plot(
        rows,
        plot_path,
        model_field,
        args.annotate,
        args.plot_style,
        args.highlight_smooth,
    )

    print(f"Exports root: {args.exports_root}")
    print(f"Output CSV: {csv_path}")
    if plotted:
        print(f"Output figure: {plot_path}")
    else:
        print("Output figure: skipped (matplotlib unavailable or no rows)")
    print(f"Model field: {model_field}")
    print(f"Plot style: {args.plot_style}")
    print(f"Included runs: {len(rows)}")
    for row in rows:
        print(
            f"{row['run_name']}: workflow={row['workflow_mode']}, "
            f"smooth={row['smooth_joint']}, alpha_g={row['alpha_g']}, beta_t={row['beta_t']}, "
            f"weighted_res_all={row['weighted_res_all']:.6f}, "
            f"{model_field}={row[model_field]:.6f}"
        )
    if skipped:
        print("Skipped runs:")
        for name, reason in skipped:
            print(f"  {name}: {reason}")


if __name__ == "__main__":
    main()
