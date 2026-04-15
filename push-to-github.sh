#!/usr/bin/env bash
set -euo pipefail

DIR="${1:-/workspace/project}"
BRANCH="main"

if [[ ! -d "$DIR" ]]; then
  echo "❌ $DIR не найдена"
  exit 1
fi

read -rp "👤 GitHub юзернейм: " GH_USER
read -rsp "🔑 GitHub токен/пароль: " GH_PASS
echo
read -rp "📁 Имя репозитория: " REPO_NAME

REMOTE="https://${GH_USER}:${GH_PASS}@github.com/${GH_USER}/${REPO_NAME}.git"

cd "$DIR"

# --- git-lfs если нет ---
if ! command -v git-lfs &>/dev/null; then
  echo "📦 Ставлю git-lfs..."
  sudo apt-get update -qq && sudo apt-get install -y git-lfs
fi

# --- создаю приватный репо через API ---
echo "🔒 Создаю приватный репо $GH_USER/$REPO_NAME..."
curl -sf -X POST https://api.github.com/user/repos \
  -u "${GH_USER}:${GH_PASS}" \
  -H "Accept: application/vnd.github+json" \
  -d "{\"name\":\"${REPO_NAME}\",\"private\":true}" >/dev/null 2>&1 || echo "   (репо уже существует)"

# --- init если нет .git ---
if [[ ! -d .git ]]; then
  git init
  git branch -M "$BRANCH"
fi

git lfs install

# --- remote ---
if git remote get-url origin &>/dev/null; then
  git remote set-url origin "$REMOTE"
else
  git remote add origin "$REMOTE"
fi

# --- lfs для больших файлов ---
find . -not -path './.git/*' -type f -size +100M -print0 | while IFS= read -r -d '' f; do
  git lfs track "$f"
  echo "   📎 LFS: $f"
done

# --- коммит и пуш ---
git add -A
git diff --cached --quiet && echo "✅ Нечего коммитить" && exit 0
git commit -m "$(date +'%d.%m.%Y %H:%M')"

echo "🚀 Пушу..."
git push -u origin "$BRANCH" --force

echo "✅ Готово! → https://github.com/$GH_USER/$REPO_NAME"
