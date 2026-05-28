#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/run.sh" ]; then
    ROOT_DIR="$SCRIPT_DIR"
else
    ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
cd "$ROOT_DIR"

ALPHA_S_VALUES="${ALPHA_S_VALUES:-1.0}"
ALPHA_G_VALUES="${ALPHA_G_VALUES:-0.2 0.4 0.6 0.8 1.0}"
BETA_T_VALUES="${BETA_T_VALUES:-0 0.002 0.005 0.01 0.02 0.05}"
SWEEP_NAME="${SWEEP_NAME:-cross_param_sweep}"
SWEEP_ROOT="${SWEEP_ROOT:-$ROOT_DIR/exports/$SWEEP_NAME}"
SUMMARY_FILE="$SWEEP_ROOT/sweep_summary.tsv"

mkdir -p "$SWEEP_ROOT"

format_tag() {
    local value="$1"
    printf "%0.5f" "$value" | sed 's/-/m/g; s/\./p/g'
}

extract_last_float() {
    local logfile="$1"
    local pattern="$2"
    awk -v pattern="$pattern" '
        $0 ~ pattern { value=$NF }
        END {
            if (value == "") {
                print "nan"
            } else {
                print value
            }
        }
    ' "$logfile"
}

extract_last_rms() {
    local logfile="$1"
    local pattern="$2"
    awk -v pattern="$pattern" '
        $0 ~ pattern { value=$NF }
        END {
            if (value == "") {
                print "nan"
            } else {
                print value
            }
        }
    ' "$logfile"
}

write_case_param_file() {
    local export_dir="$1"
    local alpha_s="$2"
    local alpha_g="$3"
    local beta_t="$4"
    mkdir -p "$export_dir/params"
    cat > "$export_dir/params/cross_sweep_params.txt" <<EOF
alpha_s=$alpha_s
alpha_g=$alpha_g
beta_t=$beta_t
EOF
}

{
    echo -e "alpha_s\talpha_g\tbeta_t\texport_dir\tstandalone_surf_rms\tjoint_surf_rms\tjoint_grav_rms\trel_rms_change_s\trel_rms_change_g"
} > "$SUMMARY_FILE"

for alpha_s in $ALPHA_S_VALUES; do
    for alpha_g in $ALPHA_G_VALUES; do
        for beta_t in $BETA_T_VALUES; do
            as_tag="$(format_tag "$alpha_s")"
            ag_tag="$(format_tag "$alpha_g")"
            bt_tag="$(format_tag "$beta_t")"
            export_dir="$SWEEP_ROOT/as_${as_tag}_ag_${ag_tag}_bt_${bt_tag}"

            echo "===== Cross sweep alpha_s=$alpha_s alpha_g=$alpha_g beta_t=$beta_t ====="
            export CROSS_ALPHA_S="$alpha_s"
            export CROSS_ALPHA_G="$alpha_g"
            export CROSS_BETA_T="$beta_t"
            export EXPORT_TARGET_DIR="$export_dir"

            bash "$ROOT_DIR/run.sh"

            unset EXPORT_TARGET_DIR
            unset CROSS_ALPHA_S
            unset CROSS_ALPHA_G
            unset CROSS_BETA_T

            write_case_param_file "$export_dir" "$alpha_s" "$alpha_g" "$beta_t"

            surf_info="$export_dir/logs/info_surf10.txt"
            joint_info="$export_dir/logs/info_joint10.txt"
            terminal_log="$export_dir/logs/terminal_output.log"

            standalone_surf_rms="$(extract_last_rms "$surf_info" "mean and rms of traveltime residuals")"
            joint_surf_rms="$(extract_last_rms "$joint_info" "mean and rms of traveltime residuals after inversion")"
            joint_grav_rms="$(extract_last_rms "$joint_info" "mean and rms of gravity residuals after inversion")"
            rel_rms_change_s="$(extract_last_float "$terminal_log" "DEBUG: rel_rms_change_s")"
            rel_rms_change_g="$(extract_last_float "$terminal_log" "DEBUG: rel_rms_change_(g|rho_g)")"

            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
                "$alpha_s" "$alpha_g" "$beta_t" "$export_dir" \
                "$standalone_surf_rms" "$joint_surf_rms" "$joint_grav_rms" \
                "$rel_rms_change_s" "$rel_rms_change_g" >> "$SUMMARY_FILE"
        done
    done
done

echo "Sweep finished."
echo "Summary: $SUMMARY_FILE"
echo "Summarize next with:"
echo "C:\\Users\\Chp\\.local\\bin\\python3.11.exe $SCRIPT_DIR\\summarize_cross_param_sweep.py --exports-root $SWEEP_ROOT --output-dir $SWEEP_ROOT\\summary"
