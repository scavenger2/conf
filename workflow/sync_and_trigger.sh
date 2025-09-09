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
NAMESPACE="${CURRENT_BRANCH_NAME%/${JIRA_INFO}*}"
if [[ "$SUBSTRING" == *_* ]]; then
    ENV=${SUBSTRING%%_*}
    DEPLOY_BRANCH_NAME="${NAMESPACE}/${JIRA_INFO}_deploy_${ENV}"
else
    DEPLOY_BRANCH_NAME="${NAMESPACE}/${JIRA_INFO}_deploy"
fi

# 獲取 deploy worktree 的路徑
WORKTREES_DIR="$HOME/worktrees"
DEPLOY_WORKTREE_PATH="$WORKTREES_DIR/${DEPLOY_BRANCH_NAME:t}"

# 進入 deploy worktree 並進行同步
cd "$DEPLOY_WORKTREE_PATH"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "錯誤: 找不到 deploy worktree資料夾($DEPLOY_WORKTREE_PATH) 或它不是一個有效的 Git worktree，請先執行 create_feature_env.sh。"
    exit 1
fi
echo "Deploy branch name: $DEPLOY_BRANCH_NAME, path: $DEPLOY_WORKTREE_PATH"

# --- 核心邏輯修正：合併變更並推送到遠端 ---
# 先從遠端拉取最新變更，確保本地 deploy 分支是最新的
echo "🔄 正在從遠端拉取最新變更..."
git pull --ff-only

# 合併 feature 分支的最新變更
# 這裡使用 --no-ff 來確保每次合併都產生一個新的 commit
echo "➡️ 正在合併 feature 分支的變更..."
git merge --no-edit --no-ff "$CURRENT_BRANCH_NAME"
echo "✅ 變更已合併到 $DEPLOY_BRANCH_NAME。"

# 檢查上游追蹤是否已設定，如果沒有，則在推送後設定
UPSTREAM_BRANCH=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)
echo "UPSTREAM_BRANCH=${UPSTREAM_BRANCH}"
if [ -z "$UPSTREAM_BRANCH" ]; then
    echo "🚀 正在推送至遠端並建立追蹤，觸發 CI/CD..."
    git push -u origin "$DEPLOY_BRANCH_NAME"
else
    echo "🚀 正在推送至遠端，觸發 CI/CD..."
    git push
fi

echo "--- CI/CD 觸發已完成。 ---"
