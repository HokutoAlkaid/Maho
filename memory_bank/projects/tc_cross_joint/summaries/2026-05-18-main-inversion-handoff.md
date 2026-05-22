# tc_cross_joint Conversation Summary (2026-05-18)

## 1. Purpose

This note summarizes the debugging, validation, and interpretation work we completed for the `tc_cross_joint` main inversion workflow. It is intended as a handoff document for future chats or future agents.

The current focus is the **main inversion workflow** under:

- [tc_cross_joint](</C:/Users/Chp/Documents/Maho/tc_cross_joint>)

Not the checkerboard test directory:

- [tc_Checkboard](</C:/Users/Chp/Documents/Maho/tc_Checkboard>)


## 2. Earlier housekeeping already completed

### 2.1 CRLF/LF issue

The original Ubuntu runtime crashes were traced mainly to Windows CRLF line endings, not to inversion logic.

Symptoms included:

- `$'\\r'`
- `do\\r`
- paths containing `\\r`
- Bash treating data files as commands

Files already converted to LF:

`tc_cross_joint`

- `run.sh`
- `collect_key_results.sh`
- `crossgradient_inversion.py`

`tc_Checkboard`

- `run.sh`
- `collect_key_results.sh`
- `crossgradient_inversion.py`

Repository rule added:

- [`.gitattributes`](</C:/Users/Chp/Documents/Maho/.gitattributes>)


### 2.2 Export slimming

`tc_cross_joint/collect_key_results.sh` was already simplified so exports only keep key logs and selected figures.

Current export policy:

- no `veltodensi.py`
- no `readme.md`
- no `gmt_slice_ref.log`
- no full copy of `logs/extra_logs`
- only selected logs
- figures only from:
  - `figures/surf_depth_slices`
  - `figures/gmt_slice_ref_depth_slices`
  - `colorbar.jpg`


## 3. Important scripts added during this investigation

The following helper scripts were created in [tc_cross_joint](</C:/Users/Chp/Documents/Maho/tc_cross_joint>):

- [`recheck_surface_rms.sh`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/recheck_surface_rms.sh>)
  - Recomputes surface-wave RMS for a given `mod_iter.dat` using the standalone surface-wave workflow.

- [`diagnose_jointsg_cases.sh`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/diagnose_jointsg_cases.sh>)
  - Tests selected `JointSG.in` parameter combinations for the gravity branch.

- [`diagnose_jointsg_p.sh`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/diagnose_jointsg_p.sh>)
  - Tests the effect of changing `RELATIVE_P` / `p`.

- [`diagnose_jointsg_model_offset.sh`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/diagnose_jointsg_model_offset.sh>)
  - Tests how `JointSG` output responds to a uniform offset added to the gravity-branch initial model.


## 4. Core findings before source-code inspection

### 4.1 The scary `19.8 s` was not the final main-model surface RMS

At one stage we saw:

- standalone surface-wave RMS around `0.96 s`
- `info_joint10.txt` traveltime RMS around `19.8 s`

This looked catastrophic at first, but it turned out that:

- `info_joint10.txt` refers to the **JointSG branch model**
- it does **not** refer to the final cross-gradient merged `results/mod_iter.dat`

This was verified using:

- [`recheck_surface_rms.sh`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/recheck_surface_rms.sh>)

Results:

`tc_Checkboard`

- final model RMS stayed near `0.1159`

`tc_cross_joint`

- final `results/mod_iter.dat` rechecked RMS stayed near `0.962`

So the final main model did **not** destroy the surface-wave fit.


### 4.2 Checkerboard did not show the same severe behavior

`tc_Checkboard` behaved much more gently:

- standalone surface RMS about `0.1159`
- joint branch RMS only worsened modestly to about `0.19-0.27`

This showed that the major red flag was not simply caused by the cross-gradient code port itself.


### 4.3 Changing cross-gradient parameters helped, but did not solve the main issue

We compared:

- old main-run parameters: `alpha_s=1.0, alpha_g=1.0, beta_t=0.1`
- checkerboard-like parameters: `alpha_s=1.0, alpha_g=0.4, beta_t=0.01`

Using the weaker set:

- greatly reduced `rel_rms_change_s`
- greatly reduced `rel_rms_change_g`

But it did **not** remove the `JointSG` branch surface RMS issue by itself.

Conclusion:

- cross-gradient parameters affected how strongly the two branches were merged
- they were not the main cause of the `~19.9 s` branch behavior


### 4.4 `JointSG.in` parameter sweeps

We tested the two lines in `JointSG.in` that looked suspicious:

- noise-level line
- std/weight line

Results:

- changing the noise-level line had essentially no effect in real-data mode
- changing the std/weight line had only tiny effects

Conclusion:

- those two `JointSG.in` lines were not the main reason for the branch behavior


### 4.5 `RELATIVE_P` is a real control parameter

We also tested different `p` values with:

- [`diagnose_jointsg_p.sh`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/diagnose_jointsg_p.sh>)

Conclusion:

- `p` strongly changes the output model
- `p` strongly changes gravity residuals
- `p=0` does **not** mean the surface-wave side is merely a harmless printed diagnostic

So `p` is a genuine data-balance control parameter.


## 5. Source-code and manual inspection of JDSurfG

We then inspected:

- local manual: [`UserManual.md`](</C:/Users/Chp/Documents/Maho/UserManual.md>)
- upstream repository: [nqdu/JDSurfG](https://github.com/nqdu/JDSurfG)
- local cloned copy used for inspection: [`_tmp_JDSurfG_repo`](</C:/Users/Chp/Documents/Maho/_tmp_JDSurfG_repo>)

### 5.1 Official JDSurfG design

The official JDSurfG design is:

- the inversion model variable in `JointSG` is **Vs**
- gravity is computed internally by converting:
  - current `Vs`
  - reference `Vs`
  - into density using empirical relations

Key source evidence:

- [`_tmp_JDSurfG_repo/src/JSurfGTomo/main.cpp`](</C:/Users/Chp/Documents/Maho/_tmp_JDSurfG_repo/src/JSurfGTomo/main.cpp:49>)
  - the main inversion model variable is named `vsf`

- [`_tmp_JDSurfG_repo/src/JSurfGTomo/JSurfGtomo.cpp`](</C:/Users/Chp/Documents/Maho/_tmp_JDSurfG_repo/src/JSurfGTomo/JSurfGtomo.cpp:57>)
  - input model is read into `vsinit`

- [`_tmp_JDSurfG_repo/src/JSurfGTomo/JSurfGtomo.cpp`](</C:/Users/Chp/Documents/Maho/_tmp_JDSurfG_repo/src/JSurfGTomo/JSurfGtomo.cpp:208>)
  - `compute_gravity(const fmat3 &vs, ...)`

- [`_tmp_JDSurfG_repo/src/JSurfGTomo/JSurfGtomo.cpp`](</C:/Users/Chp/Documents/Maho/_tmp_JDSurfG_repo/src/JSurfGTomo/JSurfGtomo.cpp:224>)
  - calls `empirical_relation(vs, vp, rho)`

- [`_tmp_JDSurfG_repo/utils/syn_gravity.cpp`](</C:/Users/Chp/Documents/Maho/_tmp_JDSurfG_repo/utils/syn_gravity.cpp:32>)
  - same logic: convert `vs` to `rho`, then compute gravity

### 5.2 What this means for our earlier local workflow

Our local workflow had been doing something non-standard:

- we converted `surf_inv_direct/results/mod_iter10.dat` from `Vs` to density using [veltodensi.py](</C:/Users/Chp/Documents/Maho/tc_cross_joint/veltodensi.py>)
- we then fed that density-valued file directly into `gravity_inv/initial/joint_mod_iter.dat`
- `JointSG` still treated that input as if it were `Vs`
- and then internally applied `Vs -> rho` again

So the old workflow was effectively:

- density-valued numbers were inserted into a slot that JDSurfG expects to be `Vs`

This explains the earlier confusing behavior.


## 6. The key fix applied

We modified:

- [`tc_cross_joint/run.sh`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/run.sh>)

Old behavior:

- initial `Vs` model was converted to density using `veltodensi.py`
- result written to `gravity_inv/initial/joint_mod_iter.dat`

New behavior:

- the initial `Vs` model from `surf_inv_direct/results/mod_iter10.dat` is copied directly into `gravity_inv/initial/joint_mod_iter.dat`
- no initial `Vs -> density` conversion is done

This aligns the workflow with official JDSurfG expectations.


## 7. Result of the fixed workflow

Latest fixed export:

- [`run_20260518_162033`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/exports/run_20260518_162033>)

### 7.1 What improved

After the fix:

- `joint_mod_iter.dat` returned to **Vs-like** range
- `JointSG` branch surface RMS returned to the same order of magnitude as the standalone surface-wave solution

Key values from the new export:

- [`info_surf10.txt`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/exports/run_20260518_162033/logs/info_surf10.txt>)
  - surface-wave RMS about `0.960048`

- [`info_joint10.txt`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/exports/run_20260518_162033/logs/info_joint10.txt>)
  - branch surface RMS about `1.16637`
  - gravity RMS about `11.4532`

Model ranges:

- [`models/mod_iter.dat`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/exports/run_20260518_162033/models/mod_iter.dat>)
  - `min=2.865054`
  - `max=4.861018`
  - `mean=3.642111`

- [`models/joint_mod_iter.dat`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/exports/run_20260518_162033/models/joint_mod_iter.dat>)
  - `min=1.5`
  - `max=4.630256`
  - `mean=3.667350`

Difference between the two exported Vs models:

- mean difference about `0.025240`
- RMS difference about `0.139144`

This is a major improvement over the old density-like `joint_mod_iter.dat` behavior.


## 8. How to interpret the two current output models

With the fixed workflow, the experiment now produces **two Vs models**:

- [`results/mod_iter.dat`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/results/mod_iter.dat>)
- [`results/joint_mod_iter.dat`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/results/joint_mod_iter.dat>)

### 8.1 Recommended primary model

Use:

- [`results/mod_iter.dat`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/results/mod_iter.dat>)

as the **main model for interpretation and reporting**.

Reason:

- it is the surface-wave-side final model
- surface waves directly constrain `Vs`
- it gives the best direct surface-wave fit

### 8.2 Recommended secondary model

Use:

- [`results/joint_mod_iter.dat`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/results/joint_mod_iter.dat>)

as the **gravity-side auxiliary Vs model**.

Reason:

- it represents where the gravity-constrained branch wants to place the velocity structure
- it is useful for comparison, not as the primary interpreted model


## 9. What the current gravity figures mean

Very important:

- with the fixed workflow, `joint_mod_iter.dat` is again a **Vs model**
- therefore any figure drawn directly from `joint_mod_iter.dat` is a **velocity figure**
- it is **not** a true density figure

So the current `gravity` figure branch should be understood as:

- velocity slices from the gravity-side branch

not:

- direct density slices

If true density figures are needed later, the proper workflow is:

1. take a Vs model
2. convert it to density using Brocher or another chosen relation
3. plot that density file


## 10. What cross-gradient means now

After fixing the workflow, both branches are now Vs models.

So the cross-gradient term no longer means:

- "Vs-density structural coupling"

Instead it means:

- "structural consistency between two Vs models derived from different data sensitivities"

More specifically:

- `mod_iter.dat` is mainly surface-wave driven
- `joint_mod_iter.dat` is mainly gravity-side driven, but gravity enters through internal `Vs -> rho`

So cross-gradient is still useful, but now it acts more like:

- a structural consistency regularizer between two velocity solutions

and less like:

- a true two-parameter `Vs-rho` coupling method


## 11. Current best understanding

At the end of this investigation, the best current interpretation is:

1. The old local workflow was physically inconsistent with official JDSurfG usage.
2. The main error was feeding density-valued initial models into a module that expects `Vs`.
3. Removing the initial `Vs -> density` conversion corrected that mismatch.
4. The new fixed workflow now behaves much more consistently with JDSurfG design.
5. The primary model for reporting should be `results/mod_iter.dat`.
6. The gravity-side output `results/joint_mod_iter.dat` should be treated as an auxiliary Vs model.


## 12. Most important files to remember

Workflow:

- [`run.sh`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/run.sh>)
- [`crossgradient_inversion.py`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/crossgradient_inversion.py>)

Main model outputs:

- [`results/mod_iter.dat`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/results/mod_iter.dat>)
- [`results/joint_mod_iter.dat`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/results/joint_mod_iter.dat>)

Recent key export:

- [`exports/run_20260518_162033`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/exports/run_20260518_162033>)

Helper diagnostics:

- [`recheck_surface_rms.sh`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/recheck_surface_rms.sh>)
- [`diagnose_jointsg_cases.sh`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/diagnose_jointsg_cases.sh>)
- [`diagnose_jointsg_p.sh`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/diagnose_jointsg_p.sh>)
- [`diagnose_jointsg_model_offset.sh`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/diagnose_jointsg_model_offset.sh>)

Manual and source references:

- [`UserManual.md`](</C:/Users/Chp/Documents/Maho/UserManual.md>)
- [`_tmp_JDSurfG_repo`](</C:/Users/Chp/Documents/Maho/_tmp_JDSurfG_repo>)


## 13. Suggested next steps

Recommended next options:

1. Interpret the new main inversion results using `results/mod_iter.dat` as the primary model.
2. Compare `joint_mod_iter.dat` against `mod_iter.dat` only as a gravity-side auxiliary check.
3. If density plots are needed, add an explicit post-processing `Vs -> rho` plotting branch.
4. Update any scripts, labels, or documentation that still misleadingly treat `joint_mod_iter.dat` as a direct density model.
