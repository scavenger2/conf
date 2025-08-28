#!/bin/zsh

# 腳本設定：任何指令失敗則立刻退出
set -e

# 腳本使用說明
if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ -z "$1" ]; then
    echo "用法: $0 <feature_branch_name>"
    echo ""
    echo "  <feature_branch_name>  : 必填，要刪除的 feature 分支名稱。"
    exit 1
fi

# 參數處理
FEATURE_BRANCH_NAME="$1"

echo "--- 開始清理 ${FEATURE_BRANCH_NAME} 相關環境 ---"

# 獲取主儲存庫路徑
MAIN_REPO_PATH=$(git rev-parse --show-toplevel)
cd "$MAIN_REPO_PATH"

# 1. 根據 feature 分支名稱推斷 worktree 路徑
SANITIZED_BRANCH_PATH_TAIL=${FEATURE_BRANCH_NAME:t}
SANITIZED_BRANCH_PATH_HEAD=${FEATURE_BRANCH_NAME:h}
if [ -n "$SANITIZED_BRANCH_PATH_HEAD" ]; then
    FEATURE_WORKTREE_PATH="$HOME/worktrees/$SANITIZED_BRANCH_PATH_HEAD/$SANITIZED_BRANCH_PATH_TAIL"
else
    FEATURE_WORKTREE_PATH="$HOME/worktrees/$SANITIZED_BRANCH_PATH_TAIL"
fi

# 2. 根據 feature 分支名稱推斷 deploy 分支名稱
if [[ "$FEATURE_BRANCH_NAME" =~ (FOR-[0-9]+) ]]; then
    JIRA_INFO="${match[1]}"
else
    echo "錯誤: 無法從 feature branch 名稱中找到 'FOR-xxxx' 資訊。"
    exit 1
fi

SUBSTRING=${FEATURE_BRANCH_NAME#*${JIRA_INFO}_}
if [[ "$SUBSTRING" == *_* ]]; then
    ENV=${SUBSTRING%%_*}
    DEPLOY_BRANCH_NAME="${JIRA_INFO}_deploy_${ENV}"
else
    DEPLOY_BRANCH_NAME="${JIRA_INFO}_deploy"
fi

# 3. 刪除 worktrees
if git worktree list | grep -q "$FEATURE_WORKTREE_PATH"; then
    git worktree remove "$FEATURE_WORKTREE_PATH"
    echo "✅ Feature worktree 已刪除。"
else
    echo "⚠️ Feature worktree 不存在，跳過刪除。"
fi

DEPLOY_WORKTREE_PATH="$HOME/worktrees/$DEPLOY_BRANCH_NAME"
if git worktree list | grep -q "$DEPLOY_WORKTREE_PATH"; then
    git worktree remove "$DEPLOY_WORKTREE_PATH"
    echo "✅ Deploy worktree 已刪除。"
else
    echo "⚠️ Deploy worktree 不存在，跳過刪除。"
fi

# 4. 刪除遠端分支
if git ls-remote --exit-code origin "$FEATURE_BRANCH_NAME"; then
    git push origin --delete "$FEATURE_BRANCH_NAME"
    echo "✅ 遠端 feature 分支已刪除。"
else
    echo "⚠️ 遠端 feature 分支不存在，跳過刪除。"
fi

if git ls-remote --exit-code origin "$DEPLOY_BRANCH_NAME"; then
    git push origin --delete "$DEPLOY_BRANCH_NAME"
    echo "✅ 遠端 deploy 分支已刪除。"
else
    echo "⚠️ 遠端 deploy 分支不存在，跳過刪除。"
fi

echo "--- 環境清理完成！ ---"
