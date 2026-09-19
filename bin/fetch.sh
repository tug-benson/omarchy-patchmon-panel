#!/usr/bin/env bash
# Secure PatchMon fetcher.
# Reads a single-line JSON object from stdin:
#   {"serverUrl":"https://...","apiKey":"...","apiSecret":"...","hostGroup":"..."}
# Never takes secrets via argv; the Authorization header is written to a
# 0600 --config file (umask 077 + mktemp + chmod 600) and never appears in
# /proc/*/cmdline. Response size is capped producer-side.
set -uo pipefail
umask 077

# --- read config (one line JSON) ---
IFS= read -r config || true
if [ -z "$config" ]; then
  printf '{"error":"missing-config"}\n'
  exit 0
fi
if [ ${#config} -gt 8192 ]; then
  printf '{"error":"config-too-large"}\n'
  exit 0
fi

# --- parse JSON securely via python3 (one invocation) ---
eval "$(CONFIG="$config" python3 - <<'PY'
import json, os, shlex, sys
try:
    data = json.loads(os.environ["CONFIG"])
except Exception:
    # signal bad-config via shell
    print('_bad_config=1')
    sys.exit(0)
def cap(s, n):
    if s is None:
        return ""
    s = str(s)
    return s[:n]
# caps match QML producer caps
serverUrl = cap(data.get("serverUrl", ""), 2048)
apiKey    = cap(data.get("apiKey", ""), 1024)
apiSecret = cap(data.get("apiSecret", ""), 2048)
hostGroup = cap(data.get("hostGroup", ""), 200)
# shlex.quote for safe eval
print(f"serverUrl={shlex.quote(serverUrl)}")
print(f"apiKey={shlex.quote(apiKey)}")
print(f"apiSecret={shlex.quote(apiSecret)}")
print(f"hostGroup={shlex.quote(hostGroup)}")
# flag for bad json already handled
PY
)"
if [ "${_bad_config:-0}" = "1" ]; then
  printf '{"error":"bad-config"}\n'
  exit 0
fi

if [ -z "${serverUrl:-}" ] || [ -z "${apiKey:-}" ] || [ -z "${apiSecret:-}" ]; then
  printf '{"error":"not-configured"}\n'
  exit 0
fi

# --- validate URL scheme: only https:// allowed ---
case "$serverUrl" in
  https://*)
    ;;
  *)
    printf '{"error":"invalid-url-scheme"}\n'
    exit 0
    ;;
esac
# also reject whitespace/control chars
if printf "%s" "$serverUrl" | grep -q '[[:space:]]'; then
  printf '{"error":"invalid-url-scheme"}\n'
  exit 0
fi

# --- build request URL ---
REQ="$serverUrl/api/v1/api/hosts?include=stats"
if [ -n "${hostGroup:-}" ]; then
  ESC=$(printf "%s" "$hostGroup" | python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=""))' 2>/dev/null || printf "%s" "$hostGroup")
  REQ="$REQ&hostgroup=$ESC"
fi

# --- private temp files (0600) ---
tmpConfig=$(mktemp)
tmpBody=$(mktemp)
# ensure 600 even if umask changes
chmod 600 "$tmpConfig" "$tmpBody" 2>/dev/null || true
trap 'rm -f "$tmpConfig" "$tmpBody"' EXIT

# --- build Authorization header in private --config file ---
auth=$(printf "%s:%s" "$apiKey" "$apiSecret" | base64 -w0 2>/dev/null || printf "%s:%s" "$apiKey" "$apiSecret" | base64 | tr -d '\n')
# clear secrets from shell variables as soon as possible
unset apiKey
unset apiSecret
printf 'header = "Authorization: Basic %s"\n' "$auth" > "$tmpConfig"
unset auth
chmod 600 "$tmpConfig"

# --- curl with producer-side caps ---
# --proto =https enforces https only; --max-filesize caps response at 2 MiB
# --max-time and --connect-timeout cap duration
curl --silent --show-error \
  --max-time 30 --connect-timeout 10 \
  --max-filesize 2097152 \
  --proto =https --proto-default https \
  --config "$tmpConfig" \
  "$REQ" --output "$tmpBody" 2>/dev/null
RC=$?

# remove config immediately (secrets)
rm -f "$tmpConfig"
trap 'rm -f "$tmpBody"' EXIT

if [ $RC -ne 0 ]; then
  printf '{"error":"fetch-failed","httpStatus":%d}\n' "$RC"
  rm -f "$tmpBody"
  exit 0
fi

if [ ! -s "$tmpBody" ]; then
  printf '{"error":"fetch-failed","httpStatus":0}\n'
  rm -f "$tmpBody"
  exit 0
fi

sz=$(stat -c%s "$tmpBody" 2>/dev/null || wc -c < "$tmpBody" | tr -d ' ')
# normalize
sz=$(printf "%s" "$sz" | tr -d '[:space:]')
# guard non-numeric
case "$sz" in
  ''|*[!0-9]*) sz=0 ;;
esac
if [ "$sz" -gt 2097152 ]; then
  printf '{"error":"response-too-large"}\n'
  rm -f "$tmpBody"
  exit 0
fi

# output capped body
head -c 2097152 "$tmpBody"
rm -f "$tmpBody"
trap - EXIT
