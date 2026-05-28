# JointSG Smooth L-Curve

This workflow follows route A:

- keep the outer cross-gradient settings unchanged
- keep `damp` fixed
- sweep only the `smooth` value in [`gravity_inv/JointSG.in`](C:/Users/Chp/Documents/Maho/tc_cross_joint/gravity_inv/JointSG.in)

## What the curve means

For this project, each sweep point changes only the gravity-branch smoothing strength.

- smaller `smooth`: the gravity-side model can become rougher, and data fit may improve
- larger `smooth`: the gravity-side model is forced to be smoother, and data fit usually worsens

The L-curve compares:

- data residual norm
- model roughness norm

The preferred point is usually near the bend, where more smoothing starts to cost noticeably more misfit.

## Current caveat

The current [`gravity_inv/JointSG.in`](C:/Users/Chp/Documents/Maho/tc_cross_joint/gravity_inv/JointSG.in) uses `p=0`.

That means the combined weighted residual is effectively gravity-dominated. So this L-curve should be described as:

- a `JointSG` smooth-selection curve under the current `p=0` weighting

not as:

- a fully balanced two-dataset joint L-curve

## First-pass sweep

Default values in [`run_jointsg_smooth_sweep.sh`](C:/Users/Chp/Documents/Maho/tc_cross_joint/parameter_selection/run_jointsg_smooth_sweep.sh):

`1 2 4 6 8 10 15 20 30 40 60 80`

Fixed damping default:

`0.01`

## Run

After Python is available, a typical run is:

If this Windows machine still does not expose `python` in `PATH`, the lightest setup is:

```powershell
C:\Users\Chp\.local\bin\uv.exe python install 3.11
```

Then run the sweep inside the Linux or bash environment that already runs the inversion workflow.

```bash
bash parameter_selection/run_jointsg_smooth_sweep.sh
```

Or with explicit settings:

```bash
FIXED_DAMP=0.01 \
SMOOTH_VALUES="1 2 4 6 8 10 15 20 30 40 60 80" \
bash parameter_selection/run_jointsg_smooth_sweep.sh
```

Each run is exported into:

- [`exports/`](C:/Users/Chp/Documents/Maho/tc_cross_joint/exports)

under a dedicated sweep folder such as:

- `exports/jointsg_smooth_damp_0.01/sm_010.00`

## Plot

The plotting script reads exported runs and computes:

- weighted residual norm
- final-model roughness
- optional model-update norms when the initial model is present in the export

Command:

```bash
uv run python parameter_selection/plot_jointsg_lcurve.py \
  --exports-root exports/jointsg_smooth_damp_0.01 \
  --output-dir exports/jointsg_smooth_damp_0.01/lcurve_summary \
  --workflow-mode vs_seed
```

## Output

Expected outputs:

- `lcurve_metrics.csv`
- `lcurve.png`

If you want a second-pass denser sweep near the corner, a good next set is:

`8 12 15 18 20 25`

Useful companion checks:

- compare `joint_grav_rms` against `smooth`
- compare `joint_surf_rms` against `smooth`
- verify the chosen point still keeps the surface branch acceptable
