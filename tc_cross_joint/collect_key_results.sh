#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_ROOT="$ROOT_DIR/exports"

timestamp="$(date +%Y%m%d_%H%M%S)"
TARGET_DIR="${1:-${EXPORT_TARGET_DIR:-$EXPORT_ROOT/run_$timestamp}}"

mkdir -p "$TARGET_DIR"
mkdir -p "$TARGET_DIR/scripts" "$TARGET_DIR/params" "$TARGET_DIR/models" "$TARGET_DIR/figures" "$TARGET_DIR/logs" "$TARGET_DIR/residuals"

copy_file() {
    local src="$1"
    local dst="$2"
    if [ -f "$src" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
    fi
}

copy_glob() {
    local pattern="$1"
    local dst_dir="$2"
    shopt -s nullglob
    local files=( $pattern )
    shopt -u nullglob
    if [ ${#files[@]} -eq 0 ]; then
        return
    fi
    mkdir -p "$dst_dir"
    for src in "${files[@]}"; do
        cp "$src" "$dst_dir/"
    done
}

copy_slice_images() {
    local src_root="$1"
    local dst_dir="$2"
    local slice_dir
    shopt -s nullglob
    for slice_dir in "$src_root"/*_sli; do
        if [ -d "$slice_dir" ]; then
            copy_glob "$slice_dir/*.jpg" "$dst_dir"
        fi
    done
    shopt -u nullglob
}

copy_file "$ROOT_DIR/crossgradient_inversion.py" "$TARGET_DIR/scripts/crossgradient_inversion.py"
copy_file "$ROOT_DIR/veltodensi.py" "$TARGET_DIR/scripts/veltodensi.py"
copy_file "$ROOT_DIR/densitovel.py" "$TARGET_DIR/scripts/densitovel.py"
copy_file "$ROOT_DIR/run.sh" "$TARGET_DIR/scripts/run.sh"

copy_file "$ROOT_DIR/surf_inv/DSurfTomo.in" "$TARGET_DIR/params/surf_DSurfTomo.in"
copy_file "$ROOT_DIR/gravity_inv/JointSG.in" "$TARGET_DIR/params/gravity_JointSG.in"

copy_file "$ROOT_DIR/runtime.txt" "$TARGET_DIR/runtime.txt"

# Keep only the key logs needed to understand and reproduce the run.
copy_file "$ROOT_DIR/logs/terminal_output.log" "$TARGET_DIR/logs/terminal_output.log"
copy_file "$ROOT_DIR/logs/surf_inv_direct.log" "$TARGET_DIR/logs/surf_inv_direct.log"
copy_file "$ROOT_DIR/logs/gravity_initial.log" "$TARGET_DIR/logs/gravity_initial.log"
copy_file "$ROOT_DIR/logs/mkmat.log" "$TARGET_DIR/logs/mkmat.log"
copy_file "$ROOT_DIR/logs/surf_iter10.log" "$TARGET_DIR/logs/surf_iter10.log"
copy_file "$ROOT_DIR/logs/gravity_iter10.log" "$TARGET_DIR/logs/gravity_iter10.log"
copy_file "$ROOT_DIR/logs/results_surf.log" "$TARGET_DIR/logs/results_surf.log"
copy_file "$ROOT_DIR/logs/results_gravity.log" "$TARGET_DIR/logs/results_gravity.log"
copy_file "$ROOT_DIR/surf_inv/info_surf10.txt" "$TARGET_DIR/logs/info_surf10.txt"
copy_file "$ROOT_DIR/gravity_inv/info_joint10.txt" "$TARGET_DIR/logs/info_joint10.txt"
copy_file "$ROOT_DIR/gravity_inv/info_mkmat.txt" "$TARGET_DIR/logs/info_mkmat.txt"

copy_file "$ROOT_DIR/results/mod_iter.dat" "$TARGET_DIR/models/mod_iter.dat"
copy_file "$ROOT_DIR/results/joint_mod_iter.dat" "$TARGET_DIR/models/joint_mod_iter.dat"
copy_file "$ROOT_DIR/results/joint_density_iter.dat" "$TARGET_DIR/models/joint_density_iter.dat"
copy_file "$ROOT_DIR/results/MOD" "$TARGET_DIR/models/MOD"
copy_file "$ROOT_DIR/surf_inv_direct/results/mod_iter10.dat" "$TARGET_DIR/models/initial_joint_model.dat"

# Keep the final residual files so later L-curve scripts can recover the
# weighted residual norm without rerunning the inversion.
copy_file "$ROOT_DIR/gravity_inv/results/res_surf1.dat" "$TARGET_DIR/residuals/res_surf_final.dat"
copy_file "$ROOT_DIR/gravity_inv/results/res_grav1.dat" "$TARGET_DIR/residuals/res_grav_final.dat"

# Keep exports lightweight by copying only final depth-slice images.
copy_glob "$ROOT_DIR/results/surf/allfig/*km.jpg" "$TARGET_DIR/figures/surf_depth_slices"
copy_glob "$ROOT_DIR/results/gravity/allfig/jpg/*km.jpg" "$TARGET_DIR/figures/gravity_depth_slices"
copy_glob "$ROOT_DIR/results/gravity/allfig/grav_inv_*.jpg" "$TARGET_DIR/figures/gravity_depth_slices"
copy_glob "$ROOT_DIR/results/gravity/allfig/grav_density_*.jpg" "$TARGET_DIR/figures/gravity_depth_slices"
copy_slice_images "$ROOT_DIR/results/gmt_slice_ref" "$TARGET_DIR/figures/gmt_slice_ref_depth_slices"
copy_file "$ROOT_DIR/results/gmt_slice_ref/colorbar/colorbar.jpg" "$TARGET_DIR/figures/gmt_slice_ref_depth_slices/colorbar.jpg"

if [ $# -gt 1 ]; then
    shift
    for extra_file in "$@"; do
        if [ -f "$extra_file" ]; then
            copy_file "$extra_file" "$TARGET_DIR/logs/$(basename "$extra_file")"
        fi
    done
fi

manifest="$TARGET_DIR/manifest.txt"
find "$TARGET_DIR" -type f | sort > "$manifest"

file_count=$(find "$TARGET_DIR" -type f | wc -l | tr -d ' ')
dir_count=$(find "$TARGET_DIR" -type d | wc -l | tr -d ' ')

echo "Collected key results."
echo "Output directory: $TARGET_DIR"
echo "Manifest: $manifest"
echo "File count: $file_count"
echo "Directory count: $dir_count"
echo "Use this command to open it:"
echo "cd \"$TARGET_DIR\""
