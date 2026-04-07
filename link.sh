#!/bin/bash
# 交互式软链接配置文件到目标位置

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

declare -A TARGETS
TARGETS=(
  [vim]="$HOME/.vimrc:$REPO_DIR/.vimrc"
  [ghostty]="$HOME/.config/ghostty/config:$REPO_DIR/ghostty/config"
  [nvim]="$HOME/.config/nvim:$REPO_DIR/nvim"
  [zed-settings]="$HOME/.config/zed/settings.json:$REPO_DIR/zed/settings.json"
  [zed-keymap]="$HOME/.config/zed/keymap.json:$REPO_DIR/zed/keymap.json"
  [claude-code]="$HOME/.claude/settings.json:$REPO_DIR/claude-code/settings.json"
  [claude-powerline]="$HOME/.claude/.claude-powerline.json:$REPO_DIR/claude-code/.claude-powerline.json"
)

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

select opt in "全部链接" "vim" "ghostty" "nvim" "zed-settings" "zed-keymap" "claude-code" "退出"; do
  case "$REPLY" in
    1)
      echo "==> 链接全部配置..."
      for key in "${!TARGETS[@]}"; do
        IFS=: read -r target source <<< "${TARGETS[$key]}"
        link "$target" "$source"
      done
      break
      ;;
    [2-7])
      local_key="$opt"
      IFS=: read -r target source <<< "${TARGETS[$local_key]}"
      echo "==> 链接 $local_key..."
      link "$target" "$source"
      break
      ;;
    8)
      echo "退出"
      break
      ;;
    *)
      echo "无效选项"
      ;;
  esac
done
