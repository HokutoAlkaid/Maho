# surf_inv Single-Module L-Curve

This workflow selects the smoothing parameter for [`surf_inv`](C:/Users/Chp/Documents/Maho/tc_cross_joint/surf_inv), not for `surf_inv_direct`, and treats `surf_inv` as a standalone single-module experiment.

Why:

- `surf_inv_direct` is mainly the initial-model generator
- `surf_inv` is the surface-wave branch used inside the joint workflow

## Recommended sweep

Keep `damp = 0.01` fixed and sweep:

`2 3 4 5 6 7 8 9 10 12 15 20`

This matches the current selection strategy:

- keep `maximum iteration = 1`
- use only the standalone `surf_inv` module for screening
- focus later interpretation on the candidate range `6 / 8 / 10`

## What is plotted

- x-axis: `||Wr_s||_2^2`
- y-axis: `||Dm_s||_2^2`
- point labels: `smooth`

Here `Wr_s` is the weighted surface-wave residual and `Dm_s` is the roughness of the model update `mod_iter1 - mod_iter0`.

## Run the sweep

Inside the Linux or bash environment that already runs this project:

```bash
cd /home/chp/Documents/Maho/tc_cross_joint

FIXED_DAMP=0.01 \
SWEEP_NAME=surfinv_singlemodule_smooth_damp_0.01 \
SMOOTH_VALUES="2 3 4 5 6 7 8 9 10 12 15 20" \
bash run_surfinv_smooth_sweep.sh
```

## Plot on Windows

```powershell
$env:UV_CACHE_DIR='C:\Users\Chp\Documents\Maho\.uv-cache'
$env:MPLCONFIGDIR='C:\Users\Chp\Documents\Maho\.mplconfig'
$env:MPLBACKEND='Agg'

uv run --python 3.11 --with numpy --with matplotlib python C:\Users\Chp\Documents\Maho\tc_cross_joint\plot_surfinv_lcurve.py --exports-root C:\Users\Chp\Documents\Maho\tc_cross_joint\exports\surfinv_singlemodule_smooth_damp_0.01 --output-dir C:\Users\Chp\Documents\Maho\tc_cross_joint\exports\surfinv_singlemodule_smooth_damp_0.01\lcurve_summary --highlight-smooth 8
```

## Output

Expected files:

- `sweep_summary.txt`
- `lcurve_metrics.csv`
- `lcurve.png`

If you are running this on Ubuntu and handing results back here, the simplest handoff is the whole:

- `exports/surfinv_singlemodule_smooth_damp_0.01`
