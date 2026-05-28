# tc_Checkboard Follow-up Summary (2026-05-25)

## 1. Current Focus

- This follow-up records the later stage of the `tc_Checkboard` checkerboard investigation after the initial 2026-05-19 handoff.
- The main topics added in this stage are:
  - validating the `run.sh` fix that removes the initial `Vs -> rho` conversion;
  - comparing the current workflow against the copied reference example [`JointSG_Checkboard`](</C:/Users/Chp/Documents/Maho/JointSG_Checkboard>);
  - checking whether deep poor recovery is mainly a plotting/colorbar issue or a true inversion-resolution issue;
  - identifying an encoding problem in GMT plotting templates that affects future script editing.

## 2. New Confirmed Conclusions

- The `tc_Checkboard/run.sh` change that removes the initial `veltodensi.py` step and directly copies the initial `Vs` model into `gravity_inv/initial/joint_mod_iter.dat` should be kept.
- The representative export after this fix is [`run_20260518_171644`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/exports/run_20260518_171644>).
- Compared with the earlier normalized baseline [`run_20260516_163046`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/exports/run_20260516_163046>), this fixed workflow changed the final models and figures in a real way rather than only changing logs.
- The latest balanced interpretation after the `run.sh` fix is:
  - `rel_rms_change_s` becomes slightly larger;
  - `rel_rms_change_g` becomes slightly smaller;
  - the coupled update is therefore a bit more surface-wave-dominated and a bit less gravity-dragged.
- Deep poor recovery is **not primarily a colorbar problem**. After checking the plotted scale range, the deep layers already use a range comparable to the anomaly amplitude and to similar papers. The main issue is still the true recovery quality.
- The copied folder [`JointSG_Checkboard`](</C:/Users/Chp/Documents/Maho/JointSG_Checkboard>) is useful as a reference example, but it is **not methodologically equivalent** to the current `tc_Checkboard` workflow.

## 3. What Changed Numerically After the `run.sh` Fix

- Earlier baseline:
  - [`run_20260516_163046`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/exports/run_20260516_163046>)
  - last-iteration diagnostics approximately:
    - `rel_rms_change_s ≈ 0.1187`
    - `rel_rms_change_g ≈ 0.0879`

- New fixed-flow baseline:
  - [`run_20260518_171644`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/exports/run_20260518_171644>)
  - last-iteration diagnostics approximately:
    - `rel_rms_change_s ≈ 0.1321`
    - `rel_rms_change_g ≈ 0.0694`

- Interpretation:
  - the updated workflow keeps the cross-gradient coupling active;
  - gravity-side deviation is slightly weaker;
  - surface-wave-side deviation is slightly stronger;
  - this is considered healthier than the old inconsistent initialization route.

## 4. Deep Recovery Interpretation After Rechecking the Figures

- The deep slices still show the same essential behavior:
  - `20 km` and deeper become increasingly blurred;
  - `30 km` still contains some recognizable anomalies but tends to appear as elongated or banded structures;
  - `40 km` and deeper are weak;
  - `50 km` and below are dominated by long-wavelength trends rather than sharp checkerboard blocks.
- After rechecking the figure display, the conclusion is:
  - deep poor recovery should be interpreted as a **resolution / recovery limitation**;
  - it should **not** be mainly attributed to the plotting color scale.

## 5. How to Understand `JointSG_Checkboard`

- [`JointSG_Checkboard`](</C:/Users/Chp/Documents/Maho/JointSG_Checkboard>) is a useful comparison case from the same Tengchong region.
- However, it follows a different workflow:
  - it performs a surface-wave-only inversion;
  - then performs a **native JointSG joint inversion**;
  - it does **not** use the current outer Python cross-gradient coupling framework from [`tc_Checkboard/crossgradient_inversion.py`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/crossgradient_inversion.py>).
- Therefore it is best treated as:
  - a methodological reference;
  - a baseline for how a native JointSG checkerboard example behaves;
  - not as a strict one-to-one standard that `tc_Checkboard` must visually match.

## 6. Plotting Script Maintenance Note

- While investigating whether the colorbar could be adjusted, it was discovered that the GMT plotting template file:
  - [`results/gmt_vel_joint/demo/tomo.sh`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/results/gmt_vel_joint/demo/tomo.sh>)
  is encoded as non-UTF-8 in the Ubuntu environment.
- The user verified:
  - `file -bi tomo.sh` -> `charset=iso-8859-1`
  - `file -bi scale.f90` -> `charset=us-ascii`
  - `iconv -f utf-8 -t utf-8 tomo.sh ...` fails
- Meaning:
  - `scale.f90` is safe to patch;
  - `tomo.sh` is not reliably editable with strict UTF-8 patch tools until it is converted.
- Recommendation for future maintenance:
  - convert `results/gmt_vel_joint/demo/tomo.sh` to UTF-8 + LF first;
  - only then make automated edits to the plotting logic.

## 7. Current Recommended Interpretation

- The current `tc_Checkboard` workflow should continue using:
  - real `dx, dy, dz`;
  - cross-gradient block normalization;
  - direct copying of the initial `Vs` model into `gravity_inv/initial/joint_mod_iter.dat`;
  - `ALPHA_S = 1.0`, `ALPHA_G = 0.4`, `BETA_T = 0.01` as a practical reference set.
- The current recommended scientific wording is:
  - the cross-gradient coupling is numerically effective and reasonably balanced;
  - the main limitation of deep checkerboard recovery is no longer whether the coupling is active;
  - the main limitation is the inherent deep resolution / experiment-design ceiling, so deep layers mainly recover long-wavelength anomalies rather than sharp checkerboard boundaries.

## 8. Suggested Next-Step Usage

1. If a new chat continues `tc_Checkboard`, read this file first, then the earlier [`2026-05-19-checkerboard-handoff.md`](</C:/Users/Chp/Documents/Maho/memory_bank/projects/tc_Checkboard/summaries/2026-05-19-checkerboard-handoff.md>) if more detail is needed.
2. Treat [`run_20260518_171644`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/exports/run_20260518_171644>) as the current best post-fix baseline.
3. Do not spend more effort blaming colorbar range unless the plotting templates are intentionally redesigned for a special comparison figure; the present issue is fundamentally recovery quality.
4. Use [`JointSG_Checkboard`](</C:/Users/Chp/Documents/Maho/JointSG_Checkboard>) as a methodological comparison case, not as a direct visual acceptance criterion.
