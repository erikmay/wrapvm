CONTAINER_ENGINE ?= podman
IMAGE ?= localhost/wrapvm:test

.PHONY: image test image.tar check-engine

# The Containerfile writes its scripts with RUN heredocs. Docker's legacy
# builder (no buildx/BuildKit) accepts them but writes empty files.
check-engine:
	@if [ "$$(basename "$(CONTAINER_ENGINE)")" = docker ] && ! $(CONTAINER_ENGINE) buildx version >/dev/null 2>&1; then \
	  echo "docker has no buildx, so it would use the legacy builder, which drops RUN heredocs." >&2; \
	  echo "Install docker-buildx, or run: make CONTAINER_ENGINE=podman" >&2; \
	  exit 1; \
	fi

image: check-engine
	$(CONTAINER_ENGINE) build --pull -t $(IMAGE) -f Containerfile .

# Needs egress (agent-browser installs on first use); every container is disposable.
test: image
	$(CONTAINER_ENGINE) run --rm -v "$(CURDIR)/tests:/tests:ro" $(IMAGE) bash -l /tests/container_desktop_a11y.sh
	CONTAINER_ENGINE="$(CONTAINER_ENGINE)" bash tests/container_desktop_run.sh $(IMAGE)

# A local build for smolvm before CI has published it:
#   make image.tar && WRAPVM_IMAGE=$PWD/wrapvm.tar ./wrapvm
image.tar: image
	$(CONTAINER_ENGINE) save --format docker-archive -o wrapvm.tar $(IMAGE)
