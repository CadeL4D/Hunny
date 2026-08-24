#!/usr/bin/env bash
# Quick Directus API debugging helper for Hunny.
#
# Reads DIRECTUS_URL and DIRECTUS_TOKEN from .env.local (gitignored —
# copy .env.example to .env.local if it doesn't exist yet).
#
# Usage:
#   scripts/api.sh ping
#   scripts/api.sh get items/players?fields=id,name
#   scripts/api.sh post items/players -d '{"name":"Test"}'
#   scripts/api.sh patch items/answers/1 -d '{"body":"new text"}'
#   scripts/api.sh delete items/players/7
#
# Any extra args are passed straight to curl (-d, -H, -i, ...).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env.local ]; then
    echo "Missing .env.local — copy .env.example to .env.local and fill it in." >&2
    exit 1
fi
# shellcheck disable=SC1091
source .env.local

if [ "${1:-}" = "ping" ]; then
    set -- GET server/ping
fi

method=$(echo "${1:-GET}" | tr '[:lower:]' '[:upper:]')
path="${2:-server/ping}"
[ $# -gt 0 ] && shift
[ $# -gt 0 ] && shift

url="${DIRECTUS_URL%/}/$path"
case "$url" in
    http://*|https://*) ;;
    *) url="https://$url" ;;
esac

exec curl -sS -w '\nHTTP %{http_code}\n' -X "$method" "$url" \
    -H "Authorization: Bearer ${DIRECTUS_TOKEN}" \
    -H "Content-Type: application/json" \
    "$@"
