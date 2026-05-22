# tc_Checkboard Conversation Summary (2026-05-19)

## 1. 当前任务

- 本阶段主要围绕 [`tc_Checkboard`](</C:/Users/Chp/Documents/Maho/tc_Checkboard>) 的 checkerboard 检测板实验展开。
- 重点问题包括：
  - 深部 `30-60 km` 恢复差、边界模糊；
  - 交叉梯度脚本是否真正起作用；
  - `run.sh` 初始模型流程是否与 `JointSG/JDSurfG` 官方参数化一致；
  - 如何判断当前联合反演的耦合强度是否合理。

## 2. 已确认结论

- 早期脚本在真实 `dx,dy,dz` 下，交叉梯度项曾经数值上几乎不起作用；其后通过对交叉梯度方程块做归一化，约束才真正“发声”。
- 当前较平衡的一组 checkerboard 联合参数是：
  - `ALPHA_S = 1.0`
  - `ALPHA_G = 0.4`
  - `BETA_T = 0.01`
- 在这组参数下，交叉梯度已对两侧更新产生温和、真实的修正，但深部恢复仍然有限。
- 深部 `30-50 km` 的主要问题已经不再是“交叉梯度完全不起作用”，而是深部敏感性、参数化尺度、平滑正则以及交叉梯度本身偏向结构连续性等综合限制。
- `tc_Checkboard/run.sh` 的旧流程中，初始 `Vs -> rho` 经验公式转换与 `JointSG/JDSurfG` 官方思路不一致；已改为直接复制初始 `Vs` 模型进入 `gravity_inv/initial/joint_mod_iter.dat`。

## 3. 已做改动

- 更新了 [`crossgradient_inversion.py`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/crossgradient_inversion.py>)：
  - 引入真实网格尺度 `dx,dy,dz`；
  - 用真实深度节点处理非均匀 `dz`；
  - 增加 `CONFIG` 参数打印；
  - 增加 `rel_rms_change_s/g`、平均和最大更新差等诊断输出；
  - 对交叉梯度 `x/y/z` 三个方向的方程块做 RMS 归一化。
- 更新了 [`run.sh`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/run.sh>)：
  - 固定 `ROOT_DIR`；
  - 用 `tee` 自动保存终端输出；
  - 末尾自动调用收集脚本；
  - 去掉初始 `veltodensi.py` 转换，改为直接复制 `surf_inv_direct/results/mod_iter10.dat`。
- 更新了 [`collect_key_results.sh`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/collect_key_results.sh>)：
  - 自动收集关键脚本、参数、日志、模型和深度切片图；
  - 输出目录和 manifest 会在终端中醒目打印。
- 额外保留了 [`crossgradient_inversion_original_debug.py`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/crossgradient_inversion_original_debug.py>) 用于与原始 `dx=dy=dz=1` 版本对照。

## 4. 已做验证

### 4.1 交叉梯度是否起作用

- 真实尺度但未归一化时，最后一轮大致为：
  - `rel_rms_change_s ~ 10^-6`
  - `rel_rms_change_g ~ 10^-7`
- 说明当时交叉梯度项在数值上几乎被单位阵项淹没，基本不起作用。
- 原始 `dx=dy=dz=1` 调试版本则可达到约：
  - `rel_rms_change_s ~ 10^-2`
  - `rel_rms_change_g ~ 10^-3`
- 这证明脚本并非完全无效，而是量级平衡有问题。

### 4.2 归一化后的参数扫描

- 经过归一化后，测试过的关键参数包括：
  - `1 / 1 / 0.1`
  - `1 / 0.1 / 0.01`
  - `1 / 0.05 / 0.01`
  - `1 / 0.2 / 0.01`
  - `1 / 0.3 / 0.01`
  - `1 / 0.4 / 0.01`
- 重要认识：
  - 继续降低 `alpha_g` 并不会抑制重力侧，反而会让重力分支偏离得更厉害；
  - 提高 `alpha_g` 能更有效地约束重力侧更新。

### 4.3 当前较平衡的基线

- 导出目录 [`run_20260516_163046`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/exports/run_20260516_163046>) 是归一化后较平衡的一组代表。
- 其最后一轮诊断量约为：
  - `rel_rms_change_s ≈ 0.1187`
  - `rel_rms_change_g ≈ 0.0879`
- 这说明交叉梯度对两侧更新都已产生真实作用，但尚未强到完全主导更新。

### 4.4 去掉初始经验公式转换后的新流程

- 新流程代表导出为 [`run_20260518_171644`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/exports/run_20260518_171644>)。
- 相比旧基线 [`run_20260516_163046`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/exports/run_20260516_163046>)：
  - 模型文件和图件哈希均发生变化，说明流程修正确实改变了结果；
  - 最后一轮约为：
    - `rel_rms_change_s ≈ 0.1321`
    - `rel_rms_change_g ≈ 0.0694`
- 解释：
  - 面波侧改动略增强；
  - 重力侧改动略减弱；
  - 说明去掉初始 `Vs -> rho` 转换后，联合耦合更偏向以面波为主的稳定平衡。

## 5. 关键文件

- 工作目录：
  - [`tc_Checkboard`](</C:/Users/Chp/Documents/Maho/tc_Checkboard>)
- 工作流脚本：
  - [`run.sh`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/run.sh>)
  - [`collect_key_results.sh`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/collect_key_results.sh>)
- 交叉梯度脚本：
  - [`crossgradient_inversion.py`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/crossgradient_inversion.py>)
  - [`crossgradient_inversion_original_debug.py`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/crossgradient_inversion_original_debug.py>)
- 代表性导出：
  - [`run_20260516_163046`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/exports/run_20260516_163046>)
  - [`run_20260518_171644`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/exports/run_20260518_171644>)
- 代表性图件：
  - [`Fig6_checker_2.jpg`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/exports/run_20260518_171644/figures/Fig1/Fig6_checker_2.jpg>)
  - [`030km.jpg`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/exports/run_20260518_171644/figures/depth_slices/030km.jpg>)
  - [`040km.jpg`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/exports/run_20260518_171644/figures/depth_slices/040km.jpg>)
  - [`050km.jpg`](</C:/Users/Chp/Documents/Maho/tc_Checkboard/exports/run_20260518_171644/figures/depth_slices/050km.jpg>)

## 6. 当前推荐口径

- 方法层面：
  - `tc_Checkboard` 应继续沿用“真实网格尺度 + 交叉梯度方程块归一化 + 直接复制初始 Vs 模型”的流程；
  - 不建议再恢复初始 `veltodensi.py` 转换。
- 参数层面：
  - 当前可把 `ALPHA_S = 1.0`, `ALPHA_G = 0.4`, `BETA_T = 0.01` 作为默认参考组。
- 结果解释层面：
  - 浅部 `0-10 km` 恢复较好；
  - `20 km` 开始模糊；
  - `30 km` 仍能识别部分异常，但常呈带状；
  - `40 km` 以下明显减弱；
  - `50 km` 及更深部主要表现为长波趋势恢复，而不是规则小尺度棋盘格恢复。
- 因此，当前 checkerboard 的推荐解释是：
  - 联合反演在深部对长波异常有一定补充作用；
  - 但深部小尺度棋盘格边界恢复能力有限。

## 7. 未决问题

- 交叉梯度当前仍是近似线性化与对角近似，不是严格的邻点全耦合雅可比。
- 深部恢复差的主要限制仍包括：
  - 深部敏感性不足；
  - 当前 checkerboard 尺度对深部偏苛刻；
  - 平滑/阻尼和交叉梯度结构连续性共同抹平边界。
- 如果后续继续改进，优先方向不再是简单重复扫 `alpha/beta`，而是：
  - 改实验设计（如深部更大尺度 anomaly test）；
  - 或增加定量恢复指标，而不仅依赖视觉判断。

## 8. 下一步建议

1. 新开窗口继续 `tc_Checkboard` 时，先读 [`INDEX.md`](</C:/Users/Chp/Documents/Maho/memory_bank/projects/tc_Checkboard/INDEX.md>) 和本 handoff。
2. 若继续做 checkerboard，对外默认使用“去掉初始 `Vs -> rho` 转换”的新流程。
3. 若要写工作日志或论文讨论，可用当前统一口径：
   - 交叉梯度耦合已有效且数值平衡合理；
   - 深部恢复受分辨率与实验设计限制，主要恢复长波异常。
