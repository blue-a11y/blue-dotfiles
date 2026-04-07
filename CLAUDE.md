# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 概述

这是 `blue` 的 dotfiles 仓库，用于存放个人开发环境的配置文件。这是一个纯配置文件仓库，不涉及构建、测试或部署。

## 工作流程

- `./up.sh` — 自动生成 commit message（调用 `claude` CLI 解读 diff），提交并推送到远程
- `./down.sh` — 从远程拉取最新配置
- 配置通过 symlink 链接到目标位置（如 `~/.vimrc`）

## 配置模块

### Vim (`.vimrc`)
轻量级 Vim 配置，2 空格缩进，macOS 剪贴板同步，中文友好搜索（ignorecase + smartcase）。

### Neovim (`nvim/`)
基于 [LazyVim](https://github.com/LazyVim/LazyVim) 框架，使用 lazy.nvim 插件管理器。
- 入口：`nvim/init.lua` → `lua/config/lazy.lua`
- 自定义插件：`lua/plugins/` 下按功能分文件（lualine、neo-tree、example）
- 启用的 LazyVim extras：`neo-tree`、`mini-animate`
- 代码格式化：`stylua.toml`

### Claude Code (`claude-code/settings.json`)
界面语言中文，自动记忆已开启，状态栏使用 `@owloops/claude-powerline`（rose-pine 主题），默认模型 `opus[1m]`，中等 effort level。

### Ghostty (`ghostty/config`)
Dracula 主题，CaskaydiaCove Nerd Font Mono 18px，macOS 玻璃模糊背景效果。

### Zed (`zed/settings.json` + `zed/keymap.json`)
Vim 模式，Tokyo Night Storm 主题，2 空格缩进，Cascadia Code 字体族。
