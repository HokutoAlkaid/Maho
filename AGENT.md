# AGENT.md

这是 `C:\Users\Chp\Documents\Maho` 工作区的简要约定。

## Python

- 不要默认用 `python` 或 `py`，它们不一定在 PATH 里。
- 优先用：
  - `C:\Users\Chp\.local\bin\python3.11.exe`
- 如果要用 `uv`，优先用：
  - `C:\Users\Chp\.local\bin\uv.exe`
- 用 `uv` 时，先设：
  - `UV_CACHE_DIR=C:\Users\Chp\Documents\Maho\.uv-cache`
- 需要固定版本时，用：
  - `uv run --python 3.11 python ...`

## 记忆库

- 记忆库根目录：
  - `C:\Users\Chp\Documents\Maho\memory_bank`
- 默认项目：
  - `tc_cross_joint`
- 新窗口继续时，先读：
  - `memory_bank/projects/<project>/INDEX.md`
- 然后优先读：
  - `Latest` 对应的 summary

## 总结规则

- 一次阶段性工作，尽量写一份新的 summary。
- 不要把所有历史都追加到同一个大文件里。
- 写完新的 summary 后，记得更新对应项目的 `INDEX.md`。

## 常用项目

- 主反演项目：
  - `C:\Users\Chp\Documents\Maho\tc_cross_joint`
- 检测板项目：
  - `C:\Users\Chp\Documents\Maho\tc_Checkboard`

## 推荐做法

- 读写记忆库时，优先用 `$memory-bank-handoff`。
- 如果用户只说“读记忆库”或“存记忆库”，默认先按当前正在处理的项目判断。
