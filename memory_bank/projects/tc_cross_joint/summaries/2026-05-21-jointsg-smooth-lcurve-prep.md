# tc_cross_joint Conversation Summary (2026-05-21)

## 1. 当前任务

- 本窗口主要把 `tc_cross_joint` 的反演实验 L 曲线工作梳理清楚，并确定先走 A 路线。
- 当前关注的是 `JointSG` 分支的平滑参数选取，不是重新排查主反演物理口径。
- 这次约定的路线是：
  - 固定 `damp=0.01`
  - 保持外层交叉梯度参数不变
  - 只扫描 [`gravity_inv/JointSG.in`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/gravity_inv/JointSG.in>) 里的 `smooth`

## 2. 已确认结论

- 当前 L 曲线先按 A 路线做，也就是“固定阻尼，只扫 `JointSG smooth`”。
- 平滑参数的初步确定已经达成：
  - 阻尼先固定为 `damp=0.01`
  - 第一轮只做 `JointSG` 的 `smooth` 粗扫
  - 第一轮粗扫值定为：`1 2 4 6 8 10 15 20 30 40 60 80`
- 当前基于经验判断的初步候选值可先记为：
  - `smooth = 8`
  - 但这个值目前仍是“优先候选”，不是已经由 L 曲线正式确认的最终值
- 当前这组值的用途是：
  - 先用稀疏取样把 L 曲线的大致弯折区间找出来
  - 后续如果角点落在某个局部区间，再在那个区间附近加密扫描
- 第一轮 `smooth` 粗扫范围已定为：
  - `1 2 4 6 8 10 15 20 30 40 60 80`
- 当前 [`gravity_inv/JointSG.in`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/gravity_inv/JointSG.in>) 中 `p=0`，因此这条 L 曲线的综合残差口径本质上是重力项主导。
- 这意味着当前曲线更准确的表述应是：
  - “当前 `p=0` 权重设置下的 `JointSG` 平滑参数选取曲线”
  - 不是“面波与重力完全平衡的联合 L 曲线”
- 这台 Windows 会话里已经能通过 `uv` 调起 Python，但 `python` / `py` 还没有直接暴露在当前 PowerShell 的 `PATH` 中。

## 3. 已做改动

- 在 [`tc_cross_joint`](</C:/Users/Chp/Documents/Maho/tc_cross_joint>) 下新增了 L 曲线准备脚本：
  - [`run_jointsg_smooth_sweep.sh`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/run_jointsg_smooth_sweep.sh>)
  - [`plot_lcurve_from_exports.py`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/plot_lcurve_from_exports.py>)
  - [`LCURVE_JOINTSG_SMOOTH.md`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/LCURVE_JOINTSG_SMOOTH.md>)
- 调整了导出脚本 [`collect_key_results.sh`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/collect_key_results.sh>)：
  - 支持通过 `EXPORT_TARGET_DIR` 指定导出目录
  - 额外导出初始模型与最终残差文件，便于后续严格计算 L 曲线指标
- 已生成一版基于现有 `run_*` 导出的预览产物：
  - [`lcurve_metrics_preview.csv`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/exports/lcurve_summary/lcurve_metrics_preview.csv>)
  - [`lcurve_preview.svg`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/exports/lcurve_summary/lcurve_preview.svg>)

## 4. 已做验证

- 已确认当前 Windows 环境存在可用 `uv`：
  - `uv 0.11.14`
- 通过临时设置 `UV_CACHE_DIR`，已确认 `uv run python --version` 可返回：
  - `Python 3.14.5`
- 通过一次性依赖方式已确认绘图脚本可以被 `uv` 正常解析：
  - `uv run --with numpy python ... --help`
- 已发现两个需要绕开的本地权限点：
  - `uv` 默认缓存目录 `C:\Users\Chp\AppData\Local\uv\cache` 有权限报错
  - `matplotlib` 默认配置目录 `C:\Users\Chp\.matplotlib` 有权限报错
- 当前建议的 Windows 汇总方式是先设置：
  - `UV_CACHE_DIR=C:\Users\Chp\Documents\Maho\.uv-cache`
  - `MPLCONFIGDIR=C:\Users\Chp\Documents\Maho\.mplconfig`
- 本窗口没有在当前 Windows PowerShell 中实际启动完整反演扫参，因为此会话没有可直接调用的 `bash` / Linux 运行环境。

## 5. 关键文件

- [`gravity_inv/JointSG.in`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/gravity_inv/JointSG.in>)
- [`run_jointsg_smooth_sweep.sh`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/run_jointsg_smooth_sweep.sh>)
- [`plot_lcurve_from_exports.py`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/plot_lcurve_from_exports.py>)
- [`LCURVE_JOINTSG_SMOOTH.md`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/LCURVE_JOINTSG_SMOOTH.md>)
- [`collect_key_results.sh`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/collect_key_results.sh>)
- [`exports/lcurve_summary/lcurve_metrics_preview.csv`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/exports/lcurve_summary/lcurve_metrics_preview.csv>)

## 6. 当前推荐口径

- 这次 L 曲线先只服务于 `JointSG smooth` 的选取，不把 `surf_inv` 与外层交叉梯度参数一并混扫。
- 当前已经约定的第一轮选参口径是：
  - 固定 `damp=0.01`
  - 只扫 `smooth`
  - 先粗扫，再视角点位置决定是否局部加密
- 当前可以带着去验证的经验候选点是：
  - `smooth = 8`
- 曲线主图建议仍按传统口径使用：
  - 横轴：加权残差范数 `||Wr||` 或 `||Wr||^2`
  - 纵轴：模型粗糙度 `||Dm||` 或 `||Dm||^2`
- 但在结果解释里必须明确说明：
  - 当前 `p=0`
  - 因而综合残差主要体现重力项
- 推荐同时查看辅助关系：
  - `smooth` vs `joint_grav_rms`
  - `smooth` vs `joint_surf_rms`
- 选点时不仅看 L 曲线角点，也要检查面波分支是否被拖坏。

## 7. 未决问题

- 尚未在真正的 Linux / bash 运行环境中执行整套 `smooth` 扫描。
- 尚未得到第一轮 `smooth` 粗扫的 `lcurve_metrics.csv` 与正式 `lcurve.png`。
- 后续如果希望得到“更联合意义上的”L 曲线，需要重新讨论 `p` 的设置，而不只是直接沿用当前 `p=0`。

## 8. 下一步建议

1. 在原来能正常跑 [`run.sh`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/run.sh>) 的 Linux / bash 环境中进入 [`tc_cross_joint`](</C:/Users/Chp/Documents/Maho/tc_cross_joint>)，执行：
   `FIXED_DAMP=0.01 SMOOTH_VALUES="1 2 4 6 8 10 15 20 30 40 60 80" bash run_jointsg_smooth_sweep.sh`
2. 扫描结束后，在 Windows PowerShell 中设置 `UV_CACHE_DIR` 和 `MPLCONFIGDIR`，再运行 [`plot_lcurve_from_exports.py`](</C:/Users/Chp/Documents/Maho/tc_cross_joint/plot_lcurve_from_exports.py>) 做汇总和画图。
3. 如果开新窗口，对方应优先阅读：
   - [`projects/tc_cross_joint/INDEX.md`](</C:/Users/Chp/Documents/Maho/memory_bank/projects/tc_cross_joint/INDEX.md>)
   - [`2026-05-21-jointsg-smooth-lcurve-prep.md`](</C:/Users/Chp/Documents/Maho/memory_bank/projects/tc_cross_joint/summaries/2026-05-21-jointsg-smooth-lcurve-prep.md>)
   - 如需回溯主反演物理口径，再读 [`2026-05-18-main-inversion-handoff.md`](</C:/Users/Chp/Documents/Maho/memory_bank/projects/tc_cross_joint/summaries/2026-05-18-main-inversion-handoff.md>)
