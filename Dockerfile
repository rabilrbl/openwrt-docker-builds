ARG SDK_TAG=bcm27xx-bcm2712
FROM openwrt/sdk:${SDK_TAG}

# Install gperf (needed by libseccomp which is a runc dependency)
USER root
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends gperf && rm -rf /var/lib/apt/lists/*

USER buildbot
WORKDIR /builder

# Copy only the version update script (the only custom script needed)
COPY --chown=buildbot:buildbot scripts/update_versions.sh /scripts/update_versions.sh
RUN chmod +x /scripts/update_versions.sh

# Build following the official SDK pattern:
# https://github.com/openwrt/docker#sdk-example
# Note: Feed URLs are replaced with GitHub mirrors for improved reliability
CMD ["bash", "-c", "\
  cd /builder && \
  if [ ! -d ./scripts ]; then bash ./setup.sh; fi && \
  git config --global http.postBuffer 524288000 && \
  sed -i 's|https://git.openwrt.org/feed/packages.git|https://github.com/openwrt/packages.git|g' feeds.conf.default && \
  sed -i 's|https://git.openwrt.org/project/luci.git|https://github.com/openwrt/luci.git|g' feeds.conf.default && \
  sed -i 's|https://git.openwrt.org/feed/luci.git|https://github.com/openwrt/luci.git|g' feeds.conf.default && \
  sed -i 's|https://git.openwrt.org/feed/routing.git|https://github.com/openwrt/routing.git|g' feeds.conf.default && \
  sed -i 's|https://git.openwrt.org/feed/telephony.git|https://github.com/openwrt/telephony.git|g' feeds.conf.default && \
  ./scripts/feeds update packages && \
  make defconfig && \
  bash /scripts/update_versions.sh && \
  ./scripts/feeds install docker dockerd containerd runc docker-compose libseccomp && \
  if ./scripts/feeds install tini 2>/dev/null; then \
    echo 'tini package found and installed'; \
    TINI_AVAILABLE=1; \
  else \
    echo 'tini package not available, skipping'; \
    TINI_AVAILABLE=0; \
  fi && \
  make defconfig && \
  make package/libseccomp/compile -j$(nproc) V=s && \
  if [ \"$TINI_AVAILABLE\" = \"1\" ]; then \
    make package/tini/compile -j$(nproc) V=s || echo 'tini compilation failed, continuing'; \
  fi && \
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
