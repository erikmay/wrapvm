CONTAINER_ENGINE ?= $(shell command -v podman >/dev/null 2>&1 && echo podman || echo docker)
IMAGE ?= localhost/wrapvm:test

# The machine's architecture: amd64 or arm64. The image is always built for the
# host's own architecture, so smolvm runs it natively (no Rosetta, no QEMU).
ARCH ?= $(shell uname -m | sed -e 's/^x86_64$$/amd64/' -e 's/^aarch64$$/arm64/')

# tobi/wrap publishes its base image (ghcr.io/tobi/wrap:latest) for amd64 only.
# On arm64 the base is built here from wrap's Containerfile.arm64 (Arch Linux
# ARM) at WRAP_REV, the commit the Containerfile's desktop half comes from.
WRAP_REV ?= c562a7d2d2dd96600641ffad4c52297ab3bb345a
ifeq ($(ARCH),arm64)
BASE_IMAGE ?= localhost/wrap:arm64
BASE_TARGET := base
PULL :=
else
BASE_IMAGE ?= ghcr.io/tobi/wrap:latest
BASE_TARGET :=
PULL := --pull
endif

.PHONY: base image test image.tar check-engine

# The Containerfile writes its scripts with RUN heredocs. Docker's legacy
# builder (no buildx/BuildKit) accepts them but writes empty files.
check-engine:
	@if [ "$$(basename "$(CONTAINER_ENGINE)")" = docker ] && ! $(CONTAINER_ENGINE) buildx version >/dev/null 2>&1; then \
	  echo "docker has no buildx, so it would use the legacy builder, which drops RUN heredocs." >&2; \
	  echo "Install docker-buildx, or run: make CONTAINER_ENGINE=podman" >&2; \
	  exit 1; \
	fi

# wrap's arm64 base, from its own repository at WRAP_REV.
base: check-engine
	$(CONTAINER_ENGINE) build --platform linux/arm64 -t $(BASE_IMAGE) -f Containerfile.arm64 \
	  "https://github.com/tobi/wrap.git#$(WRAP_REV)"

image: check-engine $(BASE_TARGET)
	$(CONTAINER_ENGINE) build $(PULL) --platform linux/$(ARCH) --build-arg BASE_IMAGE=$(BASE_IMAGE) \
	  -t $(IMAGE) -f Containerfile .

# wrap's desktop tests (tests/container_{mise,viewer,a11y,desktop}*, from
# tobi/wrap), then what wrapvm adds. Needs egress; every container is disposable.
test: image
	$(CONTAINER_ENGINE) run --rm -v "$(CURDIR)/tests:/tests:ro" $(IMAGE) bash /tests/container_mise.sh desktop
	$(CONTAINER_ENGINE) run --rm --network none -e MISE_OFFLINE=1 -v "$(CURDIR)/tests:/tests:ro" $(IMAGE) bash /tests/container_viewer.sh
	$(CONTAINER_ENGINE) run --rm --network none $(IMAGE) sh -lc 'd=$$(mktemp -d); HOME=$$d agent-browser --version >/dev/null && HOME=$$d agent-desktop version >/dev/null'
	CONTAINER_ENGINE="$(CONTAINER_ENGINE)" bash tests/container_a11y_run.sh $(IMAGE)
	CONTAINER_ENGINE="$(CONTAINER_ENGINE)" bash tests/container_desktop_run.sh $(IMAGE)
	$(CONTAINER_ENGINE) run --rm -v "$(CURDIR)/tests:/tests:ro" $(IMAGE) bash -l /tests/container_wrapvm.sh

# A local build for smolvm before CI has published it:
#   make image.tar && WRAPVM_IMAGE=$PWD/wrapvm.tar ./wrapvm
# podman needs --format to write a docker archive; docker writes one already.
image.tar: image
	@if [ "$$(basename "$(CONTAINER_ENGINE)")" = podman ]; then \
	  $(CONTAINER_ENGINE) save --format docker-archive -o wrapvm.tar $(IMAGE); \
	else \
	  $(CONTAINER_ENGINE) save -o wrapvm.tar $(IMAGE); \
	fi
