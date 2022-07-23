FROM ubuntu:20.04

# hadolint ignore=DL3000,DL3015,DL3008
RUN apt-get update \
    && apt-get install -y \
        ca-certificates \
        curl \
        git \
        iproute2 \
        iptables \
        openssh-client \
        supervisor \
        wget \
    && rm -rf /var/lib/apt/list/*

ENV DOCKER_CHANNEL=stable \
    DOCKER_VERSION=20.10.9 \
    DEBUG=false

# Docker installation
RUN set -eux; \
    \
    arch="$(uname --m)"; \
    case "$arch" in \
    # amd64
    x86_64) dockerArch='x86_64' ;; \
    # arm64v8
    aarch64) dockerArch='aarch64' ;; \
    *) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;;\
    esac; \
    \
    if ! wget -q -O docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz"; then \
    echo >&2 "error: failed to download 'docker-${DOCKER_VERSION}' from '${DOCKER_CHANNEL}' for '${dockerArch}'"; \
    exit 1; \
    fi; \
    \
    tar --extract \
    --file docker.tgz \
    --strip-components 1 \
    --directory /usr/local/bin/ \
    ; \
    rm docker.tgz; \
    \
    dockerd --version; \
    docker --version

COPY modprobe startup.sh /usr/local/bin/
COPY supervisor/ /etc/supervisor/conf.d/
COPY logger.sh /opt/bash-utils/logger.sh

RUN chmod +x /usr/local/bin/startup.sh /usr/local/bin/modprobe
VOLUME /var/lib/docker

# hadolint ignore=DL4006,DL4001
RUN curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# hadolint ignore=DL4006,DL4001
RUN \
    if [ "$(uname --m)" = "aarch64" ]; then \
        curl -LO "https://dl.k8s.io/release/v1.24.3/bin/linux/arm64/kubectl"; \
    else \
        curl -LO "https://dl.k8s.io/release/v1.24.3/bin/linux/amd64/kubectl"; \
    fi \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# hadolint ignore=DL4006,DL4001
RUN \
    if [ "$(uname --m)" = "aarch64" ]; then \
        wget -q -O golang.tar.gz https://go.dev/dl/go1.18.4.linux-arm64.tar.gz; \
    else \
        wget -q -O golang.tar.gz https://go.dev/dl/go1.18.4.linux-amd64.tar.gz; \
    fi \
    && tar zfx golang.tar.gz -C /usr/local/ && rm -f golang.tar.gz

ENV PATH=/usr/local/go/bin:$PATH

# hadolint ignore=DL4006,DL4001
RUN sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin

RUN git config --global --add safe.directory /src

WORKDIR /src

ENTRYPOINT ["startup.sh"]
CMD ["sh"]
