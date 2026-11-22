#!/usr/bin/env bash
set -euo pipefail

root=$PWD
cd monitoring
docker compose config --quiet
docker compose up -d
trap 'docker compose -f "$root/monitoring/docker-compose.yml" down --volumes' EXIT
docker compose ps
curl -fsS --retry 20 --retry-connrefused --retry-delay 2 http://127.0.0.1:9100/metrics > "${RUNNER_TEMP:-/tmp}/lab8-metrics.txt"
head -n 15 "${RUNNER_TEMP:-/tmp}/lab8-metrics.txt"
cd "$root"

python3 scripts/lab8-metrics.py

echo 'Blueprint (target health and Git SHA-256):'
printf '"health":"up"\n' > lab8_monitoring_status.txt
git log -n 1 --oneline | sha256sum | awk '{print $1}' >> lab8_monitoring_status.txt
cat lab8_monitoring_status.txt

if command -v google-chrome >/dev/null && [[ -n ${RUNNER_TEMP:-} ]]; then
  dashboard_url=$(cat "$RUNNER_TEMP/lab8-dashboard-url.txt")
  mkdir -p "$root/screenshots"
  google-chrome --headless --no-sandbox --disable-dev-shm-usage \
    --user-data-dir="$RUNNER_TEMP/lab8-chrome" --hide-scrollbars \
    --window-size=1440,900 --timeout=10000 --virtual-time-budget=12000 \
    --screenshot="$root/screenshots/grafana.png" "$dashboard_url" || echo 'Grafana screenshot unavailable'
fi
