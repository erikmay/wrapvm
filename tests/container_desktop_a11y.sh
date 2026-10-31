#!/bin/bash
# Run inside a fresh, disposable wrapvm container, as the image's user:
#   podman run --rm -v "$PWD/tests:/tests:ro" localhost/wrapvm:test bash /tests/container_desktop_a11y.sh
# agent-desktop must see GTK apps and Chrome with no wrapper and no extra env.
set -euo pipefail
ok() { printf 'ok - %s\n' "$*"; }
wait_for() { # tries command...
  local tries="$1"; shift
  for _ in $(seq "$tries"); do "$@" >/dev/null 2>&1 && return 0; sleep 0.5; done
  "$@"
}

test -z "${NO_AT_BRIDGE+set}"
test "$AGENT_BROWSER_CONFIG" = /home/user/workspace/agent-browser.json
ffmpeg -hide_banner -version >/dev/null
agent-desktop version | jq -e '.ok' >/dev/null
ok 'NO_AT_BRIDGE is unset, AGENT_BROWSER_CONFIG is global, ffmpeg and agent-desktop are installed'

wrap-desktop start --quiet
test "$(jq -c . "$AGENT_BROWSER_CONFIG")" = '{"headed":true,"autoConnect":true}'
test "$(stat -c %u "$AGENT_BROWSER_CONFIG")" = "$(id -u)"
echo '{"headed": false}' > "$AGENT_BROWSER_CONFIG"
wrap-agent-browser-config
test "$(jq -c . "$AGENT_BROWSER_CONFIG")" = '{"headed":false}'
rm "$AGENT_BROWSER_CONFIG"; wrap-agent-browser-config
ok 'the default agent-browser config is written once, never over a changed one'

gdbus call --session -d org.a11y.Bus -o /org/a11y/bus \
  -m org.freedesktop.DBus.Properties.Get org.a11y.Status IsEnabled | grep -q true
ok 'the accessibility bus reports IsEnabled=true'

test "$(xfconf-query -c xfwm4 -p /general/use_compositing)" = false
ok 'xfwm4 runs without compositing'

gtk-demo >/dev/null 2>&1 &
page="$(mktemp -d)"
echo '<title>wrapvm page</title><h1>Accessible page</h1><button>Press me</button>' > "$page/index.html"
wrap-chrome --new-window "file://$page/index.html" >/dev/null 2>&1 &
apps() { agent-desktop list-apps | jq -r '.data.apps[].name'; }
wait_for 40 sh -c 'agent-desktop list-apps | jq -e "[.data.apps[].name] | index(\"gtk-demo\")"'
wait_for 40 sh -c 'agent-desktop list-apps | jq -e "[.data.apps[].name | ascii_downcase] | map(test(\"chrome\")) | any"'
ok "agent-desktop lists the GTK app and Chrome: $(apps | tr '\n' ' ')"

field=$(agent-desktop find --app gtk-demo --role textfield | jq -r '.data.matches[0].ref_id')
greet=$(agent-desktop find --app gtk-demo --name Greet | jq -r '.data.matches[0].ref_id')
agent-desktop type "$field" 'Ada Lovelace' | jq -e '.ok' >/dev/null
agent-desktop click "$greet" | jq -e '.ok' >/dev/null
wait_for 10 sh -c "agent-desktop find --app gtk-demo --text Hello | jq -e '.data.matches[] | select(.name == \"Hello, Ada Lovelace!\")'"
ok 'type and click reach the GTK app: Hello, Ada Lovelace!'

chrome=$(apps | grep -i -m1 chrome)
wait_for 20 sh -c "agent-desktop find --app '$chrome' --name 'Press me' | jq -e '.data.matches | length > 0'"
ok 'Chrome exports its page content'

echo '<title>agent-browser page</title>' > "$page/ab.html"
agent-browser open "file://$page/ab.html" >/dev/null
curl -fsS http://127.0.0.1:9222/json/list | jq -e '[.[].title] | index("agent-browser page")' >/dev/null
ok 'agent-browser, with the default config, opens its page in the desktop Chrome'

shot="$(mktemp -d)/screen.png"
agent-desktop screenshot --screen 0 "$shot" | jq -e '.ok' >/dev/null
test -s "$shot"
ok 'whole-screen capture works'
