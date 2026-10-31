# wrapvm

A desktop VM for agents: the [wrap](https://github.com/tobi/wrap) base image plus
an X desktop that a person and agents share.

- Xvfb `:1` + XFCE, VNC on 5900, noVNC on 6080
- one persistent Google Chrome with CDP on 9222 (9223 on guest interfaces)
- [agent-browser](https://github.com/vercel-labs/agent-browser) attached to that Chrome
- [agent-desktop](https://github.com/vercel-labs/agent-desktop) for every other app, through AT-SPI
- ffmpeg, and `gtk-demo`, a small GTK app to try agent-desktop on

Split out of tobi/wrap at `1bbe62b` (its `Containerfile.desktop` and the Smolfile
prototype `697ef58`). wrap keeps the CLI and the base image; this repo is the desktop.

## Files

| File | What |
| --- | --- |
| `Containerfile` | The VM. CI builds it, tests it and publishes `ghcr.io/tobi/wrapvm` |
| `Dockerfile` | A symlink to `Containerfile`, for `docker build .` |
| `Smolfile` | A smolvm machine booting that image, with the workspace mount, network policy and credentials |
| `wrapvm` | One machine per directory: create, start, shell in (`wrapvm -- CMD` runs CMD) |
| `tests/` | Run by CI and `make test` |

## Use

```sh
./wrapvm                                  # smolvm: machine for $PWD, zsh in it; prints the desktop URL
docker run -d -p 127.0.0.1:6080:6080 ghcr.io/tobi/wrapvm    # or as a container
```

The desktop is `http://127.0.0.1:6080/vnc.html?autoconnect=1&resize=scale` (`WRAPVM_DESKTOP_PORT`
picks another host port when `wrapvm` creates the machine).

## Accessibility

agent-desktop only sees apps that register on the session's AT-SPI bus. The image:

- never sets `NO_AT_BRIDGE` (set, GTK and Chromium skip the bridge and nothing is listed)
- sets the a11y bus's `org.a11y.Status.IsEnabled` to true in `wrap-desktop start`, before Chrome starts
  and again on every supervision pass (`wrap-a11y`); Chromium exports no tree while it is false
- has a dconf profile, so `gsettings` works in any HOME
- runs xfwm4 without compositing, so `agent-desktop screenshot --screen 0` works

## agent-browser config

`AGENT_BROWSER_CONFIG=/home/user/workspace/agent-browser.json` is set everywhere. When that file is
missing, `wrap-desktop start` and every login shell write `{"headed": true, "autoConnect": true}`; an
existing file is never touched. It replaces `~/.agent-browser/config.json`.

## Develop

```sh
make test                                 # podman build + tests; CONTAINER_ENGINE=docker works too
make image.tar && WRAPVM_IMAGE=$PWD/wrapvm.tar ./wrapvm   # boot a local build under smolvm
```
