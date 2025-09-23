# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains a Git workflow automation system written in Zsh that manages feature development environments using Git worktrees. The system automates the creation, synchronization, and cleanup of feature branches and their corresponding deployment branches.

## Architecture

The workflow system consists of four main shell scripts that work together:

1. **create_feature_env.sh** - Creates new feature development environments
2. **sync_and_trigger.sh** - Synchronizes feature branches to deploy branches and triggers CI/CD (used as a Git hook)
3. **finalize_feature_env.sh** - Cleans up feature environments when development is complete
4. **worktrees_maintenance.sh** - Maintains all worktrees by syncing with develop branch

### Core Concepts

- **Feature Branches**: Development branches following the pattern `Namespace/FOR-XXX_description_env`
- **Deploy Branches**: Automatically generated deployment branches with pattern `Namespace/FOR-XXX_deploy[_env]`
- **Worktrees**: Separate working directories for each branch, stored in `$HOME/worktrees/`
- **JIRA Integration**: Branches must contain JIRA ticket numbers in format `FOR-XXX`

### Branch Naming Convention

The system expects feature branches to follow this pattern:
```
Namespace/FOR-XXX_description[_environment]
```

Examples:
- `Forerunner/feature/FOR-123_bugfix_test_env` → `Forerunner/FOR-123_deploy_test`
- `Backend/FOR-456_api_update` → `Backend/FOR-456_deploy`

## Common Commands

### Create New Feature Environment
```bash
./create_feature_env.sh <repo_path> [base_branch]
```
- `repo_path`: Path to existing Git repository
- `base_branch`: Base branch for new feature (default: develop)

### Clean Up Feature Environment
```bash
./finalize_feature_env.sh <feature_branch_name>
```
- Removes both feature and deploy worktrees
- Deletes remote branches
- Cleans up local references

### Maintain All Worktrees
```bash
./worktrees_maintenance.sh
```
- Updates develop branch in all repositories
- Rebases all feature branches onto latest develop
- Reports old merged branches for cleanup

### Manual Sync (if needed)
```bash
./sync_and_trigger.sh
```
- Synchronizes current feature branch to its deploy branch
- Triggers CI/CD pipeline
- Updates local deploy branch

## Workflow Process

1. **Setup**: Run `create_feature_env.sh` to create feature and deploy worktrees
2. **Development**: Work in the feature worktree; commits automatically sync to deploy branch via post-commit hook
3. **Maintenance**: Periodically run `worktrees_maintenance.sh` to keep branches updated
4. **Cleanup**: Run `finalize_feature_env.sh` when feature is complete

## Git Hooks Integration

The system automatically creates a post-commit hook that runs `sync_and_trigger.sh` to ensure deploy branches stay synchronized with feature development.

## Requirements

- Zsh shell
- Git with worktree support
- Repository structure with develop branch as main development branch
- JIRA ticket numbers in branch names for proper automation
- 這裡有多個script檔案，每個都有各自的用途，在不理解它們的定位前不推薦修改它們，但目前它們都不是完成的版本，所以最終還是需要修改它們的；以create_feature_env.sh來說，我會用它來從第一個參數-repo的位址，來建立兩個worktree(因為我習慣的GUI工具不支援Git Worktree)，一個worktree是for feature branch，另一個則是for deploy branch。以feature branch來說，它會是從repo的develop branch為基底(可以在使用過程中指定不同的branch)的local branch，暫時先不具備git push的能力，基本上功能的實作會先做在這個地方；deploy branch會是以feature branch為基底、同時有local branch並且有相對應的remote upstream，所以在feature branch有更新時它能夠簡易地merge來自feature branch的commit、也能在deploy branch本身的修改(通常會是一些不希望上到develop的test code)完成後上到遠端的真實環境來觸發CI/CD(feature branch暫時不能git push的原因就是不想要和deploy branch一起觸發CI/CD)；其他的一些細節例如feature branch的name rule已經在create_feature_env.sh中實現了，主要是一些git上的naming rule，你可以先就目前的版本確認create_feature_sh.env的行為、並整理一份簡報給我
- worktrees_maintenance.sh這支script的目標是提供一個無需參數、讓每個worktree資料夾都能和它們各自的base branch做好sync的簡易腳本
- 如果我寫feature worktree path就表示我要說的是feature branch的worktree資料夾位址；同理deploy worktree path就是deploy branch的worktree資料夾位址
- sync_and_trigger.sh這個腳本是用來設定成feature branch的post-commit git hook，我記得在create_feature_env.sh中已經完成了這個設定，當初遇到的難點是"worktree資料夾下只有.git檔案、沒有.git資料夾，所以要回到repo底下做設定"
- sync_and_trigger.sh的設計理念是"feature branch如果有在local commit新的內容、應該會觸發相對應的deploy branch馬上將新的內容merge進去"
- finalize_feature_env.sh的使用時機是deploy branch在透過CI/CD佈署到真實環境後、人為判斷功能已經實作完成後，會使用這個腳本將deploy branch從本地和遠端刪除，並且替feature branch設定好正確的upstream(和本地的branch一致即可、需要包含當初在create_feature_env.sh輸入的完整Namespace)方便它git push觸發CI/CD，之後若還有功能上的commit就視為fix
- create_sync_env.sh的使用情境是使用者可以指定一個repo的位置、並且指定一個既有的branch(通常會是develop、如果不指定的話就會以develop為預設值)作為worktree的base branch，然後在~/worktrees資料夾下建立一個追蹤base branch的worktree；需要在base branch有任何更新的時候也反應在這個用於追蹤的worktree上(或許是透過git hook觸發)
- deploy branch會有自己的修改、大致上都是一些test code而已，不會影響merge來自feature branch的commit