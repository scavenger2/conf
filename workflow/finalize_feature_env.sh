#!/bin/zsh

# 腳本設定：任何指令失敗則立刻退出
set -e

# 獲取傳入的 worktree 路徑
WORKTREE_PATH="$1"

# 檢查路徑是否為有效的 Git worktree
if [ -z "$WORKTREE_PATH" ] || [ ! -d "$WORKTREE_PATH/.git" ]; then
    echo "錯誤: 請傳入一個有效的 Git worktree 路徑作為參數。"
    exit 1
fi

# 進入 worktree 目錄
cd "$WORKTREE_PATH"

# 獲取當前所在的分支名稱
CURRENT_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)

# 確保只在 feature 分支上運行
if [[ ! "$CURRENT_BRANCH_NAME" == "feature"* ]]; then
    echo "錯誤: 此腳本必須在 feature 分支上執行。"
    exit 1
fi

echo "--- 正在清理相關的 Git 環境 ---"

# 獲取主儲存庫和 worktree 路徑
MAIN_REPO_PATH=$(git rev-parse --show-toplevel)
WORKTREE_PATH=$(pwd)

# 根據 feature 分支名稱推斷 deploy 分支名稱
DEPLOY_BRANCH_NAME="deploy-${CURRENT_BRANCH_NAME#feature-}"
DEPLOY_WORKTREE_PATH="$HOME/worktrees/$DEPLOY_BRANCH_NAME"

# 刪除遠端和本地的 deploy 分支
echo "1. 刪除遠端和本地的 deploy 分支: $DEPLOY_BRANCH_NAME..."
cd "$MAIN_REPO_PATH"
git push origin --delete "$DEPLOY_BRANCH_NAME"
git branch -D "$DEPLOY_BRANCH_NAME"
echo "✅ 刪除完成。"

# 刪除 deploy worktree
echo "2. 刪除 deploy worktree: $DEPLOY_WORKTREE_PATH..."
git worktree remove --force "$DEPLOY_WORKTREE_PATH"
echo "✅ 刪除完成。"

echo "--- 清理完成。 ---"
echo "您現在可以回到您的主儲存庫，並刪除本地的 feature 分支。"
echo "cd $MAIN_REPO_PATH && git branch -D $CURRENT_BRANCH_NAME"
