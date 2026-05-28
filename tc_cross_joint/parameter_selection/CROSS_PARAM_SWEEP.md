# CROSS_PARAM_SWEEP

用于扫描 [`crossgradient_inversion.py`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/crossgradient_inversion.py>) 中的三参数：

- `alpha_s`
- `alpha_g`
- `beta_t`

## 当前建议口径

- 先固定：
  - `alpha_s = 1.0`
- 先粗扫：
  - `beta_t = 0 0.002 0.005 0.01 0.02 0.05`
- 同时扫一组较保守的：
  - `alpha_g = 0.2 0.4 0.6 0.8 1.0`

这样更适合当前流程，因为现在 `cross-gradient` 更像两个 `Vs` 模型之间的结构一致性约束，不是经典的 `Vs-rho` 双参数耦合。

## 运行方法

在 Linux / bash 环境里进入 [`tc_cross_joint`](</C:/Users/Chp/Documents/Maho/tc_cross_joint>) 后运行：

```bash
bash parameter_selection/run_cross_param_sweep.sh
```

如果想只扫 `beta_t`，保持 `alpha_s=1.0`、`alpha_g=0.4`，可用：

```bash
ALPHA_S_VALUES="1.0" \
ALPHA_G_VALUES="0.4" \
BETA_T_VALUES="0 0.002 0.005 0.01 0.02 0.05" \
bash parameter_selection/run_cross_param_sweep.sh
```

如果想在定住 `beta_t` 以后再扫 `alpha_g`，可用：

```bash
ALPHA_S_VALUES="1.0" \
ALPHA_G_VALUES="0.2 0.4 0.6 0.8 1.0" \
BETA_T_VALUES="0.01" \
bash parameter_selection/run_cross_param_sweep.sh
```

## 汇总方法

Windows PowerShell 下可直接运行：

```powershell
& 'C:\Users\Chp\.local\bin\python3.11.exe' `
  'C:\Users\Chp\Documents\Maho\tc_cross_joint\parameter_selection\summarize_cross_param_sweep.py' `
  --exports-root 'C:\Users\Chp\Documents\Maho\tc_cross_joint\exports\cross_param_sweep' `
  --output-dir 'C:\Users\Chp\Documents\Maho\tc_cross_joint\exports\cross_param_sweep\summary'
```

## 重点看什么

优先看这些量：

- `standalone_surf_rms`
- `joint_surf_rms`
- `joint_grav_rms`
- `rel_rms_change_s`
- `rel_rms_change_g`
- `model_diff_rms`

## 当前推荐的选点原则

- 面波 RMS 不要比单独面波结果明显变坏。
- `rel_rms_change_s` 先尽量控制在较温和范围。
- `rel_rms_change_g` 不要异常大。
- `model_diff_rms` 不必追求最小，但不要无约束地变大。
- 优先选“最小但已经起作用”的 `beta_t`。

## 2026-05-23 beta_t 第一轮结果

已完成一轮固定参数扫描：

- `alpha_s = 1.0`
- `alpha_g = 0.4`
- `beta_t = 0 0.002 0.005 0.01 0.02 0.05`

汇总结果位于：

- [`exports/cross_param_sweep/summary/cross_param_metrics.csv`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/exports/cross_param_sweep/summary/cross_param_metrics.csv>)
- [`exports/cross_param_sweep/summary`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/exports/cross_param_sweep/summary>)

关键指标：

| beta_t | joint_surf_rms | joint_grav_rms | rel_rms_change_s | rel_rms_change_g | model_diff_rms |
|---:|---:|---:|---:|---:|---:|
| 0 | 1.226940 | 11.4054 | 0.000000 | 0.000000 | 0.159259 |
| 0.002 | 1.226300 | 11.4054 | 0.002004 | 0.002072 | 0.159212 |
| 0.005 | 1.224890 | 11.4055 | 0.012437 | 0.012807 | 0.159106 |
| 0.01 | 1.226880 | 11.4056 | 0.048608 | 0.050733 | 0.159205 |
| 0.02 | 1.231560 | 11.4065 | 0.178771 | 0.189730 | 0.159514 |
| 0.05 | 1.315100 | 11.4243 | 0.851876 | 0.796666 | 0.166135 |

当前解释：

- `beta_t=0.005` 是第一轮指标上最稳的候选点：`joint_surf_rms` 和 `model_diff_rms` 都是本轮最低，且对两个更新量的相对改动约 1.2%，属于温和但已经起作用。
- `beta_t=0.01` 是偏强的备用候选：相对改动约 5%，但没有带来更好的面波或重力残差。
- `beta_t>=0.02` 暂不推荐：相对改动快速增大，`joint_surf_rms` 开始变坏。
- 相对 `beta_t=0`，`beta_t=0.005` 对主模型的整体 RMS 改动约 `0.000184 km/s`，峰值深度在 `2 km`；`beta_t=0.01` 对主模型的整体 RMS 改动约 `0.000717 km/s`，也是 `2 km` 最明显。

下一步建议：

1. 先把 `beta_t=0.005` 作为当前默认候选。
2. 保留 `beta_t=0.01` 用于图件对比，只有当它在关键深度切片上表现出更合理的结构连续性、且不引入异常时再考虑上调。
3. 后续若继续扫参，建议固定 `beta_t=0.005` 和 `0.01` 两个点，再扫描 `alpha_g = 0.2 0.4 0.6 0.8 1.0`，看 `alpha_g` 是否改变这个判断。
