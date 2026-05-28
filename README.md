# Maho

本仓库用于管理腾冲火山区重力-面波联合反演相关代码、实验目录、参数选择脚本和阶段性文档。

## 主要目录

- `tc_cross_joint/`
  - 主联合反演工作目录
  - 当前用于交叉梯度约束下的重震联合反演、参数扫描和结果整理
- `tc_Checkboard/`
  - 当前交叉梯度联合反演框架下的检测板实验目录
- `JointSG_checkboard/`
  - 传统联合反演框架下的检测板实验目录
- `lcurve_s25/`
  - L-curve 相关脚本与历史实验材料
- `memory_bank/`
  - 跨对话工作记录、handoff 摘要和项目索引
- `fig1_dem/`, `fig_phase/`, `fig_WGM2012/`
  - 区域底图、相速度和重力绘图相关材料

## 项目结构约定

- 不同实验尽量按目录隔离，而不是依赖多个 Git 分支隔离
- `exports/`、运行日志、临时绘图结果和自动生成目录默认不纳入版本控制
- `doc/` 目录当前不纳入 Git 跟踪，用于放置个人参考文档和外部 PDF
- 参数选择实验相关脚本集中放在 `tc_cross_joint/parameter_selection/`

## 典型工作流

1. 在对应实验目录中修改脚本或参数文件
2. 在 Ubuntu 环境中运行 Shell 主控脚本
3. 检查 `results/`、`logs/` 和导出的关键结果
4. 仅将需要长期保留的脚本、配置、说明文档提交到 Git

## Git 使用建议

- 日常主要在 `master` 分支工作
- 提交前先看：
  - `git status`
  - `git diff --stat`
- 如果只想提交某个实验目录，显式指定目录或文件，例如：
  - `git add tc_Checkboard`
  - `git add tc_cross_joint`
- 对关键实验结果，优先用收集脚本导出到 `exports/`，不要依赖 Git 保存大体量结果文件

## 当前环境

- 主控：Shell
- 耦合：Python
- 物理引擎：Fortran（DSurfTomo / JointSG）
- 运行环境：Ubuntu 18.04
- 绘图：GMT

## 说明

- 本仓库中的部分脚本会同时在 Windows 工作区与 Ubuntu 虚拟机共享目录中维护，提交前建议确认最终以哪一侧为准
- 若目录重组导致 Git 显示删除/新增，优先确认是否属于“移动文件”而不是误删文件
