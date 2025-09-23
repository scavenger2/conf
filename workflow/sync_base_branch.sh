#!/bin/zsh

# 腳本設定：任何指令失敗則立刻退出
set -e

# 獲取當前分支名稱
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# 檢查是否為 sync branch
if [[ "$CURRENT_BRANCH" != sync-* ]]; then
    echo "此 hook 僅在 sync branch 中執行"
    exit 0
fi

echo "--- 自動同步 base branch 到 $CURRENT_BRANCH ---"

# 獲取關聯的 base branch
BASE_BRANCH=$(git config branch."$CURRENT_BRANCH".basebranch || echo "")

if [ -z "$BASE_BRANCH" ]; then
    echo "錯誤: 無法找到關聯的 base branch"
    exit 1
fi

echo "=> 同步來源: $BASE_BRANCH"

# 檢查是否有未提交的變更
if ! git diff-index --quiet HEAD 2>/dev/null; then
    echo "⚠️ 有未提交的變更，跳過自動同步"
    exit 0
fi

# 檢查是否有 staged 變更
if ! git diff-index --quiet --cached HEAD 2>/dev/null; then
    echo "⚠️ 有已暫存的變更，跳過自動同步"
    exit 0
fi

# Fetch 最新的變更
echo "📡 正在 fetch 最新變更..."
git fetch origin

# 檢查 base branch 是否有新的 commit
LOCAL_BASE=$(git rev-parse "origin/$BASE_BRANCH" 2>/dev/null || echo "")
if [ -z "$LOCAL_BASE" ]; then
    echo "⚠️ 無法找到遠端分支 origin/$BASE_BRANCH"
    exit 0
fi

CURRENT_HEAD=$(git rev-parse HEAD)
MERGE_BASE=$(git merge-base HEAD "origin/$BASE_BRANCH" 2>/dev/null || echo "")

if [ "$LOCAL_BASE" = "$MERGE_BASE" ]; then
    echo "✅ $BASE_BRANCH 沒有新的變更，無需同步"
    exit 0
fi

# 將 base branch 的變更 merge 進來
echo "🔀 正在 merge origin/$BASE_BRANCH 的最新變更..."
if git merge "origin/$BASE_BRANCH" --no-edit --no-ff; then
    echo "✅ 同步完成"
    echo "📊 最新 commit: $(git log --oneline -1)"
else
    echo "❌ 同步失敗，可能有衝突需要手動解決"
    exit 1
fi