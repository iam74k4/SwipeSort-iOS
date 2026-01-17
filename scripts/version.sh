#!/bin/bash

# Gitタグベースのバージョン自動管理スクリプト
# mainブランチ: タグのバージョンをそのまま使用
# developブランチ: タグの次のパッチバージョンを使用

# エラー時もビルドを続行するため、set -e は使用しない

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_FILE="$PROJECT_ROOT/SwipeSort.xcodeproj/project.pbxproj"

# CI/CD環境の判定
IS_CI=false
if [ -n "$CI" ] || [ -n "$GITHUB_REF" ]; then
    IS_CI=true
fi

# デフォルト値
DEFAULT_MARKETING_VERSION="0.0.1"
DEFAULT_CURRENT_PROJECT_VERSION="1"

# ブランチ判定
get_current_branch() {
    # CI/CD環境: GITHUB_REFを優先
    if [ -n "$GITHUB_REF" ]; then
        # refs/heads/main -> main
        # refs/heads/develop -> develop
        # refs/pull/123/merge -> GITHUB_HEAD_REFを使用
        if [[ "$GITHUB_REF" == refs/heads/* ]]; then
            echo "${GITHUB_REF#refs/heads/}"
        elif [ -n "$GITHUB_HEAD_REF" ]; then
            echo "$GITHUB_HEAD_REF"
        else
            echo "main"
        fi
    # ローカル環境: git branch --show-current
    elif command -v git >/dev/null 2>&1 && [ -d "$PROJECT_ROOT/.git" ]; then
        git branch --show-current 2>/dev/null || echo "main"
    else
        echo "main"
    fi
}

# 最新タグを取得
get_latest_tag() {
    if ! command -v git >/dev/null 2>&1 || [ ! -d "$PROJECT_ROOT/.git" ]; then
        return 1
    fi
    
    cd "$PROJECT_ROOT"
    # まず、現在のブランチから見える最新タグを取得
    local tag=$(git describe --tags --abbrev=0 2>/dev/null)
    if [ -n "$tag" ]; then
        echo "$tag"
        return 0
    fi
    
    # タグが見つからない場合、すべてのタグから最新を取得
    tag=$(git tag -l "v*" | sort -V | tail -1 2>/dev/null)
    if [ -n "$tag" ]; then
        echo "$tag"
        return 0
    fi
    
    return 1
}

# バージョンをパース（v1.0.0 -> 1.0.0）
parse_version() {
    local tag="$1"
    # vプレフィックスを除去、プレリリース部分を除去
    echo "$tag" | sed -E 's/^v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/'
}

# バージョンをインクリメント（1.0.0 -> 1.0.1）
increment_patch_version() {
    local version="$1"
    local major minor patch
    
    IFS='.' read -r major minor patch <<< "$version"
    patch=$((patch + 1))
    echo "$major.$minor.$patch"
}

# コミット数を取得
get_commit_count() {
    local tag="$1"
    
    if ! command -v git >/dev/null 2>&1 || [ ! -d "$PROJECT_ROOT/.git" ]; then
        echo "$DEFAULT_CURRENT_PROJECT_VERSION"
        return
    fi
    
    cd "$PROJECT_ROOT"
    
    if [ -n "$tag" ]; then
        # タグからのコミット数
        git rev-list --count "$tag"..HEAD 2>/dev/null || echo "$DEFAULT_CURRENT_PROJECT_VERSION"
    else
        # 全コミット数
        git rev-list --count HEAD 2>/dev/null || echo "$DEFAULT_CURRENT_PROJECT_VERSION"
    fi
}

# project.pbxprojを更新
update_project_file() {
    local marketing_version="$1"
    local current_project_version="$2"
    local backup_file="${PROJECT_FILE}.bak"
    
    if [ ! -f "$PROJECT_FILE" ]; then
        echo "Warning: project.pbxproj not found at $PROJECT_FILE"
        return 1
    fi
    
    # バックアップを作成
    cp "$PROJECT_FILE" "$backup_file" 2>/dev/null || true
    
    # Debug/Release両方の設定を更新
    # MARKETING_VERSION = 0.0.1; を MARKETING_VERSION = 1.0.0; に置換
    # macOSとLinuxの両方に対応
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = ${marketing_version};/g" "$PROJECT_FILE" 2>/dev/null || {
            echo "Warning: Failed to update MARKETING_VERSION"
            mv "$backup_file" "$PROJECT_FILE" 2>/dev/null || true
            return 1
        }
        sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = ${current_project_version};/g" "$PROJECT_FILE" 2>/dev/null || {
            echo "Warning: Failed to update CURRENT_PROJECT_VERSION"
            mv "$backup_file" "$PROJECT_FILE" 2>/dev/null || true
            return 1
        }
    else
        # Linux
        sed -i "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = ${marketing_version};/g" "$PROJECT_FILE" 2>/dev/null || {
            echo "Warning: Failed to update MARKETING_VERSION"
            mv "$backup_file" "$PROJECT_FILE" 2>/dev/null || true
            return 1
        }
        sed -i "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = ${current_project_version};/g" "$PROJECT_FILE" 2>/dev/null || {
            echo "Warning: Failed to update CURRENT_PROJECT_VERSION"
            mv "$backup_file" "$PROJECT_FILE" 2>/dev/null || true
            return 1
        }
    fi
    
    # バックアップを削除（成功時）
    rm "$backup_file" 2>/dev/null || true
    
    echo "Updated project.pbxproj: MARKETING_VERSION=$marketing_version, CURRENT_PROJECT_VERSION=$current_project_version"
}

# メイン処理
main() {
    local branch
    local latest_tag
    local base_version
    local marketing_version
    local current_project_version
    
    # ブランチを取得
    branch=$(get_current_branch)
    
    # 最新タグを取得
    if latest_tag=$(get_latest_tag); then
        base_version=$(parse_version "$latest_tag")
        
        # ブランチに応じてバージョンを決定
        if [ "$branch" = "develop" ]; then
            marketing_version=$(increment_patch_version "$base_version")
        else
            marketing_version="$base_version"
        fi
        
        # ビルド番号を取得（タグからのコミット数）
        current_project_version=$(get_commit_count "$latest_tag")
    else
        # タグがない場合
        if [ "$branch" = "develop" ]; then
            marketing_version="0.0.2"
        else
            marketing_version="$DEFAULT_MARKETING_VERSION"
        fi
        current_project_version=$(get_commit_count "")
    fi
    
    # 環境変数で上書き可能
    if [ -n "$OVERRIDE_MARKETING_VERSION" ]; then
        marketing_version="$OVERRIDE_MARKETING_VERSION"
    fi
    if [ -n "$OVERRIDE_CURRENT_PROJECT_VERSION" ]; then
        current_project_version="$OVERRIDE_CURRENT_PROJECT_VERSION"
    fi
    
    # 環境変数をエクスポート（CI/CD用）
    export MARKETING_VERSION="$marketing_version"
    export CURRENT_PROJECT_VERSION="$current_project_version"
    
    # CI/CD環境の場合はproject.pbxprojを更新しない
    if [ "$IS_CI" = true ]; then
        echo "CI/CD environment detected. Version: $marketing_version, Build: $current_project_version"
        return 0
    fi
    
    # ローカル環境: project.pbxprojを更新
    if [ -f "$PROJECT_FILE" ]; then
        update_project_file "$marketing_version" "$current_project_version" || {
            echo "Warning: Failed to update project.pbxproj, using default values"
        }
    else
        echo "Warning: project.pbxproj not found, skipping update"
    fi
}

# スクリプト実行
main "$@"
