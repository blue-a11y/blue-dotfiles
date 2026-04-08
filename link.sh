#!/bin/bash
# 交互式软链接配置文件到目标位置

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

get_link() {
  case "$1" in
    vim)           echo "$HOME/.vimrc:$REPO_DIR/.vimrc" ;;
    ghostty)       echo "$HOME/.config/ghostty/config:$REPO_DIR/ghostty/config" ;;
    nvim)          echo "$HOME/.config/nvim:$REPO_DIR/nvim" ;;
    zed-settings)  echo "$HOME/.config/zed/settings.json:$REPO_DIR/zed/settings.json" ;;
    zed-keymap)    echo "$HOME/.config/zed/keymap.json:$REPO_DIR/zed/keymap.json" ;;
    claude-code)   echo "$HOME/.claude/settings.json:$REPO_DIR/claude-code/settings.json" ;;
    claude-powerline) echo "$HOME/.claude/.claude-powerline.json:$REPO_DIR/claude-code/.claude-powerline.json" ;;
  esac
}

ALL_KEYS="vim ghostty nvim zed-settings zed-keymap claude-code claude-powerline"

link() {
  local target="$1"
  local source="$2"
  local target_dir
  target_dir="$(dirname "$target")"

  # 已指向正确源文件
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    echo "  [skip] $target 已正确链接"
    return 0
  fi

  # 创建目标目录
  mkdir -p "$target_dir"

  # 备份已存在的文件/目录
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    local backup="${target}.bak"
    echo "  [backup] $target → $backup"
    mv "$target" "$backup"
  fi

  ln -snf "$source" "$target"
  echo "  [linked] $target → $source"
}

echo "请选择要链接的配置（多选用空格分隔，选 0 链接全部）："
echo ""
PS3="输入编号: "

select opt in "全部链接" "vim" "ghostty" "nvim" "zed-settings" "zed-keymap" "claude-code" "claude-powerline" "退出"; do
  case "$REPLY" in
    1)
      echo "==> 链接全部配置..."
      for key in $ALL_KEYS; do
        IFS=: read -r target source <<< "$(get_link "$key")"
        link "$target" "$source"
      done
      break
      ;;
    [2-8])
      IFS=: read -r target source <<< "$(get_link "$opt")"
      echo "==> 链接 $opt..."
      link "$target" "$source"
      break
      ;;
    9)
      echo "退出"
      break
      ;;
    *)
      echo "无效选项"
      ;;
  esac
done
