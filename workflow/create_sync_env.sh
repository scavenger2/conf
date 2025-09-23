#!/bin/zsh

# 腳本設定：任何指令失敗則立刻退出
set -e

# 腳本使用說明
if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ -z "$1" ]; then
    echo "用法: $0 <repo_path> [base_branch]"
    echo ""
    echo "  <repo_path>    : 必填，現有 Git 專案資料夾的路徑。"
    echo "  [base_branch]  : 選填，要追蹤的分支名稱。預設: develop"
    echo ""
    echo "範例:"
    echo "  $0 /Users/dean.sung/projects/web2"
    echo "  $0 /Users/dean.sung/projects/web2 main"
    echo ""
    echo "功能: 建立一個 worktree 來追蹤指定的 base branch，當 base branch 有更新時會自動同步"
    echo "      Worktree 路徑格式: ~/worktrees/{repo名稱}-sync-{branch名稱}"
    exit 1
fi

# 參數處理
REPO_PATH="$1"
BASE_BRANCH=${2:-develop}

# 驗證 repo 路徑
if [ ! -d "$REPO_PATH" ]; then
    echo "錯誤: 提供的路徑不存在: $REPO_PATH"
    exit 1
fi

# 自動找到主儲存庫的路徑
MAIN_REPO_PATH=$(git -C "$REPO_PATH" rev-parse --show-toplevel 2>/dev/null || echo "")

if [ -z "$MAIN_REPO_PATH" ] || [ ! -d "$MAIN_REPO_PATH/.git" ]; then
    echo "錯誤: 提供的路徑不是一個有效的 Git 儲存庫: $REPO_PATH"
    exit 1
fi

echo "--- 開始建立 sync 環境 ---"
echo "=> 主儲存庫路徑: $MAIN_REPO_PATH"
echo "=> 追蹤分支: $BASE_BRANCH"

cd "$MAIN_REPO_PATH"

# 檢查 base branch 是否存在
if ! git show-ref --verify --quiet "refs/heads/$BASE_BRANCH" && ! git show-ref --verify --quiet "refs/remotes/origin/$BASE_BRANCH"; then
    echo "錯誤: 分支 '$BASE_BRANCH' 不存在於本地或遠端"
    echo "可用的分支:"
    git branch -a | head -10
    exit 1
fi

# 確保 base branch 是最新的
echo "--- 更新 base branch ---"
if git show-ref --verify --quiet "refs/remotes/origin/$BASE_BRANCH"; then
    git fetch origin
    if git show-ref --verify --quiet "refs/heads/$BASE_BRANCH"; then
        git checkout "$BASE_BRANCH"
        git pull origin "$BASE_BRANCH"
    else
        git checkout -b "$BASE_BRANCH" "origin/$BASE_BRANCH"
    fi
    echo "✅ Base branch '$BASE_BRANCH' 已更新"
else
    echo "=> Base branch '$BASE_BRANCH' 僅存在於本地"
fi

# 建立 sync worktree
# 從 repo 路徑中提取資料夾名稱，避免不同 repo 的 worktree 路徑衝突
REPO_NAME=$(basename "$MAIN_REPO_PATH")
SYNC_BRANCH_NAME="sync-${BASE_BRANCH}"
SYNC_WORKTREE_PATH="$HOME/worktrees/${REPO_NAME}-sync-${BASE_BRANCH}"

echo "=> Repo 名稱: $REPO_NAME"

# 檢查 worktree 是否已存在
if [ -d "$SYNC_WORKTREE_PATH" ]; then
    echo "錯誤: Sync worktree 已存在: $SYNC_WORKTREE_PATH"
    echo "如果要重新建立，請先手動刪除此目錄"
    exit 1
fi

# 檢查 sync branch 是否已存在
if git show-ref --verify --quiet "refs/heads/$SYNC_BRANCH_NAME"; then
    echo "錯誤: Sync branch '$SYNC_BRANCH_NAME' 已存在"
    echo "如果要重新建立，請先刪除此分支: git branch -D $SYNC_BRANCH_NAME"
    exit 1
fi

echo "--- 建立 sync worktree ---"
mkdir -p $(dirname "$SYNC_WORKTREE_PATH")

# 建立 sync branch 和 worktree
git worktree add -b "$SYNC_BRANCH_NAME" "$SYNC_WORKTREE_PATH" "$BASE_BRANCH"
echo "✅ Sync worktree 建立於: $SYNC_WORKTREE_PATH"

# 切換到 sync worktree 進行設定
cd "$SYNC_WORKTREE_PATH"

# 設定 sync branch 的 upstream
git branch --set-upstream-to=origin/"$BASE_BRANCH"
echo "✅ Sync branch upstream 已設定為: origin/$BASE_BRANCH"

# 記錄 sync branch 與 base branch 的關聯
git config branch."$SYNC_BRANCH_NAME".basebranch "$BASE_BRANCH"
git config branch."$SYNC_BRANCH_NAME".mainrepo "$MAIN_REPO_PATH"
echo "✅ Sync branch 關聯資訊已記錄"

# 為 sync worktree 建立 hooks (參考 create_feature_env.sh 的模式)
GIT_HOOKS_DIR="$HOME/projects/conf/workflow"
echo "--- 正在為 sync worktree 建立 hooks 的 symbolic links ---"

mkdir -p "$(git rev-parse --git-dir)/hooks"
ln -s "$GIT_HOOKS_DIR/sync_base_branch.sh" "$(git rev-parse --git-dir)/hooks/post-merge"
git config core.hooksPath "$(git rev-parse --git-dir)/hooks"
echo "✅ Sync worktree 的 hooks 連結已建立"

echo ""
echo "--- Sync 環境設定完成！ ---"
echo "📁 Sync worktree 路徑: $SYNC_WORKTREE_PATH"
echo "🌿 Sync branch: $SYNC_BRANCH_NAME"
echo "🎯 追蹤分支: $BASE_BRANCH"
echo "📦 Repository: $REPO_NAME"
echo ""
echo "使用方式:"
echo "1. 進入 sync worktree: cd $SYNC_WORKTREE_PATH"
echo "2. 當 $BASE_BRANCH 有更新並被 merge 時，會自動觸發 post-merge hook 進行同步"
echo "3. 手動觸發同步: 在 sync worktree 中執行 git fetch && git merge origin/$BASE_BRANCH"
echo ""
echo "⚠️  注意: 請在 sync worktree 中進行查看和輕量級操作，避免大量修改"
echo "🔗 Hook 腳本: $GIT_HOOKS_DIR/sync_base_branch.sh"