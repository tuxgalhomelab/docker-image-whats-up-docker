# syntax=docker/dockerfile:1

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG} AS builder

SHELL ["/bin/bash", "-c"]

COPY scripts/start-whats-up-docker.sh /scripts/

ARG WHATS_UP_DOCKER_VERSION

# hadolint ignore=SC1091
RUN \
    set -E -e -o pipefail \
    # Install build dependencies. \
    && homelab install git \
    && mkdir -p /root/whats-up-docker-build \
    # Download what's up docker repo. \
    && git clone \
        --quiet \
        --depth 1 \
        --branch ${WHATS_UP_DOCKER_VERSION:?} \
        https://github.com/fmartinou/whats-up-docker \
        /root/whats-up-docker-build \
    && pushd /root/whats-up-docker-build \
    && source "${NVM_DIR:?}/nvm.sh" \
    && pushd ui && npm ci && npm run build && popd \
    && cp app/package*.json . && npm ci --omit=dev --omit=optional --no-audit --no-fund --no-update-notifier \
    && cp -rf app /release \
    && cp -rf node_modules /release/ \
    && cp -rf ui/dist /release/ui \
    && cp /scripts/start-whats-up-docker.sh /release/ \
    && popd

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

SHELL ["/bin/bash", "-c"]

ARG USER_NAME
ARG GROUP_NAME
ARG USER_ID
ARG GROUP_ID
ARG WHATS_UP_DOCKER_VERSION

RUN --mount=type=bind,target=/build,from=builder,source=/release \
    set -E -e -o pipefail \
    # Install dependencies. \
    # && homelab install ${PACKAGES_TO_INSTALL:?} \
    # Create the user and the group. \
    && homelab add-user \
        ${USER_NAME:?} \
        ${USER_ID:?} \
        ${GROUP_NAME:?} \
        ${GROUP_ID:?} \
        --no-create-home-dir \
    && cp -rf /build /opt/whats-up-docker-${WHATS_UP_DOCKER_VERSION#v} \
    && ln -sf /opt/whats-up-docker-${WHATS_UP_DOCKER_VERSION#v} /opt/whats-up-docker \
    && ln -sf /opt/whats-up-docker/start-whats-up-docker.sh /opt/bin/start-whats-up-docker \
    && mkdir -p /store \
    && chown -R ${USER_NAME}:${GROUP_NAME:?} /opt/whats-up-docker-${WHATS_UP_DOCKER_VERSION#v} /store

EXPOSE 3000

HEALTHCHECK \
    --start-period=15s \
    --interval=30s \
    --timeout=3s \
    CMD curl \
        --silent \
        --fail \
        --location \
        --show-error \
        --insecure \
        https://localhost:3000/health

ENV NODE_ENV=production
ENV WUD_VERSION="$WHATS_UP_DOCKER_VERSION"

ENV USER=${USER_NAME}
USER ${USER_NAME}:${GROUP_NAME}
WORKDIR /home/${USER_NAME}

CMD ["start-whats-up-docker"]
STOPSIGNAL SIGTERM
