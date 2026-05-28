#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/run.sh" ]; then
    ROOT_DIR="$SCRIPT_DIR"
else
    ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
SURF_DIR="$ROOT_DIR/surf_inv"
cd "$ROOT_DIR"

DSURF_FILE="$SURF_DIR/DSurfTomo.in"
BACKUP_FILE="$SURF_DIR/DSurfTomo.in.lcurve_backup"

FIXED_DAMP="${FIXED_DAMP:-0.01}"
SMOOTH_VALUES="${SMOOTH_VALUES:-2 3 4 5 6 7 8 9 10 12 15 20}"
SWEEP_NAME="${SWEEP_NAME:-surfinv_singlemodule_smooth_damp_${FIXED_DAMP}}"
SWEEP_ROOT="${SWEEP_ROOT:-$ROOT_DIR/exports/$SWEEP_NAME}"
SUMMARY_FILE="$SWEEP_ROOT/sweep_summary.txt"

mkdir -p "$SWEEP_ROOT"
cp "$DSURF_FILE" "$BACKUP_FILE"

restore_dsurf() {
    if [ -f "$BACKUP_FILE" ]; then
        mv -f "$BACKUP_FILE" "$DSURF_FILE"
    fi
}

trap restore_dsurf EXIT

set_dsurf_smooth_damp() {
    local smooth="$1"
    local damp="$2"
    awk -v smooth="$smooth" -v damp="$damp" '
        /# smooth damp/ {
            printf "%.6f %.6f                        # smooth damp\n", smooth, damp
            next
        }
        { print }
    ' "$BACKUP_FILE" > "$DSURF_FILE"
}

extract_surf_rms() {
    local logfile="$1"
    awk '
        /mean and rms of traveltime residuals/ { a=$(NF-1); b=$NF }
        END {
            if (a == "" || b == "") {
                print "nan nan"
            } else {
                print a, b
            }
        }
    ' "$logfile"
}

copy_file() {
    local src="$1"
    local dst="$2"
    if [ -f "$src" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
    fi
}

export_one_case() {
    local export_dir="$1"
    mkdir -p "$export_dir"/{logs,models,params}
    copy_file "$SURF_DIR/DSurfTomo.in" "$export_dir/params/DSurfTomo.in"
    copy_file "$SURF_DIR/info_surf.txt" "$export_dir/logs/info_surf.txt"
    copy_file "$SURF_DIR/runtime1.txt" "$export_dir/runtime1.txt"
    copy_file "$SURF_DIR/results/res1.dat" "$export_dir/logs/res1.dat"
    copy_file "$SURF_DIR/results/mod_iter0.dat" "$export_dir/models/mod_iter0.dat"
    copy_file "$SURF_DIR/results/mod_iter1.dat" "$export_dir/models/mod_iter1.dat"
    copy_file "$SURF_DIR/results/delta_ms0.dat" "$export_dir/models/delta_ms0.dat"
}

{
    echo "# surf_inv single-module smooth sweep"
    echo "# fixed_damp = $FIXED_DAMP"
    echo "# smooth_values = $SMOOTH_VALUES"
    echo "# sweep_root = $SWEEP_ROOT"
    echo "smooth export_dir surf_rms"
} > "$SUMMARY_FILE"

for smooth in $SMOOTH_VALUES; do
    smooth_tag="$(printf "%06.2f" "$smooth" | tr ' ' '0')"
    export_dir="$SWEEP_ROOT/sm_${smooth_tag}"

    echo "===== surf_inv single-module sweep smooth = $smooth, damp = $FIXED_DAMP ====="
    set_dsurf_smooth_damp "$smooth" "$FIXED_DAMP"

    (
        cd "$SURF_DIR"
        bash run.sh
    )

    export_one_case "$export_dir"
    info_file="$export_dir/logs/info_surf.txt"
    read -r _ surf_rms < <(extract_surf_rms "$info_file")
    printf "%s %s %s\n" "$smooth" "$export_dir" "$surf_rms" >> "$SUMMARY_FILE"
done

echo "Sweep finished."
echo "Summary: $SUMMARY_FILE"
echo "Plot next with:"
echo "uv run python $SCRIPT_DIR/plot_surfinv_lcurve.py --exports-root $SWEEP_ROOT --output-dir $SWEEP_ROOT/lcurve_summary"
