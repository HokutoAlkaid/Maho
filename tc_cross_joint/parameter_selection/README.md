# parameter_selection

这个文件夹集中放和参数选择实验有关的脚本与说明，避免 [`tc_cross_joint`](</C:/Users/Chp/Documents/Maho/tc_cross_joint>) 根目录过乱。

## 当前内容

- `run_jointsg_smooth_sweep.sh`
- `plot_jointsg_lcurve.py`
- `LCURVE_JOINTSG_SMOOTH.md`
- `run_surfinv_smooth_sweep.sh`
- `plot_surfinv_lcurve.py`
- `LCURVE_SURF_INV.md`
- `run_cross_param_sweep.sh`
- `summarize_cross_param_sweep.py`
- `CROSS_PARAM_SWEEP.md`

## 三类实验

1. `JointSG smooth` 选参
2. `surf_inv smooth` 选参
3. `cross` 三参数选参

## 说明

- 这些脚本虽然放在这个子目录里，但默认仍然以项目根目录 [`tc_cross_joint`](</C:/Users/Chp/Documents/Maho/tc_cross_joint>) 作为工作根目录。
- 导出目录仍然默认写到：
  - [`exports`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/exports>)
