# Maho Memory Bank

这个目录是 `Maho` 工作区的跨对话记忆库，用来保存各项目的阶段总结、交接记录和可复用上下文。

## 设计目标

- 新开对话时，不用重复输入一大段背景
- 窗口上下文过大时，可以先写 handoff 再切换窗口
- 不同项目的工作记录彼此隔离，但放在同一个总入口下统一管理

## 推荐结构

- [`INDEX.md`](</C:/Users/Chp/Documents/Maho/memory_bank/INDEX.md>)
  - 总索引，说明当前有哪些项目记忆
- [`projects/`](</C:/Users/Chp/Documents/Maho/memory_bank/projects>)
  - 按项目分目录保存
- [`templates/session_handoff_template.md`](</C:/Users/Chp/Documents/Maho/memory_bank/templates/session_handoff_template.md>)
  - 会话总结模板

## 总结文档应该怎么写

推荐做法是：

- **每次总结单独写成一个新的 `.md` 文件**
- 不建议把所有历史一直追加到同一个大文档里

原因：

- 单文件按日期和主题切分，回看更快
- 不会因为一个文件太长而变得难检索
- 不同阶段的结论不会互相覆盖
- 可以在 `INDEX.md` 里明确标出“最新建议先看哪份”

## 建议命名

推荐使用：

`YYYY-MM-DD-主题.md`

例如：

- `2026-05-18-main-inversion-handoff.md`
- `2026-05-19-gravity-branch-followup.md`

## 推荐工作流

1. 一个窗口要结束时，按模板写一份新的总结文件。
2. 在对应项目的 `INDEX.md` 中把它登记进去。
3. 如果它是当前最重要的上下文，就把它标记成“Latest”。
4. 新窗口开始时，先阅读项目 `INDEX.md` 和最新总结。
