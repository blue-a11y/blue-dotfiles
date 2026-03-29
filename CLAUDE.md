# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 概述

这是 `blue` 的 dotfiles 仓库，用于存放个人开发环境的配置文件。当前仅包含 Vim 配置 (`.vimrc`) 和 Claude Code 设置。

## 关键文件

- `.vimrc` - Vim 编辑器配置
  - 2 空格缩进（Tab 转空格）
  - 鼠标支持已启用
  - macOS 剪贴板同步
  - 中文界面
  - 搜索高亮和增量搜索

- `claude-code/settings.json` - Claude Code CLI 配置
  - 界面语言：中文
  - 启用自动记忆功能
  - 状态栏使用 rose-pine 主题

## 架构说明

这是一个纯配置文件仓库，不涉及应用程序构建、测试或部署。工作流程为：将配置文件 symlink 到目标位置（如 `~/.vimrc`）。
