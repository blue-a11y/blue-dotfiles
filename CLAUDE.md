# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 概述

这是 `blue` 的 dotfiles 仓库，用于存放个人开发环境的配置文件。这是一个纯配置文件仓库，不涉及构建、测试或部署。

## 工作流程

- `./link.sh` — 交互式选择并创建 symlink 到目标位置（首次设置用）。已有文件自动备份为 `.bak`，已正确链接的自动跳过
- `./up.sh` — `git add -A`，通过 `claude` CLI 自动生成 commit message，提交并推送
- `./down.sh` — `git pull` 拉取远程最新配置

### Symlink 映射

| 仓库路径 | 目标路径 |
|---|---|
| `.vimrc` | `~/.vimrc` |
| `ghostty/config` | `~/.config/ghostty/config` |
| `nvim/` | `~/.config/nvim` |
| `zed/settings.json` | `~/.config/zed/settings.json` |
| `zed/keymap.json` | `~/.config/zed/keymap.json` |
| `claude-code/settings.json` | `~/.claude/settings.json` |
| `claude-code/.claude-powerline.json` | `~/.claude/.claude-powerline.json` |

## 配置模块

### Vim (`.vimrc`)
轻量级 Vim 配置，2 空格缩进，macOS 剪贴板同步，中文友好搜索（ignorecase + smartcase）。

### Neovim (`nvim/`)
基于 [LazyVim](https://github.com/LazyVim/LazyVim) 框架，使用 lazy.nvim 插件管理器。
- 入口：`nvim/init.lua` → `lua/config/lazy.lua`
- 自定义插件：`lua/plugins/` 下按功能分文件（lualine、neo-tree、example）
- 启用的 LazyVim extras：`neo-tree`、`mini-animate`
- 代码格式化：`stylua.toml`

### Claude Code (`claude-code/`)
- `settings.json`：界面中文，自动记忆，状态栏用 `@owloops/claude-powerline`（capsule 样式），默认模型 `opus[1m]`，中等 effort level
- `.claude-powerline.json`：powerline 主题配置

### Ghostty (`ghostty/config`)
Dracula 主题，CaskaydiaCove Nerd Font Mono 18px，macOS 玻璃模糊背景效果。

### Zed (`zed/settings.json` + `zed/keymap.json`)
Vim 模式，Tokyo Night Storm 主题，2 空格缩进，Cascadia Code 字体族。
