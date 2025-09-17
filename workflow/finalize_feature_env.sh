#!/bin/zsh

# 腳本設定：任何指令失敗則立刻退出
set -e

# 腳本使用說明
if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ -z "$1" ]; then
    echo "用法: $0 <deploy_worktree_path>"
    echo ""
    echo "  <deploy_worktree_path>  : 必填，deploy worktree 的路徑。"
    echo ""
    echo "範例: $0 /Users/dean.sung/worktrees/FOR-4043_deploy"
    exit 1
fi

# 參數處理
DEPLOY_WORKTREE_PATH="$1"

echo "--- 開始清理 deploy 環境 ---"
echo "=> Deploy worktree 路徑: $DEPLOY_WORKTREE_PATH"

# 檢查 deploy worktree 是否存在
if [ ! -d "$DEPLOY_WORKTREE_PATH" ]; then
    echo "錯誤: Deploy worktree 路徑不存在: $DEPLOY_WORKTREE_PATH"
    exit 1
fi

# 1. 從 deploy worktree 獲取相關資訊
cd "$DEPLOY_WORKTREE_PATH"
DEPLOY_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
FEATURE_BRANCH_NAME=$(git config branch."$DEPLOY_BRANCH_NAME".featurebranch || echo "")
FEATURE_WORKTREE_PATH=$(git config branch."$DEPLOY_BRANCH_NAME".featureworktree || echo "")

echo "=> Deploy 分支名稱: $DEPLOY_BRANCH_NAME"
echo "=> Feature 分支名稱: $FEATURE_BRANCH_NAME"
echo "=> Feature worktree 路徑: $FEATURE_WORKTREE_PATH"

if [ -z "$FEATURE_BRANCH_NAME" ]; then
    echo "錯誤: 無法從 deploy branch 配置中找到對應的 feature branch 資訊"
    echo "請確認此 deploy worktree 是由 create_feature_env.sh 建立的"
    exit 1
fi

# 2. 切換到主儲存庫
MAIN_REPO_PATH="/Users/dean.sung/projects/web2"
echo "=> 使用主儲存庫路徑: $MAIN_REPO_PATH"
cd "$MAIN_REPO_PATH"

# 3. 只刪除 deploy worktree (feature worktree 要保留)
if git worktree list | grep -q "$DEPLOY_WORKTREE_PATH"; then
    git worktree remove "$DEPLOY_WORKTREE_PATH" --force
    echo "✅ Deploy worktree 已刪除。"
else
    echo "⚠️ Deploy worktree 不存在，跳過刪除。"
fi

echo "=> Feature worktree 保留在: $FEATURE_WORKTREE_PATH"

# 4. 為 feature branch 設定正確的 upstream 並推送
echo "--- 為 feature branch 設定 upstream ---"
if git show-ref --verify --quiet "refs/heads/$FEATURE_BRANCH_NAME"; then
    # 切換到 feature branch
    git checkout "$FEATURE_BRANCH_NAME"
    echo "✅ 已切換到 feature branch: $FEATURE_BRANCH_NAME"

    # 設定 upstream 並推送
    git push --set-upstream origin "$FEATURE_BRANCH_NAME"
    echo "✅ Feature branch upstream 已設定並推送到遠端"
else
    echo "⚠️ 本地 feature 分支不存在，跳過 upstream 設定"
fi

# 5. 刪除 deploy 分支（本地和遠端）
echo "--- 清理 deploy 分支 ---"
if git ls-remote --exit-code origin "$DEPLOY_BRANCH_NAME" > /dev/null 2>&1; then
    git push origin --delete "$DEPLOY_BRANCH_NAME"
    echo "✅ 遠端 deploy 分支已刪除。"
else
    echo "⚠️ 遠端 deploy 分支不存在，跳過刪除。"
fi

if git show-ref --verify --quiet "refs/heads/$DEPLOY_BRANCH_NAME"; then
    # 確保不在要刪除的分支上
    if [ "$(git rev-parse --abbrev-ref HEAD)" = "$DEPLOY_BRANCH_NAME" ]; then
        git checkout develop
    fi
    git branch -D "$DEPLOY_BRANCH_NAME"
    echo "✅ 本地 deploy 分支已刪除。"
else
    echo "⚠️ 本地 deploy 分支不存在，跳過刪除。"
fi

echo "--- 環境清理完成！ ---"
echo ""
echo "🎉 Feature branch $FEATURE_BRANCH_NAME 現在可以繼續開發並直接推送觸發 CI/CD"
echo "📍 後續的 commit 將被視為 fix，可以直接使用 git push 推送"