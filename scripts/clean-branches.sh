#!/bin/bash
# main / develop のリモート・ローカルを整理するスクリプト
# 使い方: ./scripts/clean-branches.sh

set -e
cd "$(git rev-parse --show-toplevel)"

echo "=== Fetch and prune remote ==="
git fetch origin --prune

echo ""
echo "=== Sync main ==="
git checkout main
git pull origin main

echo ""
echo "=== Sync develop ==="
git checkout develop
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "⚠️  develop に未コミットの変更があります。stash してから pull します。"
  git stash push -m "clean-branches: stash before pull"
  git pull origin develop
  echo "stash を戻すには: git stash pop"
else
  git pull origin develop
fi

echo ""
echo "=== Done. Current branches ==="
git branch -a
