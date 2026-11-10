# wrapvm

A desktop VM for agents: [wrap](https://github.com/tobi/wrap)'s desktop image, as one
`Containerfile` that CI publishes as `ghcr.io/erikmay/wrapvm:desktop` and a `Smolfile` that boots it.

The image is multi-arch: amd64 and arm64. smolvm pulls the host's own architecture, so on an Apple Silicon
Mac the machine is a native arm64 microVM on Hypervisor.framework (no Rosetta, no QEMU). The arm64 image is
built on Arch Linux ARM, from tobi/wrap's `Containerfile.arm64` (wrap publishes no arm64 base), and runs
Google's Linux arm64 Chrome.

- Xvfb `:1` + XFCE, viewed in a browser through [voxl](https://github.com/tembo/voxl) on 6080 (password; `wrap-desktop url` prints the link)
- one persistent Google Chrome with CDP on 9222 (9223 on guest interfaces)
- [agent-browser](https://github.com/vercel-labs/agent-browser) for browser use, attached to that Chrome
- [agent-desktop](https://github.com/vercel-labs/agent-desktop) for computer use, through AT-SPI
- `desktop` and `browser` skills in `~/.agents/skills`, pointing agents at those two CLIs' own guides
- sound: PulseAudio with a null sink, streamed by the viewer and recordable with ffmpeg
- the shared Chrome as the default browser (xdg-open, XFCE, `$BROWSER`), with its sandbox on
- ffmpeg
- a prompt that says `[vm:<machine>]` under smolvm, `[container:<host>]` in a container

The `Containerfile` is tobi/wrap's `Containerfile.desktop` at `c562a7d`, plus what wrapvm adds (each block is
marked `wrapvm:`). wrap keeps the CLI and the base image: `ghcr.io/tobi/wrap:latest` on amd64, and on arm64
wrap's `Containerfile.arm64` at the same commit, built by `make base` and by CI.

## Files

| File | What |
| --- | --- |
| `Containerfile` | The VM. CI builds it on amd64 and arm64 runners, tests both and publishes `ghcr.io/erikmay/wrapvm:desktop` (also `:latest`) as one multi-arch tag |
| `Dockerfile` | A symlink to `Containerfile`, for `docker build .` |
| `Smolfile` | A smolvm machine booting that image, with the workspace mount, network policy and credentials |
| `wrapvm` | One machine per directory: create, start, shell in (`wrapvm -- CMD` runs CMD) |
| `wrapvm-watch` | One local page with every wrapvm machine's desktop, live, and a watchdog for their viewers |
| `skills/` | The `desktop` and `browser` skills, installed into `~/.agents/skills` |
| `tests/` | wrap's desktop tests and `container_wrapvm.sh`; run by CI and `make test` |

## Use

```sh
./wrapvm                                  # smolvm: machine for $PWD, zsh in it; prints the viewer's sign-in link
docker run -d -p 127.0.0.1:6080:6080 ghcr.io/erikmay/wrapvm:desktop   # or as a container
docker exec <id> wrap-desktop url         # its sign-in link
```

Each machine gets its own viewer port when `wrapvm` creates it: the first from 6080 up that no other machine
holds and nothing listens on (`WRAPVM_DESKTOP_PORT` picks one). It keeps that port across restarts.

The guest `user` takes your host uid and gid on the machine's first start (`wrap-realign`, run by the
Smolfile's init with the `WRAP_UID`/`WRAP_GID` that `wrapvm` passes at create), so the mounted workspace is
writable inside and new files are yours on the host. On macOS that is 501:20; the image is built as 1000.

## Watch every machine

```sh
./wrapvm-watch                            # http://127.0.0.1:6060/ (WRAPVM_WATCH_PORT picks another)
./wrapvm-watch --install                  # macOS: a LaunchAgent, up at login and after a crash
./wrapvm-watch --uninstall
```

One tile per wrapvm machine: a live picture of its desktop, its folder, guest CPU and memory, and the host
memory its VM holds. A click opens the interactive viewer. As a watchdog it marks a desktop whose viewer stops
answering and, after `WRAPVM_WATCH_HEAL_SECONDS` (30; 0 turns it off), runs `wrap-desktop start` in it. It
listens on loopback only and answers only pages served from 127.0.0.1 or localhost. It needs Python 3 and
`smolvm`.

## agent-browser config

`AGENT_BROWSER_CONFIG=/home/user/workspace/agent-browser.json` is set everywhere. When that file is
missing, `wrap-desktop start` and every login shell write `{"headed": true, "autoConnect": true}`; an
existing file is never touched. It replaces `~/.agent-browser/config.json`.

## On a Mac (Apple Silicon)

```sh
brew install smol-machines/tap/smolvm
./wrapvm                                  # pulls the arm64 image and boots it natively
```

To boot a local build instead of the published one, build it with Docker (OrbStack, Docker Desktop) or podman:

```sh
make image.tar                            # arm64: builds wrap's arm64 base first (make base), then the image
WRAPVM_IMAGE=$PWD/wrapvm.tar ./wrapvm
```

## Develop

```sh
make test                                 # build for this host's arch + tests; podman if present, else docker
make image.tar && WRAPVM_IMAGE=$PWD/wrapvm.tar ./wrapvm   # boot a local build under smolvm
```

`ARCH` (amd64 or arm64) defaults to the host's. On arm64, `make base` builds `localhost/wrap:arm64` from
tobi/wrap at `WRAP_REV`; `make image BASE_TARGET=` reuses one already built.
