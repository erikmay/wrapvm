#!/bin/bash
# Run on the host: the desktop image as a plain detached container (the
# engine's default security profile, no --init) must bring Chrome's CDP up and
# must stop on SIGTERM instead of waiting out the engine's kill timeout.
set -euo pipefail
image="${1:?expected an image}"
engine="${CONTAINER_ENGINE:-docker}"

ok() { printf 'ok - %s\n' "$*"; }
id="$("$engine" run -d "$image")"
trap '"$engine" rm -f "$id" >/dev/null 2>&1 || true' EXIT

"$engine" exec "$id" sh -c 'for i in $(seq 60); do
  curl -fsS -m 1 http://127.0.0.1:9222/json/version >/dev/null 2>&1 && exit 0; sleep 1
done; exit 1'
ok 'chrome CDP comes up under the default security profile'

"$engine" exec "$id" sh -c 'ip=$(getent ahostsv4 "$(cat /etc/hostname)" | awk "\$1 !~ /^127\\./ {print \$1; exit}")
[ -n "$ip" ] || { echo "no non-loopback address for the container" >&2; exit 1; }
for i in $(seq 10); do
  curl -fsS -m 1 "http://$ip:9223/json/version" >/dev/null 2>&1 && exit 0; sleep 1
done; exit 1'
ok 'CDP is forwarded to the guest interface on 9223'

sleep 2
test "$("$engine" inspect -f '{{.State.Running}}' "$id")" = true
ok 'desktop container keeps running'

started=$(date +%s)
"$engine" stop -t 30 "$id" >/dev/null
elapsed=$(( $(date +%s) - started ))
test "$elapsed" -lt 10
ok "desktop container stops on SIGTERM (${elapsed}s)"
