#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/run.sh" ]; then
    ROOT_DIR="$SCRIPT_DIR"
else
    ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
cd "$ROOT_DIR"

JOINTSG_FILE="$ROOT_DIR/gravity_inv/JointSG.in"
BACKUP_FILE="$ROOT_DIR/gravity_inv/JointSG.in.lcurve_backup"

FIXED_DAMP="${FIXED_DAMP:-0.01}"
SMOOTH_VALUES="${SMOOTH_VALUES:-1 2 4 6 8 10 15 20 30 40 60 80}"
SWEEP_NAME="${SWEEP_NAME:-jointsg_smooth_damp_${FIXED_DAMP}}"
SWEEP_ROOT="${SWEEP_ROOT:-$ROOT_DIR/exports/$SWEEP_NAME}"
SUMMARY_FILE="$SWEEP_ROOT/sweep_summary.txt"

mkdir -p "$SWEEP_ROOT"
cp "$JOINTSG_FILE" "$BACKUP_FILE"

restore_jointsg() {
    if [ -f "$BACKUP_FILE" ]; then
        mv -f "$BACKUP_FILE" "$JOINTSG_FILE"
    fi
}

trap restore_jointsg EXIT

set_jointsg_smooth_damp() {
    local smooth="$1"
    local damp="$2"
    awk -v smooth="$smooth" -v damp="$damp" '
        /# smooth damp/ {
            printf "%.6f %.6f                         # smooth damp\n", smooth, damp
            next
        }
        { print }
    ' "$BACKUP_FILE" > "$JOINTSG_FILE"
}

extract_rms() {
    local logfile="$1"
    local pattern="$2"
    awk -v pattern="$pattern" '
        $0 ~ pattern { a=$(NF-1); b=$NF }
        END {
            if (a == "" || b == "") {
                print "nan nan"
            } else {
                print a, b
            }
        }
    ' "$logfile"
}

{
    echo "# JointSG smooth sweep"
    echo "# fixed_damp = $FIXED_DAMP"
    echo "# smooth_values = $SMOOTH_VALUES"
    echo "# sweep_root = $SWEEP_ROOT"
    echo "smooth export_dir joint_surf_rms joint_grav_rms"
} > "$SUMMARY_FILE"

for smooth in $SMOOTH_VALUES; do
    smooth_tag="$(printf "%06.2f" "$smooth" | tr ' ' '0')"
    export_dir="$SWEEP_ROOT/sm_${smooth_tag}"

    echo "===== Sweep smooth = $smooth, damp = $FIXED_DAMP ====="
    set_jointsg_smooth_damp "$smooth" "$FIXED_DAMP"

    export EXPORT_TARGET_DIR="$export_dir"
    bash "$ROOT_DIR/run.sh"
    unset EXPORT_TARGET_DIR

    info_joint="$export_dir/logs/info_joint10.txt"
    read -r _ joint_surf_rms < <(extract_rms "$info_joint" "mean and rms of traveltime residuals after inversion")
    read -r _ joint_grav_rms < <(extract_rms "$info_joint" "mean and rms of gravity residuals after inversion")

    printf "%s %s %s %s\n" "$smooth" "$export_dir" "$joint_surf_rms" "$joint_grav_rms" >> "$SUMMARY_FILE"
done

echo "Sweep finished."
echo "Summary: $SUMMARY_FILE"
echo "Plot next with:"
echo "uv run python $SCRIPT_DIR/plot_jointsg_lcurve.py --exports-root $SWEEP_ROOT --output-dir $SWEEP_ROOT/lcurve_summary --workflow-mode vs_seed"
