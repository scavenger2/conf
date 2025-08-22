#!/bin/zsh

# 腳本設定：任何指令失敗則立刻退出
set -e

# 獲取當前分支名稱
CURRENT_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)

# 確保只在 feature 分支上運行
if [[ ! "$CURRENT_BRANCH_NAME" == "feature"* ]]; then
    echo "非 feature 分支，跳過同步。"
    exit 0
fi

echo "--- 正在同步 $CURRENT_BRANCH_NAME 到 deploy 分支並觸發 CI/CD ---"

# 獲取主儲存庫和 worktree 路徑
MAIN_REPO_PATH=$(git rev-parse --show-toplevel)
WORKTREE_PATH=$(pwd)

# 根據 feature 分支名稱推斷 deploy 分支名稱
DEPLOY_BRANCH_NAME="deploy-${CURRENT_BRANCH_NAME#feature-}"
DEPLOY_WORKTREE_PATH="$HOME/worktrees/$DEPLOY_BRANCH_NAME"

# 進入 deploy worktree 並進行同步
cd "$DEPLOY_WORKTREE_PATH"

# 合併 feature 分支的最新變更
# --no-edit 避免進入編輯器
# --no-ff 避免快進合併，保留合併 commit
git merge --no-edit --no-ff "$MAIN_REPO_PATH/$CURRENT_BRANCH_NAME"

echo "✅ 變更已同步到 $DEPLOY_BRANCH_NAME。"

# 執行 push，觸發 CI/CD
echo "🚀 正在推送至遠端，觸發 CI/CD..."
git push origin "$DEPLOY_BRANCH_NAME"

echo "--- CI/CD 觸發已完成。 ---"
