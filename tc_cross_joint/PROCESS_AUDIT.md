# tc_cross_joint Process Audit

This note tracks the main inversion workflow by variable and model transfer.
It focuses on whether each step passes the intended model, unit, grid, and
increment, not on whether the final geologic result is good.

## Audit Scope

- Project: `tc_cross_joint`
- Workflow: main inversion, not `tc_Checkboard`
- Current focus: model and variable provenance from the initial model through
  the cross-gradient merge step

## 1. Initial Surface Model

### Source

- Script: `surf_inv_direct/initial/initalmod1.py`
- Input 1D model: `surf_inv_direct/initial/ynavemod.txt`
- Output grid model:
  - `surf_inv_direct/initial/MOD`
  - `surf_inv_direct/initial/MOD.true`

### Calculation

`ynavemod.txt` is interpreted as layer thickness plus Vs. The script builds
depth boundaries by cumulative thickness, then assigns one Vs value to every
horizontal cell at each target depth:

- lateral grid: `21 x 21`
- depth grid: `0, 2, 4, 6, 8, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 km`
- output model values: Vs, in `km/s`

### Checks Performed

- `surf_inv_direct/MOD` depth header matches `DSurfTomo.in`.
- `surf_inv_direct/results/mod_iter0.dat` is exactly the table expansion of
  the generated `MOD`.
- `surf_inv_direct/results/mod_iter10.dat` is the result of 10 direct
  surface-wave iterations starting from that 1D model.

### Status

No transfer error found in this initial surface model generation step.

## 2. Initial JointSG Model

### Source

- Script: `run.sh`
- Source model: `surf_inv_direct/results/mod_iter10.dat`
- Destination:
  - `gravity_inv/initial/joint_mod_iter.dat`

### Calculation

The workflow copies the direct surface-wave Vs model directly into the JointSG
initial model slot:

```bash
cp surf_inv_direct/results/mod_iter10.dat \
   gravity_inv/initial/joint_mod_iter.dat
```

This is consistent with the JDSurfG/JointSG design, where the inversion model
variable is Vs and gravity is computed internally via empirical Vs-to-density
conversion.

### Status

This fixed transfer is conceptually correct. It avoids the earlier wrong path
where a density-valued model was passed into a Vs model slot.

## 3. Gravity Initial MOD Files

### Source

- Script: `gravity_inv/initial/bash.sh`
- Input table model: `gravity_inv/initial/joint_mod_iter.dat`
- Outputs copied to `gravity_inv/`:
  - `MOD`
  - `MOD.true`
  - `MOD.aver`

### Calculation

- `initialmod.py` converts `joint_mod_iter.dat` into JDSurfG `MOD` format.
- `initialaver.py` converts the same model into a layer-average `MOD.aver`.
- These are Vs models, not density models.

### Checks Performed

- `MOD.aver` equals the layer mean of `joint_mod_iter.dat` up to the expected
  four-decimal output rounding.
- At the end of a full run, `gravity_inv/MOD` and `gravity_inv/MOD.true` equal
  the last JointSG input model, i.e. `gravity_inv/results/joint_mod_iter0.dat`.
- At the same end state, `gravity_inv/initial/joint_mod_iter.dat` equals the
  post-cross-gradient model that would be used as the next JointSG input.
- Therefore `gravity_inv/MOD` can appear stale relative to
  `gravity_inv/initial/joint_mod_iter.dat`; this is an end-state timing issue,
  not a wrong-copy issue.

### Status

The generation logic is correct. The stale end-state `MOD` is expected, but it
can confuse manual inspection.

## 4. Gravity Matrix Precalculation

### Source

- Script: `run.sh`
- Command:

```bash
mkmat DSurfTomo.in obsgrav.dat MOD
```

### Current Understanding

The upstream `mkmat` implementation reads `MOD` for model geometry. The matrix
assembly uses cell geometry and observation coordinates; it does not use the Vs
values directly in the matrix entries.

### Status

The `if [ ! -f MOD ]` guard in `run.sh` looks risky because `MOD` may be a
previous-run residual. However, because the grid geometry is unchanged and
`mkmat` does not use Vs values directly, this is not currently treated as a
confirmed workflow error. It remains a reproducibility hygiene issue.

## 5. Surface Branch Per-Iteration Input

### Source

- Script: `surf_inv/run.sh`
- Input model: `surf_inv/MOD`
- Optional true model argument: `surf_inv/MOD.true`
- Parameter file: `surf_inv/DSurfTomo.in`

### Calculation

Each outer iteration runs one direct surface-wave inversion step:

```bash
DSurfTomo DSurfTomo.in tc_joint_surfdata.dat MOD MOD.true
```

At the start of the outer workflow, `surf_inv/MOD` is created from
`surf_inv_direct/results/mod_iter10.dat`. After each cross-gradient merge,
`results/mod_iter.dat` is converted to `results/MOD` and copied back to
`surf_inv/MOD`.

### Checks Performed

- At the current end state, `surf_inv/MOD` equals `results/mod_iter.dat`
  exactly after conversion through `out2init.py`.
- `surf_inv/MOD.true` is an old file and does not match the current `MOD`.
- The upstream DSurfTomo source only reads `MOD.true` when `synthetic flag` is
  enabled.
- Current `surf_inv/DSurfTomo.in` uses synthetic flag `0`, so `MOD.true` is not
  used in the real-data workflow.

### Status

The active `MOD` handoff is correct. `MOD.true` is stale but currently harmless
for real-data inversion; it is a reproducibility hygiene issue because it can
mislead manual inspection.

## 6. Per-Iteration Model Increments

### Surface Branch

- Script: `surf_inv/results/bash.sh`
- Old model: `mod_iter0.dat`
- New model: `mod_iter1.dat`
- Output increment: `delta_ms0.dat = new - old`

### Gravity Branch

- Script: `gravity_inv/results/bash.sh`
- Old model: `joint_mod_iter0.dat`
- New model: `joint_mod_iter1.dat`
- Output increment: `delta_mg0.dat = new - old`

### Checks Performed

- `data/delta_ms0.dat` equals `surf_inv/results/mod_iter1.dat -
  surf_inv/results/mod_iter0.dat`.
- `data/delta_mg0.dat` equals `gravity_inv/results/joint_mod_iter1.dat -
  gravity_inv/results/joint_mod_iter0.dat`.
- Coordinates are identical across the old model, new model, and increment
  files.

### Status

No sign or coordinate transfer error found in the increment handoff.

## 7. Cross-Gradient Merge

### Source

- Script: `crossgradient_inversion.py`
- Inputs:
  - `data/delta_ms0.dat`
  - `data/delta_mg0.dat`
  - `data/mod_iter0.dat`
  - `data/joint_mod_iter0.dat`
- Outputs:
  - `results/mod_iter.dat`
  - `results/joint_mod_iter.dat`

### Original Calculation

The script solves for adjusted increments and applies:

- `mod_iter.dat = mod_iter0 + adjusted_delta_ms`
- `joint_mod_iter.dat = joint_mod_iter0 + adjusted_delta_mg`

It uses real horizontal spacing in km and the actual depth grid in km for the
cross-gradient residual.

### Variable Meanings

| Variable | Source | Meaning |
|---|---|---|
| `data/delta_ms0.dat` | `surf_inv/results/bash.sh` | surface branch one-step Vs increment, `new - old` |
| `data/delta_mg0.dat` | `gravity_inv/results/bash.sh` | gravity-side JointSG one-step Vs increment, `new - old` |
| `data/mod_iter0.dat` | `surf_inv/results/mod_iter0.dat` | surface branch old Vs model for this outer iteration |
| `data/joint_mod_iter0.dat` | `gravity_inv/results/joint_mod_iter0.dat` | gravity-side old Vs model for this outer iteration |
| `ms_0` | reshape of `mod_iter0` values | surface old Vs model on `(lat, lon, depth)` grid |
| `mg_0` | reshape of `joint_mod_iter0` values | gravity-side old Vs model on `(lat, lon, depth)` grid |
| `tx0, ty0, tz0` | `grad(ms_0) x grad(mg_0)` | cross-gradient residual components |
| `Delta_m_s0` | 4th column of `delta_ms0.dat` | original surface update before cross-gradient merge |
| `Delta_m_g0` | 4th column of `delta_mg0.dat` | original gravity-side update before cross-gradient merge |
| `Delta_m_s, Delta_m_g` | LSMR solution | adjusted updates after cross-gradient merge |

### Coordinate and Shape Checks

- Input table order is `lon, lat, depth, value`.
- File order is depth-major, then lon, then lat.
- `reshape((nlat, nlon, nz), order="F")` maps the table to `(lat, lon, depth)`
  correctly.
- `lat_km` is decreasing because the latitude axis runs north to south. This is
  acceptable as long as all gradients and derivative stencils use the same axis
  convention.
- `lon_km` uses `111.32 * cos(mean_lat)` with `mean_lat = 24.5`.
- `depth_km` uses the actual nonuniform depth grid.

### Current Concern

The current cross-gradient residual uses `np.gradient` with real nonuniform
grid coordinates. The Jacobian-like diagonal blocks are still an approximate
surrogate and are not a strict finite-difference linearization of that same
operator.

This does not invalidate the use of real grid spacing. It means the residual
definition and the linearized update operator should be reviewed as a pair.

Finite-difference checking confirmed that the current diagonal blocks are not
the strict derivative of `tau = grad(ms) x grad(mg)` with respect to the same
cell value. This was already true in spirit for the older diagonal approximation;
the real nonuniform grid makes the mismatch more visible, especially near the
`10-15 km` depth-spacing transition.

The current diagonal block formulas are also not identical to the older
local-surrogate formulas preserved in `crossgradient_py_used/`. Several
cross-product subtraction terms are absent in the current implementation. A
diagnostic comparison against an old-style local full cross-product surrogate
showed large differences in the coefficient blocks, with relative RMS
differences around `0.68-1.55` depending on component.

An additional diagnostic compared three update paths on the current `data/`
state:

| Method | beta_t | true tau RMS after update | update deviation from raw surface/gravity increment |
|---|---:|---:|---:|
| raw branch updates | 0 | `1.319311e-04` | `0 / 0` |
| current diagonal approximation | 0.005 | `1.319236e-04` | `1.28% / 1.59%` |
| strict sparse linearization | 0.005 | `1.316642e-04` | `6.19% / 4.82%` |
| current diagonal approximation | 0.01 | `1.319030e-04` | `5.09% / 6.31%` |
| strict sparse linearization | 0.01 | `1.308924e-04` | `22.53% / 17.80%` |

This means the current diagonal approximation does influence the updates, but
it only weakly reduces the true cross-gradient residual measured by the same
`np.gradient` definition. A stricter linearization has a clearer effect on
`tau`, but it also perturbs the branch updates much more strongly.

The sparse derivative matrices used in this diagnostic were checked against
`np.gradient(..., edge_order=2)` on both the nonuniform depth axis and the
decreasing latitude axis; the numerical difference was zero to machine
precision.

### Boundary Note

`np.gradient(..., edge_order=2)` computes nonzero boundary values for `tau`.
The current derivative blocks are zero on model boundaries because
`calculate_gradient_derivatives()` only loops over interior indices. These zero
coefficient rows do not affect the LSMR solution directly, but they do affect
reported residual norms and block-scale estimates if boundary `tau` is included
in the scale calculation.

The native DSurfTomo/JointSG update region is also not the same as the current
cross-gradient derivative region:

- Native inversion updates lateral interior cells and all depths except the
  bottom layer.
- Current cross-gradient derivative rows cover only lateral interior cells and
  interior depth levels, excluding both top and bottom depth layers.
- The original branch increments are zero on lateral boundaries and the bottom
  layer; cross output preserves that.
- The top layer can receive native branch updates, but the current
  cross-gradient derivative does not constrain that top-layer update.

### Status

File handoff was correct. The original Vs-Vs cross-gradient implementation was
the main open audit item. The real grid spacing was a reasonable improvement,
but the residual, linearized operator, boundary treatment, and normalization
needed to be made internally consistent before treating `beta_t` scans as final.

## 7b. Density-Space Gravity Cross Variant

### Implemented Change

As of 2026-05-25, `crossgradient_inversion.py` has been changed so the
gravity-side branch participates in the cross-gradient system as an equivalent
density model:

- input JointSG model remains `Vs_g0 = data/joint_mod_iter0.dat`
- input JointSG increment remains `delta_Vs_g0 = data/delta_mg0.dat`
- cross script computes `rho_g0 = Brocher(Vs_g0)`
- cross script computes `rho_g1 = Brocher(Vs_g0 + delta_Vs_g0)`
- gravity-side cross input increment becomes `delta_rho_g0 = rho_g1 - rho_g0`
- cross-gradient residual becomes `grad(Vs_s0) x grad(rho_g0)`
- solved gravity-side increment is `adjusted_delta_rho_g`
- script forms `rho_g_new = rho_g0 + adjusted_delta_rho_g`
- script numerically inverts Brocher to obtain `Vs_g_new`
- output `results/joint_mod_iter.dat` remains a Vs model for the next JointSG
  iteration
- output `results/joint_density_iter.dat` is added as a diagnostic density model

### Backup

The pre-change real-grid Vs-Vs version was backed up as:

- `crossgradient_py_used/crossgradient_inversion_3_realgrid_vs_vs_before_density_cross_20260525.py`

### Status

A smoke test in a temporary copy of the current `data/` directory completed
successfully. It produced:

- `results/mod_iter.dat`
- `results/joint_mod_iter.dat`
- `results/joint_density_iter.dat`

The generated output tables had the expected `7056 x 4` shape and preserved the
input coordinates.

## 8. Final Figure Inputs

### Source

- `results/surf/bash.sh` reads `results/mod_iter.dat`.
- `results/gravity/bash.sh` reads `results/joint_mod_iter.dat`.
- `results/gmt_slice_ref/bash1.sh` and `bash2.sh` read `results/mod_iter.dat`.

### Current Interpretation

- The surface figure branch uses the primary surface-side final Vs model.
- The gravity figure branch uses the gravity-side auxiliary Vs model, not a
  density model.
- The cross-section branch currently uses the primary `results/mod_iter.dat`
  model.

### Status

The final figure scripts read the expected final result files rather than the
stale intermediate `gravity_inv/MOD`. Labels and interpretation should continue
to avoid calling `joint_mod_iter.dat` a direct density model.
