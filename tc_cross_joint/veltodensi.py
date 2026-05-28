#!/usr/bin/env python3
"""Convert a lon/lat/depth/Vs table to density using Brocher (2005)."""

import argparse
import sys

import numpy as np


def brocher_vs_to_vp(vs):
    return 0.9409 + 2.0947 * vs - 0.8206 * vs**2 + 0.2683 * vs**3 - 0.0251 * vs**4


def brocher_vp_to_rho(vp):
    return (
        1.6612 * vp
        - 0.4721 * vp**2
        + 0.0671 * vp**3
        - 0.0043 * vp**4
        + 0.000106 * vp**5
    )


def brocher_vs_to_rho(vs):
    return brocher_vp_to_rho(brocher_vs_to_vp(vs))


def parse_args():
    parser = argparse.ArgumentParser(
        description="Convert S-wave velocity to density with the Brocher (2005) relation."
    )
    parser.add_argument(
        "input_model",
        nargs="?",
        default="mod_iter10.dat",
        help="Input table with columns: lon lat depth Vs.",
    )
    parser.add_argument(
        "output_model",
        nargs="?",
        default="joint_densi_iter10.dat",
        help="Output table with columns: lon lat depth density.",
    )
    parser.add_argument(
        "--clip-density",
        nargs=2,
        type=float,
        metavar=("MIN", "MAX"),
        help="Optionally clip output density. Default: no clipping.",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    try:
        data = np.loadtxt(args.input_model)
    except OSError:
        print(f"Error: Cannot open {args.input_model}", file=sys.stderr)
        sys.exit(1)

    if data.ndim != 2 or data.shape[1] < 4:
        print("Error: input model must have at least four columns.", file=sys.stderr)
        sys.exit(1)

    output = data[:, :4].copy()
    output[:, 3] = brocher_vs_to_rho(data[:, 3])

    if args.clip_density is not None:
        lo, hi = args.clip_density
        if lo > hi:
            print("Error: --clip-density MIN must be <= MAX.", file=sys.stderr)
            sys.exit(1)
        output[:, 3] = np.clip(output[:, 3], lo, hi)

    np.savetxt(args.output_model, output, fmt="%.6f %.6f %.6f %.6f")
    print(f"Successfully converted Vs to density: {args.output_model}")


if __name__ == "__main__":
    main()
