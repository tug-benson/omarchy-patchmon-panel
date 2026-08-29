#!/usr/bin/env bash
# PatchMon fleet fetcher for the Omarchy PatchMon Panel plugin.
# Talks to the PatchMon Integration API (/api/v1/api/hosts?include=stats)
# and prints the raw JSON to stdout. Credentials are passed as arguments
# (a list, so no shell splitting) or via environment variables.
set -uo pipefail

URL="${PATCHMON_URL:-${1:-}}"
KEY="${PATCHMON_KEY:-${2:-}}"
SECRET="${PATCHMON_SECRET:-${3:-}}"
GROUP="${PATCHMON_GROUP:-${4:-}}"
INSECURE="${PATCHMON_INSECURE:-${5:-0}}"

if [ -z "$URL" ] || [ -z "$KEY" ] || [ -z "$SECRET" ]; then
  echo '{"error":"not-configured"}'
  exit 0
fi

AUTH=$(printf '%s:%s' "$KEY" "$SECRET" | base64 | tr -d '\n')

REQ="$URL/api/v1/api/hosts?include=stats"
if [ -n "$GROUP" ]; then
  ESC=$(printf '%s' "$GROUP" | python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.stdin.read()))' 2>/dev/null || printf '%s' "$GROUP")
  REQ="$REQ&hostgroup=$ESC"
fi

if [ "$INSECURE" = "1" ]; then
  INSECURE_FLAG="--insecure"
else
  INSECURE_FLAG=""
fi

HTTP_BODY=$(curl -fsS $INSECURE_FLAG -m 20 -H "Authorization: Basic $AUTH" "$REQ" 2>/dev/null)
RC=$?

if [ $RC -ne 0 ] || [ -z "$HTTP_BODY" ]; then
  echo "{\"error\":\"fetch-failed\",\"httpStatus\":$RC}"
  exit 0
fi

printf '%s' "$HTTP_BODY"
