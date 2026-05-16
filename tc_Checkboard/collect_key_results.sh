#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d_%H%M%S)"
DEFAULT_DEST="${SCRIPT_DIR}/exports/run_${STAMP}"

DEST="${1:-$DEFAULT_DEST}"
if [[ $# -gt 0 ]]; then
  shift
fi

mkdir -p "$DEST"

copy_if_exists() {
  local src="$1"
  local rel="$2"
  if [[ -e "$src" ]]; then
    mkdir -p "$(dirname "$DEST/$rel")"
    cp -f "$src" "$DEST/$rel"
  fi
}

copy_glob() {
  local pattern="$1"
  local rel_dir="$2"
  shopt -s nullglob
  local files=( $pattern )
  shopt -u nullglob
  if [[ ${#files[@]} -eq 0 ]]; then
    return
  fi
  mkdir -p "$DEST/$rel_dir"
  for src in "${files[@]}"; do
    cp -f "$src" "$DEST/$rel_dir/"
  done
}

copy_if_exists "$SCRIPT_DIR/run.sh" "scripts/run.sh"
copy_if_exists "$SCRIPT_DIR/crossgradient_inversion.py" "scripts/crossgradient_inversion.py"
copy_if_exists "$SCRIPT_DIR/surf_inv/DSurfTomo.in" "params/surf_inv_DSurfTomo.in"
copy_if_exists "$SCRIPT_DIR/gravity_inv/JointSG.in" "params/gravity_JointSG.in"

copy_if_exists "$SCRIPT_DIR/results/runtime.txt" "logs/runtime.txt"
copy_if_exists "$SCRIPT_DIR/logs/terminal_output.log" "logs/terminal_output.log"
copy_if_exists "$SCRIPT_DIR/surf_inv/info_surf10.txt" "logs/info_surf10.txt"
copy_if_exists "$SCRIPT_DIR/gravity_inv/info_joint.txt" "logs/info_joint.txt"
copy_if_exists "$SCRIPT_DIR/gravity_inv/info_joint10.txt" "logs/info_joint10.txt"
copy_if_exists "$SCRIPT_DIR/info_mkmat.txt" "logs/info_mkmat.txt"

copy_glob "$SCRIPT_DIR/logs/*" "logs/extra_logs"

copy_if_exists "$SCRIPT_DIR/results/mod_iter.dat" "models/mod_iter.dat"
copy_if_exists "$SCRIPT_DIR/results/joint_mod_iter.dat" "models/joint_mod_iter.dat"
copy_if_exists "$SCRIPT_DIR/results/MOD" "models/MOD"

copy_if_exists "$SCRIPT_DIR/results/gmt_vel_joint/Fig1/Fig6_checker_1.jpg" "figures/Fig1/Fig6_checker_1.jpg"
copy_if_exists "$SCRIPT_DIR/results/gmt_vel_joint/Fig1/Fig6_checker_2.jpg" "figures/Fig1/Fig6_checker_2.jpg"
copy_if_exists "$SCRIPT_DIR/results/gmt_vel_joint/Fig1/Fig6_checker_depth.pdf" "figures/Fig1/Fig6_checker_depth.pdf"

copy_glob "$SCRIPT_DIR/results/gmt_vel_joint/allfig/*km.jpg" "figures/depth_slices"

for extra in "$@"; do
  if [[ -e "$extra" ]]; then
    copy_if_exists "$extra" "extras/$(basename "$extra")"
  fi
done

MANIFEST="$DEST/manifest.txt"
{
  echo "Collected at: $(date)"
  echo "Source: $SCRIPT_DIR"
  echo "Destination: $DEST"
  echo
  echo "Included files:"
  find "$DEST" -type f | sed "s#^$DEST/##" | sort
} > "$MANIFEST"

FILE_COUNT="$(find "$DEST" -type f | wc -l | awk '{print $1}')"
DIR_COUNT="$(find "$DEST" -type d | wc -l | awk '{print $1}')"

echo
echo "========================================"
echo "Collected key results successfully."
echo "Output folder:"
echo "  $DEST"
echo "Manifest:"
echo "  $MANIFEST"
echo "Summary:"
echo "  Directories: $DIR_COUNT"
echo "  Files:       $FILE_COUNT"
echo
echo "Quick commands:"
echo "  cd \"$DEST\""
echo "  find \"$DEST\" -maxdepth 2 -type f | sort"
echo
echo "Top-level contents:"
find "$DEST" -maxdepth 2 \( -type d -o -type f \) | sed "s#^$DEST#.#" | sort
echo "========================================"
