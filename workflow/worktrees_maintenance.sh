#!/bin/zsh

# 腳本設定：任何指令失敗則立刻退出
set -e

# 設定 worktree 資料夾路徑
WORKTREES_DIR="$HOME/worktrees"

echo "--- [第一部分] 開始同步所有 Git 工作目錄 ---"

# 尋找所有 worktree 所屬的主儲存庫
declare -a unique_repos
declare -A worktree_parent_map

echo "-> 正在識別所有 worktree 的父儲存庫..."
for worktree_dir in "$WORKTREES_DIR"/*/; do
    if [ -d "$worktree_dir/.git" ]; then
        worktree_path=$(realpath "$worktree_dir")
        main_repo_path=$(git -C "$worktree_path" rev-parse --show-toplevel)

        if [ -n "$main_repo_path" ]; then
            worktree_parent_map["$worktree_path"]="$main_repo_path"
            is_unique=1
            for existing_repo in "${unique_repos[@]}"; do
                if [ "$existing_repo" = "$main_repo_path" ]; then
                    is_unique=0
                    break
                fi
            done
            if [ "$is_unique" -eq 1 ]; then
                unique_repos+=("$main_repo_path")
            fi
        fi
    fi
done

# 更新所有唯一的主儲存庫的 develop 分支
if [ ${#unique_repos[@]} -gt 0 ]; then
    echo "-> 正在更新各個主儲存庫的 develop 分支..."
    for repo in "${unique_repos[@]}"; do
        echo "  處理儲存庫: $(basename "$repo")..."
        cd "$repo"
        git pull origin develop
    done
else
    echo "警告: 沒有找到有效的 Git worktree。"
fi

echo "-> 遍歷並同步所有 worktree..."
for worktree_dir in "$WORKTREES_DIR"/*/; do
    if [ -d "$worktree_dir/.git" ]; then
        echo "  處理: $(basename "$worktree_dir")..."

        cd "$worktree_dir"

        if [ -n "$(git status --porcelain)" ]; then
            echo "  警告: $(basename "$worktree_dir") 有未提交的修改，跳過更新。"
            continue
        fi

        git fetch origin develop
        git rebase origin/develop

        echo "  更新完成。"
        echo ""
    fi
done

echo "--- [第一部分] 所有工作目錄已同步完成！ ---"

echo "--- [第二部分] 清理舊的已合併分支提醒 ---"
for repo in "${unique_repos[@]}"; do
    echo "-> 正在檢查儲存庫 $(basename "$repo") 的分支..."
    cd "$repo"
    git branch --merged develop | grep -v 'develop$' | while read -r branch; do
        branch_name=$(echo "$branch" | xargs)
        last_commit_date=$(git log "$branch_name" -1 --format=%cd --date=raw)
        current_date=$(date +%s)

        if [ $((current_date - last_commit_date)) -gt 604800 ]; then
            echo "   - 提醒: 儲存庫 $(basename "$repo") 的分支 '$branch_name' 已合併且超過一週未使用。"
            echo "     考慮使用 'git branch -d $branch_name' 刪除。"
        fi
    done
done

echo "--- [第二部分] 清理檢查完成。 ---"

echo "腳本執行完畢。"
