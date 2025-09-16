#!/bin/zsh

# 腳本設定：任何指令失敗則立刻退出
set -e

# 腳本使用說明
if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ -z "$1" ]; then
    echo "用法: $0 <repo_path>"
    echo ""
    echo "  <repo_path>     : 必填，現有 Git 專案資料夾的路徑。"
    echo "  [base_branch]   : 選填，作為新分支基礎的分支。預設: develop。"
    exit 1
fi

# 參數處理
REPO_PATH="$1"
BASE_BRANCH=${2:-develop}

# 自動找到主儲存庫的路徑
MAIN_REPO_PATH=$(git -C "$REPO_PATH" rev-parse --show-toplevel)

if [ ! -d "$MAIN_REPO_PATH/.git" ]; then
    echo "錯誤: 提供的路徑不是一個有效的 Git 儲存庫。"
    exit 1
fi

echo "--- 開始建立新的工作環境 ---"
cd "$MAIN_REPO_PATH"

# 提示使用者輸入新的 feature 分支名稱
read "?請輸入新的 feature 分支名稱 (例如: Forerunner/feature/FOR-123_bugfix_test_env): " FEATURE_BRANCH_NAME
if [ -z "$FEATURE_BRANCH_NAME" ]; then
    echo "錯誤: 分支名稱不能為空。"
    exit 1
fi

# 1. 根據 feature 分支名稱推斷 worktree 路徑
SANITIZED_BRANCH_PATH_TAIL=${FEATURE_BRANCH_NAME:t}
SANITIZED_BRANCH_PATH_HEAD=${FEATURE_BRANCH_NAME:h}

FEATURE_WORKTREE_PATH="$HOME/worktrees/$SANITIZED_BRANCH_PATH_TAIL"

echo "=> 建立 worktree 的路徑名稱為: $FEATURE_WORKTREE_PATH"

# 2. 根據 feature 分支名稱推斷 deploy 分支名稱
# 從分支名稱中提取 JIRA_INFO (例如: FOR-123)
if [[ "$FEATURE_BRANCH_NAME" =~ (FOR-[0-9]+) ]]; then
    JIRA_INFO="${match[1]}"
else
    echo "錯誤: 無法從 feature branch 名稱中找到 'FOR-xxxx' 資訊。"
    exit 1
fi

# 檢查是否有超過一個 '_' 在 JIRA_INFO 之後
SUBSTRING=${FEATURE_BRANCH_NAME#*${JIRA_INFO}_}
# === 新增：將完整的 namespace 加入 deploy 分支名稱 ===
NAMESPACE="${FEATURE_BRANCH_NAME%/${JIRA_INFO}*}"
if [[ "$SUBSTRING" == *_* ]]; then
    # 提取第一個和第二個 '_' 之間的內容作為 ENV
    ENV=${SUBSTRING%%_*}
    DEPLOY_BRANCH_NAME="${NAMESPACE}/${JIRA_INFO}_deploy_${ENV}"
else
    # 如果只有一個 '_' 或沒有，則 ENV 為空
    DEPLOY_BRANCH_NAME="${NAMESPACE}/${JIRA_INFO}_deploy"
fi

echo "=> 準備建立的分支名稱為: $FEATURE_BRANCH_NAME 和 $DEPLOY_BRANCH_NAME"
echo "=> 基礎分支為: $BASE_BRANCH" # 假設基礎分支為 develop
echo ""

# 建立 worktree 資料夾
mkdir -p $(dirname "$FEATURE_WORKTREE_PATH")

# 建立 feature branch 的 worktree
git worktree add -b "$FEATURE_BRANCH_NAME" "$FEATURE_WORKTREE_PATH" "$BASE_BRANCH"
echo "✅ Feature worktree 建立於: $FEATURE_WORKTREE_PATH"

# 設定 feature branch 的 upstream
cd "$FEATURE_WORKTREE_PATH"
git branch --set-upstream-to=origin/"$BASE_BRANCH"
echo "✅ Feature branch upstream 已設定為: origin/$BASE_BRANCH"

# 建立 deploy branch 的 worktree
DEPLOY_WORKTREE_PATH="$HOME/worktrees/${DEPLOY_BRANCH_NAME:t}"
git worktree add -b "$DEPLOY_BRANCH_NAME" "$DEPLOY_WORKTREE_PATH" "$FEATURE_BRANCH_NAME"
echo "✅ Deploy worktree 建立於: $DEPLOY_WORKTREE_PATH"

# 記錄 deploy branch 與 feature branch 的關聯
cd "$DEPLOY_WORKTREE_PATH"
git config branch."$DEPLOY_BRANCH_NAME".featurebranch "$FEATURE_BRANCH_NAME"
git config branch."$DEPLOY_BRANCH_NAME".featureworktree "$FEATURE_WORKTREE_PATH"
echo "✅ Deploy branch 關聯資訊已記錄"
echo ""

# 只為 feature worktree 建立 hooks
GIT_HOOKS_DIR="$HOME/projects/conf/workflow" # 確保此路徑正確
echo "--- 正在為 worktree 建立 hooks 的 symbolic links ---"

cd "$FEATURE_WORKTREE_PATH"
mkdir -p "$(git rev-parse --git-dir)/hooks"
ln -s "$GIT_HOOKS_DIR/sync_and_trigger.sh" "$(git rev-parse --git-dir)/hooks/post-commit"
git config core.hooksPath "$(git rev-parse --git-dir)/hooks"
echo "✅ Feature worktree 的 hooks 連結已建立。"
echo ""

echo "--- 環境設定完成！ ---"
echo "您現在可以進入您的新工作目錄開始工作："
echo "cd $FEATURE_WORKTREE_PATH"
echo ""
