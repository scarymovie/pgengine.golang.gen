#!/usr/bin/env bash
# E2E: run this repository's Go generator through the real pGenie CLI (pgn)
# against the official pgenie-io/demo project, then compile the artifact and
# run queries against the migrated database.
#
# Requirements: docker, go, git. Everything else runs in containers.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PG_PORT="${PG_PORT:-5498}"
PG_CONTAINER="pgn-e2e-pg"
WORK="$(mktemp -d /tmp/pgn-e2e.XXXXXX)"

cleanup() {
  docker rm -f "$PG_CONTAINER" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "==> Building pgn image"
docker build -q -t pgn-cli -f "$REPO_DIR/e2e/pgn.Dockerfile" "$REPO_DIR/e2e"

echo "==> Cloning pgenie-io/demo"
git clone -q --depth 1 https://github.com/pgenie-io/demo "$WORK/demo"
rm -rf "$WORK/demo/artifacts" "$WORK/demo/freeze1.pgn.yaml" \
       "$WORK/demo/types" "$WORK/demo"/queries/*.sig1.pgn.yaml
cp "$REPO_DIR/e2e/project1.pgn.yaml" "$WORK/demo/project1.pgn.yaml"

echo "==> Starting PostgreSQL 18"
docker rm -f "$PG_CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$PG_CONTAINER" -e POSTGRES_PASSWORD=pw \
  -p "$PG_PORT:5432" postgres:18 >/dev/null
until docker exec "$PG_CONTAINER" pg_isready -q 2>/dev/null; do sleep 1; done

echo "==> Running pgn generate"
docker run --rm --network host \
  -v "$WORK/demo:/project" \
  -v "$REPO_DIR:/gen-src:ro" \
  pgn-cli --database-url "postgresql://postgres:pw@127.0.0.1:$PG_PORT/postgres" generate

echo "==> Compiling the artifact"
mkdir -p "$WORK/check"
# pgn runs as root in its container; copy the artifact into a writable dir.
docker run --rm -v "$WORK:/w" debian:trixie-slim \
  sh -c "cp -r /w/demo/artifacts/go/. /w/check/ && chmod -R a+rwX /w/check /w/demo"
cd "$WORK/check"
go mod tidy >/dev/null
go vet ./...

echo "==> Running queries against the database"
docker exec "$PG_CONTAINER" psql -U postgres -q -c "create database e2e" >/dev/null
for f in "$WORK"/demo/migrations/*.sql; do
  docker exec -i "$PG_CONTAINER" psql -U postgres -d e2e -v ON_ERROR_STOP=1 -q < "$f"
done
cp "$REPO_DIR/e2e/testdata/artifact_test.go" .
PGN_E2E_DSN="postgres://postgres:pw@127.0.0.1:$PG_PORT/e2e" go test -count=1 .

echo "==> E2E OK"
