#!/usr/bin/env bash
# Smoke test: start the image with the sample app and check that nginx serves
# static files and that PHP requests are handled by php-fpm.
set -euo pipefail

IMAGE="${1:?usage: $0 <image>}"
NAME="php-container-smoke-$$"
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)/app"

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

fail() {
    echo "FAIL: $*"
    echo "--- container logs ---"
    docker logs "$NAME" 2>&1 | tail -50
    exit 1
}

docker run -d --name "$NAME" "$IMAGE" >/dev/null
# Copy instead of bind-mounting so this also works when Docker runs on another host
docker cp "$APP_DIR" "$NAME:/var/www/app"

# Wait for nginx and php-fpm to come up
for _ in $(seq 1 30); do
    docker exec "$NAME" curl -fsS -o /dev/null http://127.0.0.1/api 2>/dev/null && break
    sleep 1
done

check() {
    local path="$1" expected="$2" body
    body=$(docker exec "$NAME" curl -fsS "http://127.0.0.1$path") || fail "GET $path did not return 2xx"
    grep -q "$expected" <<<"$body" || fail "GET $path: expected '$expected', got: $body"
    echo "OK: GET $path"
}

check /           "Hello world"
check /hello.htm  "Also hello world"
check /api        "PHP: hello world"

echo "Smoke test passed"
