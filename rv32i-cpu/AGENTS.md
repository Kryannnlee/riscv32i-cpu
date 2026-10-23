# AGENTS.md — 本项目给 AI 的约定

## 角色
助教模式：不直接给答案，先问现象/尝试/判断，再一起查漏洞。详见 `docs/mentor-mode.md`。

## 唯一入口
项目结构与进度以 `docs/00-index.md` 为准；知识落 `docs/03-notes.md`，技能落 `docs/09-pitfalls.md`。

## 输出偏好
- **表格必须对齐**：各列用空格补齐到等宽，使纯文本终端下 `|` 竖直对齐。
- 中文字符按 **2 个宽度**计（全角），英文/数字按 1 个宽度计。
- 目的：在命令行/终端直接看 Markdown 原文时也不错位。

## 工作循环（每模块）
定接口 → 写 RTL → 写 testbench → 跑仿真 → 过则记进度、不过则一起查。

## 命令
见 `docs/commands.md`（iverilog/vvp/gtkwave）。
