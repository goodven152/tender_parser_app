#!/usr/bin/env bash
# файл: deploy_parser.sh
# размещайте в корне tender_parser_app
# chmod +x deploy_parser.sh  &&  ./deploy_parser.sh

set -Eeuo pipefail            # строгий режим bash
IFS=$'\n\t'

PROJECT_ROOT="$(dirname "$(readlink -f "$0")")"
cd "$PROJECT_ROOT"

echo "🛈  Pulling latest changes from GitHub..."
git pull --ff-only

echo "🛈  Building updated Docker images..."
# если фронт не меняете, уберите его из списка
docker compose build backend frontend

echo "🛈  Restarting containers..."
docker compose up -d          # поднимет с обновлёнными образами

echo "🛈  Removing dangling images to save space..."
docker image prune -f --filter "dangling=true"

echo "✅  Deployment finished. Check the admin panel 🎉"
