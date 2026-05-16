#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_ROOT="$ROOT_DIR/exports"

timestamp="$(date +%Y%m%d_%H%M%S)"
TARGET_DIR="${1:-$EXPORT_ROOT/run_$timestamp}"

mkdir -p "$TARGET_DIR"
mkdir -p "$TARGET_DIR/scripts" "$TARGET_DIR/params" "$TARGET_DIR/models" "$TARGET_DIR/figures" "$TARGET_DIR/logs"

copy_file() {
    local src="$1"
    local dst="$2"
    if [ -f "$src" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
    fi
}

copy_dir() {
    local src="$1"
    local dst="$2"
    if [ -d "$src" ]; then
        mkdir -p "$(dirname "$dst")"
        cp -r "$src" "$dst"
    fi
}

copy_file "$ROOT_DIR/crossgradient_inversion.py" "$TARGET_DIR/scripts/crossgradient_inversion.py"
copy_file "$ROOT_DIR/run.sh" "$TARGET_DIR/scripts/run.sh"
copy_file "$ROOT_DIR/veltodensi.py" "$TARGET_DIR/scripts/veltodensi.py"
copy_file "$ROOT_DIR/readme.md" "$TARGET_DIR/scripts/readme.md"

copy_file "$ROOT_DIR/surf_inv/DSurfTomo.in" "$TARGET_DIR/params/surf_DSurfTomo.in"
copy_file "$ROOT_DIR/gravity_inv/JointSG.in" "$TARGET_DIR/params/gravity_JointSG.in"

copy_file "$ROOT_DIR/runtime.txt" "$TARGET_DIR/runtime.txt"
copy_dir "$ROOT_DIR/logs" "$TARGET_DIR/logs/extra_logs"

copy_file "$ROOT_DIR/logs/terminal_output.log" "$TARGET_DIR/logs/terminal_output.log"
copy_file "$ROOT_DIR/surf_inv/info_surf10.txt" "$TARGET_DIR/logs/info_surf10.txt"
copy_file "$ROOT_DIR/gravity_inv/info_joint10.txt" "$TARGET_DIR/logs/info_joint10.txt"
copy_file "$ROOT_DIR/gravity_inv/info_mkmat.txt" "$TARGET_DIR/logs/info_mkmat.txt"

copy_file "$ROOT_DIR/results/mod_iter.dat" "$TARGET_DIR/models/mod_iter.dat"
copy_file "$ROOT_DIR/results/joint_mod_iter.dat" "$TARGET_DIR/models/joint_mod_iter.dat"
copy_file "$ROOT_DIR/results/MOD" "$TARGET_DIR/models/MOD"

copy_dir "$ROOT_DIR/results/surf" "$TARGET_DIR/figures/surf"
copy_dir "$ROOT_DIR/results/gravity" "$TARGET_DIR/figures/gravity"
copy_dir "$ROOT_DIR/results/gmt_slice_ref" "$TARGET_DIR/figures/gmt_slice_ref"

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
