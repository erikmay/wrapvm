# wrapvm

- `Containerfile` is the one definition of the VM. `Dockerfile` is a symlink to it; never fork them.
  The `Smolfile` only boots the published image (`ghcr.io/tobi/wrapvm`): settings that exist only at run
  time (mounts, network policy, credentials, resources) go there, everything about the guest goes in the Containerfile.
- Scripts are written with `RUN cat > … <<'EOF'`; build with BuildKit or podman, never Docker's legacy builder.
- Keep agent-desktop working: no `NO_AT_BRIDGE`, `wrap-a11y` before Chrome starts, no xfwm4 compositing.
  `tests/container_desktop_a11y.sh` is the acceptance test; run `make test` after changing the image.
- Build steps run as root with `HOME=/root`; nothing may leave root-owned files under `/opt/mise` or `/home/user`.
