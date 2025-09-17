#!/bin/zsh

# 腳本設定：任何指令失敗則立刻退出
set -e

# 獲取當前分支名稱 (這是 feature branch)
CURRENT_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)

# 確保能從分支名中提取 JIRA_INFO
if [[ "$CURRENT_BRANCH_NAME" =~ (FOR-[0-9]+) ]]; then
    JIRA_INFO="${match[1]}"
else
    echo "警告: 無法從 feature branch 名稱中找到 'FOR-xxxx' 資訊，無法推斷 deploy 分支名稱。"
    exit 0
fi

echo "--- 正在同步 $CURRENT_BRANCH_NAME 到 deploy 分支並觸發 CI/CD ---"

# 根據 feature 分支名稱推斷 deploy 分支名稱
# 從 feature branch 名稱中提取 namespace 部分 (例如: Forerunner/feature)
NAMESPACE="${CURRENT_BRANCH_NAME%/*${JIRA_INFO}*}"

# 從 feature branch 名稱中提取 JIRA_INFO 之後的部分
AFTER_JIRA=${CURRENT_BRANCH_NAME#*${JIRA_INFO}_}

# 檢查是否有環境後綴 (例如: domain-detector_test_env -> test)
if [[ "$AFTER_JIRA" == *_*_env ]]; then
    # 提取環境名稱 (最後一個 _ 之前的部分)
    ENV=${AFTER_JIRA%_env}
    ENV=${ENV##*_}
    DEPLOY_BRANCH_NAME="${NAMESPACE}/${JIRA_INFO}_deploy_${ENV}"
else
    DEPLOY_BRANCH_NAME="${NAMESPACE}/${JIRA_INFO}_deploy"
fi

echo "=> 對應的 deploy branch: $DEPLOY_BRANCH_NAME"

# 找到對應的 deploy worktree 路徑
DEPLOY_WORKTREE_PATH="$HOME/worktrees/${DEPLOY_BRANCH_NAME:t}"

if [ ! -d "$DEPLOY_WORKTREE_PATH" ]; then
    echo "錯誤: 找不到對應的 deploy worktree: $DEPLOY_WORKTREE_PATH"
    echo "請確認 deploy worktree 已正確建立。"
    exit 1
fi

echo "=> Deploy worktree 路徑: $DEPLOY_WORKTREE_PATH"

# 切換到 deploy worktree 進行操作
cd "$DEPLOY_WORKTREE_PATH"

# 檢查是否為正確的 deploy branch
CURRENT_DEPLOY_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ "$CURRENT_DEPLOY_BRANCH" != "$DEPLOY_BRANCH_NAME" ]; then
    echo "⚠️  調整 deploy worktree 分支狀態..."
    # 使用 git symbolic-ref 直接設定 HEAD
    git symbolic-ref HEAD "refs/heads/$DEPLOY_BRANCH_NAME"
    CURRENT_DEPLOY_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    if [ "$CURRENT_DEPLOY_BRANCH" != "$DEPLOY_BRANCH_NAME" ]; then
        echo "錯誤: 無法設定正確的 deploy branch (期待: $DEPLOY_BRANCH_NAME, 實際: $CURRENT_DEPLOY_BRANCH)"
        exit 1
    fi
fi

# 步驟一：將 feature branch 的最新變更 merge 到 deploy branch
echo "🔀 正在將 $CURRENT_BRANCH_NAME 的變更 merge 到 $DEPLOY_BRANCH_NAME..."
git merge "$CURRENT_BRANCH_NAME" --no-edit

# 步驟二：推送 deploy branch 到遠端觸發 CI/CD
echo "🚀 正在推送 deploy branch 到遠端觸發 CI/CD..."
git push origin "$DEPLOY_BRANCH_NAME"

echo "✅ Deploy branch 已更新並推送到遠端。"
echo "✅ CI/CD 已觸發。"
echo "--- 同步完成 ---"
