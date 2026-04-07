#!/bin/bash
# 同步到远程仓库

set -e

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Not a git repository. Run: git init"
    exit 1
fi

# 暂存所有更改（包括未跟踪文件）
git add -A

# 检查是否有待提交的内容
if git diff --cached --quiet; then
    echo "Nothing to commit"
else
    echo "==> 生成 commit message..."
    COMMIT_MSG=$(git diff --cached --stat | claude -p "根据以下 git diff 统计信息生成一个简短的 commit message（英文，50字符以内，格式：type(scope): description，只返回 message 本身，不要其他内容）：" 2>/dev/null | head -1 | tr -d '`')

    echo "==> 提交更改: $COMMIT_MSG"
    git commit -m "$COMMIT_MSG"
fi

echo "==> 推送到远程..."
git push -u origin $(git symbolic-ref --short HEAD)
