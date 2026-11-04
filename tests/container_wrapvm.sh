#!/bin/bash
# Run inside a fresh, disposable wrapvm container, as the image's user, in a
# login shell: what wrapvm adds to wrap's desktop.
#   podman run --rm -v "$PWD/tests:/tests:ro" localhost/wrapvm:test bash -l /tests/container_wrapvm.sh
set -euo pipefail
ok() { printf 'ok - %s\n' "$*"; }

ffmpeg -hide_banner -version >/dev/null
ok 'ffmpeg is installed'

test "$AGENT_BROWSER_CONFIG" = /home/user/workspace/agent-browser.json
test "$(jq -c . "$AGENT_BROWSER_CONFIG")" = '{"headed":true,"autoConnect":true}'
test "$(stat -c %u "$AGENT_BROWSER_CONFIG")" = "$(id -u)"
echo '{"headed": false}' > "$AGENT_BROWSER_CONFIG"
wrap-agent-browser-config
test "$(jq -c . "$AGENT_BROWSER_CONFIG")" = '{"headed":false}'
rm "$AGENT_BROWSER_CONFIG"
sudo -n -i true   # a root login shell writes it too, owned by the workspace's user
test "$(stat -c %u "$AGENT_BROWSER_CONFIG")" = "$(id -u)"
ok 'AGENT_BROWSER_CONFIG gets its default once, never over a changed one'

for skill in desktop browser; do
  head -3 "$HOME/.agents/skills/$skill/SKILL.md" | grep -qx "name: $skill"
done
agent-desktop skills get desktop | jq -e '.ok' >/dev/null
agent-browser skills get core >/dev/null
ok 'the desktop and browser skills are in ~/.agents/skills, and the guides they point at answer'

page="$(mktemp -d)"
echo '<title>agent-browser page</title>' > "$page/ab.html"
agent-browser open "file://$page/ab.html" >/dev/null
curl -fsS http://127.0.0.1:9222/json/list | jq -e '[.[].title] | index("agent-browser page")' >/dev/null
ok 'agent-browser, with the default config, opens its page in the desktop Chrome'
