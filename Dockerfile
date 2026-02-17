ARG SDK_TAG=bcm27xx-bcm2712
FROM openwrt/sdk:${SDK_TAG}

# Install gperf (needed by libseccomp which is a runc dependency)
USER root
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends gperf libblkid-dev && rm -rf /var/lib/apt/lists/*

USER buildbot
WORKDIR /builder

# Copy only the version update script (the only custom script needed)
COPY --chown=buildbot:buildbot scripts/update_versions.sh /scripts/update_versions.sh
RUN chmod +x /scripts/update_versions.sh

# Build following the official SDK pattern:
# https://github.com/openwrt/docker#sdk-example
CMD ["bash", "-c", "\
  cd /builder && \
  if [ ! -d ./scripts ]; then bash ./setup.sh; fi && \
  ./scripts/feeds update packages && \
  make defconfig && \
  bash /scripts/update_versions.sh && \
  ./scripts/feeds install docker dockerd containerd runc docker-compose libseccomp tini && \
  make defconfig && \
  make package/libseccomp/compile -j$(nproc) V=s && \
  make package/tini/compile -j$(nproc) V=s && \
  make package/containerd/compile -j$(nproc) IGNORE_ERRORS=m V=s && \
  make package/runc/compile -j$(nproc) IGNORE_ERRORS=m V=s && \
  make package/docker/compile -j$(nproc) IGNORE_ERRORS=m V=s && \
  make package/dockerd/compile -j$(nproc) IGNORE_ERRORS=m V=s && \
  make package/docker-compose/compile -j$(nproc) IGNORE_ERRORS=m V=s && \
  mkdir -p /output && \
  for ext in ipk apk; do \
    find bin/packages -name \"docker*.$ext\" -exec cp {} /output/ \\; ; \
    find bin/packages -name \"dockerd*.$ext\" -exec cp {} /output/ \\; ; \
    find bin/packages -name \"containerd*.$ext\" -exec cp {} /output/ \\; ; \
    find bin/packages -name \"runc*.$ext\" -exec cp {} /output/ \\; ; \
    find bin/packages -name \"docker-compose*.$ext\" -exec cp {} /output/ \\; ; \
  done"]
