# wrapvm

A desktop VM for agents: [wrap](https://github.com/tobi/wrap)'s desktop image, as one
`Containerfile` that CI publishes as `ghcr.io/tobi/wrapvm:desktop` and a `Smolfile` that boots it.

- Xvfb `:1` + XFCE, viewed in a browser through [voxl](https://github.com/tembo/voxl) on 6080 (password; `wrap-desktop url` prints the link)
- one persistent Google Chrome with CDP on 9222 (9223 on guest interfaces)
- [agent-browser](https://github.com/vercel-labs/agent-browser) for browser use, attached to that Chrome
- [agent-desktop](https://github.com/vercel-labs/agent-desktop) for computer use, through AT-SPI
- `desktop` and `browser` skills in `~/.agents/skills`, pointing agents at those two CLIs' own guides
- ffmpeg

The `Containerfile` is tobi/wrap's `Containerfile.desktop` at `c562a7d`, plus what wrapvm adds (each block is
marked `wrapvm:`). wrap keeps the CLI and the base image (`ghcr.io/tobi/wrap:latest`, the `FROM` here).

## Files

| File | What |
| --- | --- |
| `Containerfile` | The VM. CI builds it, tests it and publishes `ghcr.io/tobi/wrapvm:desktop` (also `:latest`) |
| `Dockerfile` | A symlink to `Containerfile`, for `docker build .` |
| `Smolfile` | A smolvm machine booting that image, with the workspace mount, network policy and credentials |
| `wrapvm` | One machine per directory: create, start, shell in (`wrapvm -- CMD` runs CMD) |
| `skills/` | The `desktop` and `browser` skills, installed into `~/.agents/skills` |
| `tests/` | wrap's desktop tests and `container_wrapvm.sh`; run by CI and `make test` |

## Use

```sh
./wrapvm                                  # smolvm: machine for $PWD, zsh in it; prints the viewer's sign-in link
docker run -d -p 127.0.0.1:6080:6080 ghcr.io/tobi/wrapvm:desktop   # or as a container
docker exec <id> wrap-desktop url         # its sign-in link
```

`WRAPVM_DESKTOP_PORT` picks another host port when `wrapvm` creates the machine.

## agent-browser config

`AGENT_BROWSER_CONFIG=/home/user/workspace/agent-browser.json` is set everywhere. When that file is
missing, `wrap-desktop start` and every login shell write `{"headed": true, "autoConnect": true}`; an
existing file is never touched. It replaces `~/.agent-browser/config.json`.

## Develop

```sh
make test                                 # podman build + tests; CONTAINER_ENGINE=docker works too
make image.tar && WRAPVM_IMAGE=$PWD/wrapvm.tar ./wrapvm   # boot a local build under smolvm
```
