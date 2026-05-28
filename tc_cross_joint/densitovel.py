#!/usr/bin/env python3
"""Convert a lon/lat/depth/density table to Vs using Brocher (2005)."""

import argparse
import sys

import numpy as np

from veltodensi import brocher_vs_to_rho


def invert_density_to_vs(rho, vs_min=1.5, vs_max=5.5, tol=1.0e-7, max_iter=80, strict=False):
    rho = np.asarray(rho, dtype=float)
    lo = np.full_like(rho, float(vs_min), dtype=float)
    hi = np.full_like(rho, float(vs_max), dtype=float)

    rho_lo = brocher_vs_to_rho(lo)
    rho_hi = brocher_vs_to_rho(hi)
    rho_min = np.minimum(rho_lo, rho_hi)
    rho_max = np.maximum(rho_lo, rho_hi)

    below = rho < rho_min
    above = rho > rho_max
    out_of_range = below | above
    if np.any(out_of_range) and strict:
        count = int(np.count_nonzero(out_of_range))
        print(
            "Error: {} density values are outside the Brocher range for Vs=[{}, {}].".format(
                count, vs_min, vs_max
            ),
            file=sys.stderr,
        )
        sys.exit(1)

    target = np.clip(rho, rho_min, rho_max)

    increasing = rho_hi >= rho_lo
    for _ in range(max_iter):
        mid = 0.5 * (lo + hi)
        rho_mid = brocher_vs_to_rho(mid)
        go_right = rho_mid < target if increasing.all() else rho_mid > target
        lo = np.where(go_right, mid, lo)
        hi = np.where(go_right, hi, mid)
        if np.max(hi - lo) < tol:
            break

    vs = 0.5 * (lo + hi)
    return vs, below, above


def parse_args():
    parser = argparse.ArgumentParser(
        description="Convert density to S-wave velocity by numerically inverting Brocher (2005)."
    )
    parser.add_argument("input_model", help="Input table with columns: lon lat depth density.")
    parser.add_argument("output_model", help="Output table with columns: lon lat depth Vs.")
    parser.add_argument("--vs-min", type=float, default=1.5, help="Minimum Vs allowed in inversion.")
    parser.add_argument("--vs-max", type=float, default=5.5, help="Maximum Vs allowed in inversion.")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Fail if any density lies outside the invertible density range.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    if args.vs_min >= args.vs_max:
        print("Error: --vs-min must be smaller than --vs-max.", file=sys.stderr)
        sys.exit(1)

    try:
        data = np.loadtxt(args.input_model)
    except OSError:
        print(f"Error: Cannot open {args.input_model}", file=sys.stderr)
        sys.exit(1)

    if data.ndim != 2 or data.shape[1] < 4:
        print("Error: input model must have at least four columns.", file=sys.stderr)
        sys.exit(1)

    vs, below, above = invert_density_to_vs(
        data[:, 3],
        vs_min=args.vs_min,
        vs_max=args.vs_max,
        strict=args.strict,
    )

    output = data[:, :4].copy()
    output[:, 3] = vs
    np.savetxt(args.output_model, output, fmt="%.6f %.6f %.6f %.6f")

    clipped = int(np.count_nonzero(below | above))
    print(f"Successfully converted density to Vs: {args.output_model}")
    if clipped:
        print(
            "Warning: {} density values were outside the Brocher range and were clipped to Vs bounds.".format(
                clipped
            )
        )


if __name__ == "__main__":
    main()
