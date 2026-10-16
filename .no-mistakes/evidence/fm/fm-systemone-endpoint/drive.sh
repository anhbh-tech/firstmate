#!/usr/bin/env bash
# Live driver: the real bin/fm-dispatch-resolve.sh, the real system HTTP client,
# real TLS to a local System One-compatible stub, real quota-axi.
set -u
W=/tmp/fm-ts-live.1NXeyt
REPO=/Users/hoanganh/.no-mistakes/worktrees/541dff6b0b51/01M51EZF3NG3Z9E8XCQ7HJKWMH
TOOL=$REPO/bin/fm-dispatch-resolve.sh
LABHOME=$(mktemp -d /tmp/fm-ts-home.XXXXXX); mkdir -p "$LABHOME/config"
cat > "$LABHOME/config/crew-dispatch.json" <<'JSON'
{ "rules": [ { "when": "A simple bug fix with a stated root cause.",
               "use": { "harness": "claude", "model": "sonnet", "effort": "high" } } ],
  "default": [ { "harness": "claude", "model": "opus" } ] }
JSON
printf '# Task\nFix the off-by-one in the pager; root cause is the <= on line 40.\n' > "$W/brief.md"
unset TYPESAFE_API_KEY TYPESAFE_BASE_URL TYPESAFE_MODEL HTTPS_PROXY https_proxy ALL_PROXY all_proxy
export CURL_CA_BUNDLE=$W/cert.pem FM_HOME=$LABHOME
KEY=live-test-key-not-real
SRV=$W/srv.log; : > "$SRV"; PXY=$W/proxy.log; : > "$PXY"
cd "$W" || exit 1
python3 server.py 18443 "$SRV" with-model & S1=$!
python3 server.py 18444 "$SRV" no-model & S2=$!
python3 proxy.py 18080 "$PXY" & S3=$!
sleep 1
step() { echo; echo "=== $1"; : > "$SRV"; }
show() { echo "--- exit $1"; echo "--- stdout:"; cat out; echo "--- stderr:"; cat err; echo "--- server received:"; cat "$SRV"; }

step "S1 env: TYPESAFE_BASE_URL=https://localhost:18443 TYPESAFE_MODEL=env-model-1"
TYPESAFE_API_KEY=$KEY TYPESAFE_BASE_URL=https://localhost:18443 TYPESAFE_MODEL=env-model-1 "$TOOL" brief.md --project pager >out 2>err; show $?

step "S2 .env: export TYPESAFE_BASE_URL=\"https://127.0.0.1:18443/\" (trailing slash) and TYPESAFE_MODEL='file-model-2'"
printf '%s\n' "TYPESAFE_API_KEY=$KEY" 'export TYPESAFE_BASE_URL="https://127.0.0.1:18443/"' "TYPESAFE_MODEL='file-model-2'" > "$LABHOME/.env"
"$TOOL" brief.md --project pager >out 2>err; show $?

step "S3 precedence: same .env, environment TYPESAFE_BASE_URL=https://localhost:18443 TYPESAFE_MODEL=env-wins"
TYPESAFE_BASE_URL=https://localhost:18443 TYPESAFE_MODEL=env-wins "$TOOL" brief.md --project pager >out 2>err; show $?

step "S4 default model: base URL to stub whose response names no model, no TYPESAFE_MODEL anywhere"
printf '%s\n' "TYPESAFE_API_KEY=$KEY" > "$LABHOME/.env"
TYPESAFE_BASE_URL=https://localhost:18444 "$TOOL" brief.md --project pager >out 2>err; show $?

step "S5 default endpoint: nothing configured; HTTPS_PROXY logger records the CONNECT target and refuses (nothing leaves the machine)"
HTTPS_PROXY=http://127.0.0.1:18080 "$TOOL" brief.md --project pager >out 2>err; show $?
echo "--- proxy CONNECT log:"; cat "$PXY"

for bad in 'http://localhost:18443' 'https://user:url-secret-7d41@localhost:18443' 'https://url-secret-7d41@localhost:18443'; do
  step "S6 invalid base URL [$bad]"
  TYPESAFE_API_KEY=$KEY TYPESAFE_BASE_URL=$bad "$TOOL" brief.md --project pager >out 2>err; show $?
  if grep -q url-secret-7d41 err; then echo "!!! secret echoed"; else echo "--- secret not in stderr"; fi
done

step "S7 invalid .env base URL, no key: off path unchanged"
printf '%s\n' 'TYPESAFE_BASE_URL=http://localhost:18443' > "$LABHOME/.env"
"$TOOL" brief.md --project pager >out 2>err; show $?

kill $S1 $S2 $S3 2>/dev/null; wait 2>/dev/null
mv "$LABHOME" ~/.Trash/
