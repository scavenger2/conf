#!/bin/zsh

# 腳本設定：任何指令失敗則立刻退出
set -e

# 腳本使用說明
if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ -z "$1" ]; then
    echo "用法: $0 <repo_path> [base_branch] [deploy_branch_suffix]"
    echo ""
    echo "  <repo_path>             : 必填，現有 Git 專案資料夾的路徑。"
    echo "  [base_branch]           : 選填，作為新分支基礎的分支。預設: develop。"
    echo "  [deploy_branch_suffix]  : 選填，用於 deploy 分支名稱的後綴。預設: (空字串)。"
    exit 1
fi

# 參數處理
REPO_PATH="$1"
BASE_BRANCH=${2:-develop}
DEPLOY_BRANCH_SUFFIX=${3:-}

# 自動找到主儲存庫的路徑
MAIN_REPO_PATH=$(git -C "$REPO_PATH" rev-parse --show-toplevel)

if [ ! -d "$MAIN_REPO_PATH/.git" ]; then
    echo "錯誤: 提供的路徑不是一個有效的 Git 儲存庫。"
    exit 1
fi

echo "--- 開始建立新的工作環境 ---"
cd "$MAIN_REPO_PATH"

# 提示使用者輸入新的 feature 分支名稱
read "?請輸入新的 feature 分支名稱 (例如: Forerunner/feature/FOR-123-bugfix): " FEATURE_BRANCH_NAME
if [ -z "$FEATURE_BRANCH_NAME" ]; then
    echo "錯誤: 分支名稱不能為空。"
    exit 1
fi

# 1. 取得 feature branch 的最後一個部分，作為 worktree 路徑
SANITIZED_BRANCH_NAME=$(basename "$FEATURE_BRANCH_NAME")
echo "=> 建立 worktree 的路徑名稱為: $SANITIZED_BRANCH_NAME"

# 2. 處理 deploy branch 名稱的邏輯
if [[ "$FEATURE_BRANCH_NAME" =~ (FOR-[0-9]+) ]]; then
    JIRA_INFO="${match[1]}"
else
    echo "警告: 無法從 feature branch 名稱中找到 'FOR-xxxx' 資訊。"
    JIRA_INFO=""
fi

DEPLOY_PARTS=("deploy")
if [ -n "$DEPLOY_BRANCH_SUFFIX" ]; then
    DEPLOY_PARTS+=("$DEPLOY_BRANCH_SUFFIX")
fi

DEPLOY_SUFFIX=$(printf -- '-%s' "${DEPLOY_PARTS[@]}")
DEPLOY_SUFFIX=${DEPLOY_SUFFIX#-}

DEPLOY_BRANCH_NAME="${JIRA_INFO}_${DEPLOY_SUFFIX}"

echo "=> 準備建立的分支名稱為: $FEATURE_BRANCH_NAME 和 $DEPLOY_BRANCH_NAME"
echo "=> 基礎分支為: $BASE_BRANCH"
echo ""

# 建立 worktree 資料夾
WORKTREES_DIR="$HOME/worktrees"
mkdir -p "$WORKTREES_DIR"

# 建立 feature branch 的 worktree
FEATURE_WORKTREE_PATH="$WORKTREES_DIR/$SANITIZED_BRANCH_NAME"
git worktree add -b "$FEATURE_BRANCH_NAME" "$FEATURE_WORKTREE_PATH" "$BASE_BRANCH"
echo "✅ Feature worktree 建立於: $FEATURE_WORKTREE_PATH"

# 建立 deploy branch 的 worktree
DEPLOY_WORKTREE_PATH="$WORKTREES_DIR/$DEPLOY_BRANCH_NAME"
git worktree add -b "${FEATURE_BRANCH_NAME:h}/$DEPLOY_BRANCH_NAME" "$DEPLOY_WORKTREE_PATH" "$BASE_BRANCH"
echo "✅ Deploy worktree 建立於: $DEPLOY_WORKTREE_PATH"
echo ""

# 設定 Git hooks
echo "--- 正在為 worktree 建立 hooks 的 symbolic links ---"
GIT_HOOKS_DIR="$MAIN_REPO_PATH/githooks"

# === 修正部分：正確處理 worktree 的 hooks 資料夾 ===
# 為 feature worktree 建立 hooks (只需要 post-commit)
cd "$FEATURE_WORKTREE_PATH"
# git rev-parse --git-common-dir
mkdir -p $(git rev-parse --git-common-dir)/hooks # 修正後的指令
ln -s "$GIT_HOOKS_DIR/post-commit" $(git rev-parse --git-common-dir)/hooks/post-commit
echo "✅ Feature worktree 的 hooks 連結已建立。"

# === 修正部分結束 ===

# === 修正部分：移除多餘的 deploy branch hook 設定 ===
echo "✅ Deploy worktree 的 hooks 連結已建立。"
echo ""
# === 修正部分結束 ===

echo "--- 環境設定完成！ ---"
echo "您現在可以進入您的新工作目錄開始工作："
echo "cd $FEATURE_WORKTREE_PATH"
echo ""
