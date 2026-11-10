# wrapvm

- `Containerfile` is the one definition of the VM. `Dockerfile` is a symlink to it; never fork them.
  The `Smolfile` only boots the published image (`ghcr.io/erikmay/wrapvm:desktop`): settings that exist only at run
  time (mounts, network policy, credentials, resources) go there, everything about the guest goes in the Containerfile.
- The Containerfile is tobi/wrap's `Containerfile.desktop` (see the header for the commit) plus blocks marked `wrapvm:`.
  To take a newer wrap desktop, copy its file and tests over and re-apply only the `wrapvm:` blocks.
- Scripts are written with `RUN cat > … <<'EOF'`; build with BuildKit or podman, never Docker's legacy builder.
- Keep agent-desktop working: no `NO_AT_BRIDGE`, `wrap-a11y` on in `wrap-desktop start`, no xfwm4 compositing.
  Run `make test` after changing the image.
- Build steps run as root with `HOME=/root`; nothing may leave root-owned files under `/opt/mise` or `/home/user`.
- The image is multi-arch (amd64, arm64) and must stay so: nothing in the Containerfile may assume x86_64.
  arm64 builds on tobi/wrap's `Containerfile.arm64` (Arch Linux ARM) at `WRAP_REV` (Makefile and CI); keep
  `WRAP_REV` and the Containerfile header's wrap commit the same.
