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
    echo "⚠️  需要切換到正確的 deploy branch..."

    # 檢查是否有未提交的變更
    if ! git diff-index --quiet HEAD 2>/dev/null; then
        echo "錯誤: Deploy worktree 有未提交的變更，無法切換分支"
        echo "請先在 deploy worktree 中提交或重置變更"
        exit 1
    fi

    # 使用安全的 checkout 方式切換分支
    if git checkout "$DEPLOY_BRANCH_NAME" 2>/dev/null; then
        echo "✅ 已切換到 deploy branch: $DEPLOY_BRANCH_NAME"
    else
        echo "錯誤: 無法切換到 deploy branch: $DEPLOY_BRANCH_NAME"
        echo "請檢查 deploy branch 是否存在"
        exit 1
    fi

    # 再次確認當前分支
    CURRENT_DEPLOY_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$CURRENT_DEPLOY_BRANCH" != "$DEPLOY_BRANCH_NAME" ]; then
        echo "錯誤: 分支切換失敗 (期待: $DEPLOY_BRANCH_NAME, 實際: $CURRENT_DEPLOY_BRANCH)"
        exit 1
    fi
fi

# 步驟一：將 feature branch 的最新變更 merge 到 deploy branch
echo "🔀 正在將 $CURRENT_BRANCH_NAME 的變更 merge 到 $DEPLOY_BRANCH_NAME..."

# 檢查 feature branch 是否存在
if ! git show-ref --verify --quiet "refs/heads/$CURRENT_BRANCH_NAME"; then
    echo "錯誤: Feature branch '$CURRENT_BRANCH_NAME' 不存在"
    exit 1
fi

# 執行 merge 並檢查結果
if git merge "$CURRENT_BRANCH_NAME" --no-edit; then
    echo "✅ Merge 成功"
else
    echo "❌ Merge 失敗，可能有衝突需要手動解決"
    exit 1
fi

# 步驟二：推送 deploy branch 到遠端觸發 CI/CD
echo "🚀 正在推送 deploy branch 到遠端觸發 CI/CD..."

if git push origin "$DEPLOY_BRANCH_NAME"; then
    echo "✅ Deploy branch 已更新並推送到遠端"
    echo "✅ CI/CD 已觸發"
else
    echo "❌ 推送失敗，請檢查網路連線或權限設定"
    exit 1
fi

echo "--- 同步完成 ---"
