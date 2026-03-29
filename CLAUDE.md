# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 概述

这是 `blue` 的 dotfiles 仓库，用于存放个人开发环境的配置文件。当前包含 Vim、Claude Code、Ghostty 和 Zed 的配置。

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

- `ghostty/config` - Ghostty 终端配置
  - 主题：Dracula
  - 字体：CaskaydiaCove Nerd Font Mono，18px
  - 光标：block 样式，闪烁
  - 背景：玻璃模糊效果

- `zed/settings.json` - Zed 编辑器配置
  - Vim 模式已启用
  - UI 字体：CaskaydiaCove Nerd Font，18px
  - 缓冲区字体：Cascadia Code，16px
  - 主题：Tokyo Night Storm
  - Tab 大小：2 空格

- `zed/keymap.json` - Zed 快捷键配置

## 架构说明

这是一个纯配置文件仓库，不涉及应用程序构建、测试或部署。工作流程为：将配置文件 symlink 到目标位置（如 `~/.vimrc`）。
