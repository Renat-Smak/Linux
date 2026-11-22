#!/usr/bin/env bash
set -euo pipefail

image=my-web-app:v1
container=web_server_instance

echo '$ docker build -t my-web-app:v1 .'
docker build -t "$image" .
if [[ -n ${GITHUB_SHA:-} ]]; then docker tag "$image" "my-app:$GITHUB_SHA"; fi
echo '$ docker images my-web-app'
docker image ls "$image"
docker inspect --format='{{.Id}}' "$image" > lab6_docker_hash.txt

docker run -d -p 127.0.0.1:8080:8080 --name "$container" "$image"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT
echo '$ curl http://localhost:8080'
curl --fail --silent --show-error --retry 8 --retry-connrefused --retry-delay 1 \
  -w 'HTTP %{http_code}\n' http://127.0.0.1:8080/
docker stop "$container"
docker rm "$container"

git log -n 3 --oneline | sha256sum | awk '{print $1}' > lab6_final_hash.txt
printf 'Docker image ID: '; cat lab6_docker_hash.txt
printf 'Git history SHA-256: '; cat lab6_final_hash.txt
