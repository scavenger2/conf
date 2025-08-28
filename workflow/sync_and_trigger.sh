#!/bin/zsh

# 腳本設定：任何指令失敗則立刻退出
set -e

# 獲取當前分支名稱
CURRENT_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)

# 確保能從分支名中提取 JIRA_INFO
if [[ "$CURRENT_BRANCH_NAME" =~ (FOR-[0-9]+) ]]; then
    JIRA_INFO="${match[1]}"
else
    echo "警告: 無法從 feature branch 名稱中找到 'FOR-xxxx' 資訊，無法推斷 deploy 分支名稱。"
    exit 0
fi

echo "--- 正在同步 $CURRENT_BRANCH_NAME 到 deploy 分支並觸發 CI/CD ---"

# 獲取主儲存庫和 worktree 路徑
MAIN_REPO_PATH=$(git rev-parse --show-toplevel)

# 根據 feature 分支名稱推斷 deploy 分支名稱
SUBSTRING=${CURRENT_BRANCH_NAME#*${JIRA_INFO}_}
if [[ "$SUBSTRING" == *_* ]]; then
    ENV=${SUBSTRING%%_*}
    DEPLOY_BRANCH_NAME="${JIRA_INFO}_deploy_${ENV}"
else
    DEPLOY_BRANCH_NAME="${JIRA_INFO}_deploy"
fi

# 獲取 deploy worktree 的路徑
WORKTREES_DIR="$HOME/worktrees"
DEPLOY_WORKTREE_PATH="$WORKTREES_DIR/$DEPLOY_BRANCH_NAME"

# 進入 deploy worktree 並進行同步
cd "$DEPLOY_WORKTREE_PATH"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "錯誤: 找不到 deploy worktree資料夾($DEPLOY_WORKTREE_PATH) 或它不是一個有效的 Git worktree，請先執行 create_feature_env.sh。"
    exit 1
fi

# 合併 feature 分支的最新變更
git merge --no-edit --no-ff "$CURRENT_BRANCH_NAME"
echo "✅ 變更已同步到 $DEPLOY_BRANCH_NAME。"

# 執行 push，觸發 CI/CD
echo "🚀 正在推送至遠端，觸發 CI/CD..."
git push origin "$DEPLOY_BRANCH_NAME"

echo "--- CI/CD 觸發已完成。 ---"
