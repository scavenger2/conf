#!/bin/zsh

# 腳本設定：任何指令失敗則立刻退出
set -e

# 腳本使用說明
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "用法: $0 [deploy_worktree_path]"
    echo ""
    echo "  [deploy_worktree_path]  : 選填，deploy branch 的 worktree 資料夾路徑。"
    echo "                           如不提供，則使用當前工作目錄（適合作為 git hook）"
    echo ""
    echo "功能: 將 deploy branch 與對應的 feature branch 及其 base branch 進行三方同步"
    exit 1
fi

# 參數處理
if [ -n "$1" ]; then
    DEPLOY_WORKTREE_PATH="$1"
else
    # 作為 git hook 時，使用當前工作目錄
    DEPLOY_WORKTREE_PATH="$(pwd)"
fi

# 檢查路徑是否存在且為有效的 Git worktree
if [ ! -d "$DEPLOY_WORKTREE_PATH" ] || ! git -C "$DEPLOY_WORKTREE_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "錯誤: 提供的路徑不是一個有效的 Git worktree。"
    exit 1
fi

echo "--- 開始同步 deploy worktree ---"
cd "$DEPLOY_WORKTREE_PATH"

# 獲取當前 deploy branch 名稱
DEPLOY_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
echo "=> 當前 deploy branch: $DEPLOY_BRANCH_NAME"

# 從 Git 配置中讀取關聯的 feature branch 資訊
FEATURE_BRANCH_NAME=$(git config branch."$DEPLOY_BRANCH_NAME".featurebranch 2>/dev/null || echo "")
FEATURE_WORKTREE_PATH=$(git config branch."$DEPLOY_BRANCH_NAME".featureworktree 2>/dev/null || echo "")

if [ -z "$FEATURE_BRANCH_NAME" ] || [ -z "$FEATURE_WORKTREE_PATH" ]; then
    echo "錯誤: 無法找到對應的 feature branch 資訊。"
    echo "請確認此 deploy worktree 是由 create_feature_env.sh 建立的。"
    exit 1
fi

echo "=> 對應的 feature branch: $FEATURE_BRANCH_NAME"
echo "=> Feature worktree path: $FEATURE_WORKTREE_PATH"

# 檢查 feature worktree 是否存在
if [ ! -d "$FEATURE_WORKTREE_PATH" ]; then
    echo "錯誤: Feature worktree 路徑不存在: $FEATURE_WORKTREE_PATH"
    exit 1
fi

# 獲取 feature branch 的 base branch (從 git config 讀取)
cd "$FEATURE_WORKTREE_PATH"
BASE_BRANCH=$(git config branch."$FEATURE_BRANCH_NAME".basebranch 2>/dev/null || echo "")

if [ -z "$BASE_BRANCH" ]; then
    echo "錯誤: 無法找到 feature branch 的 base branch 資訊。"
    echo "請確認此 feature worktree 是由新版的 create_feature_env.sh 建立的。"
    exit 1
fi
echo "=> Feature branch 的 base branch: $BASE_BRANCH"

# 回到 deploy worktree 進行同步
cd "$DEPLOY_WORKTREE_PATH"

# 檢查是否有未提交的修改
if [ -n "$(git status --porcelain)" ]; then
    echo "警告: Deploy worktree 有未提交的修改。"
    read "?是否要繼續同步？可能會產生衝突 (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "取消同步。"
        exit 0
    fi
fi

echo ""
echo "--- 開始三方同步 ---"

# 步驟 1: 更新遠端 base branch 資訊
echo "🔄 正在更新遠端 $BASE_BRANCH 分支資訊..."
git fetch origin "$BASE_BRANCH"

# 步驟 2: 更新 feature branch (確保是最新的)
echo "🔄 正在更新 feature branch..."
cd "$FEATURE_WORKTREE_PATH"
if [ -z "$(git status --porcelain)" ]; then
    git pull origin "$BASE_BRANCH" 2>/dev/null || git rebase origin/"$BASE_BRANCH"
    echo "✅ Feature branch 已更新"
else
    echo "⚠️ Feature branch 有未提交修改，跳過更新"
fi

# 步驟 3: 回到 deploy worktree 進行合併
cd "$DEPLOY_WORKTREE_PATH"

# 合併 feature branch 的最新變更
echo "🔀 正在合併 feature branch: $FEATURE_BRANCH_NAME"
git merge "$FEATURE_BRANCH_NAME" --no-edit

# 合併 base branch 的最新變更
echo "🔀 正在合併 base branch: origin/$BASE_BRANCH"
git merge "origin/$BASE_BRANCH" --no-edit

# 步驟 4: 推送 deploy branch 到遠端觸發 CI/CD
echo "🚀 正在推送 deploy branch 到遠端觸發 CI/CD..."

if git push origin "$DEPLOY_BRANCH_NAME"; then
    echo "✅ Deploy branch 已推送到遠端"
    echo "✅ CI/CD 已觸發"
else
    echo "❌ 推送失敗，請檢查網路連線或權限設定"
    exit 1
fi

echo ""
echo "✅ 三方同步完成！"
echo "Deploy branch 已包含："
echo "  - Feature branch ($FEATURE_BRANCH_NAME) 的最新變更"
echo "  - Base branch (origin/$BASE_BRANCH) 的最新變更"
echo ""
echo "--- 同步並推送完成 ---"