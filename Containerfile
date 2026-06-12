# SkyTower Tidbyt — Podman image on RHEL UBI 10 minimal
#
# Build:
#   podman build -t skytower-tidbyt .
#
# Run once:
#   podman run --rm --env-file .env -e RUN_ONCE=1 skytower-tidbyt
#
# Run loop (default, refresh every 60s):
#   podman run --rm --env-file .env skytower-tidbyt
#
# See CONTAINER.md for full usage.

FROM registry.access.redhat.com/ubi10/ubi-minimal:latest

LABEL org.opencontainers.image.title="SkyTower Tidbyt"
LABEL org.opencontainers.image.description="Render and push SkyTower Tidbyt app with pixlet"

ARG PIXLET_VERSION=v0.34.0

RUN microdnf install -y \
        bash \
        ca-certificates \
        curl \
        gzip \
        tar \
    && microdnf clean all \
    && rm -rf /var/cache/yum

RUN set -eux; \
    PIXLET_VER="${PIXLET_VERSION#v}"; \
    curl -fsSL -o /tmp/pixlet.tgz \
        "https://github.com/tidbyt/pixlet/releases/download/${PIXLET_VERSION}/pixlet_${PIXLET_VER}_linux_amd64.tar.gz"; \
    tar -xzf /tmp/pixlet.tgz -C /usr/local/bin pixlet; \
    chmod +x /usr/local/bin/pixlet; \
    rm /tmp/pixlet.tgz; \
    pixlet version

WORKDIR /app

COPY manifest.yaml skytower.star ./
COPY scripts/ /app/scripts/

RUN chmod +x /app/scripts/*.sh

ENV APP_DIR=/app \
    MODE=dashboard \
    RADIUS=20 \
    INSTALLATION_ID=skytower \
    REFRESH_SECONDS=60 \
    RUN_ONCE=0

ENTRYPOINT ["/app/scripts/entrypoint.sh"]
