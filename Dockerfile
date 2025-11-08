FROM alpine AS helper
ARG KEEPUP_VERSION='3.1.2'
RUN wget -nv -q -O keepup.zip https://github.com/MineInAbyss/Keepup/releases/download/v${KEEPUP_VERSION}/keepup-${KEEPUP_VERSION}.zip \
    && unzip -q keepup.zip \
    && mv keepup-${KEEPUP_VERSION}/ keepup

FROM itzg/minecraft-server:java21-graalvm AS minecraft
LABEL org.opencontainers.image.authors="yumio <csaila@live.com>; DoggySazHi <reimu@williamle.com>"
LABEL org.opencontainers.image.version="v0.0.2"

# Consolidate all package installations and cleanup into one layer
RUN dnf reinstall glibc-common -yq && \
    dnf install -yq \
      glibc-langpack-en \
      glibc-locale-source \
      rclone \
      wget \
      unzip \
      jq \
      python3-pip \
      ansible \
    && dnf clean all

# Set locale
RUN localedef -c -i en_US -f UTF-8 en_US.UTF-8
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
RUN echo "LANG=en_US.UTF-8" > /etc/locale.conf
ENV LANG en_US.UTF-8

COPY --from=helper /keepup /usr/local

ENV\
    KEEPUP=true\
    KEEPUP_ALLOW_OVERRIDES=true\
    ANSIBLE=true\
    ANSIBLE_PULL=true\
    ANSIBLE_PULL_BRANCH=master\
    UPDATE_DATA_OWNER=true\
    SERVER_NAME=dev\
    ANSIBLE_HOME=/data

COPY scripts/dev /scripts/dev
RUN chmod +x /scripts/dev/* && dos2unix /scripts/dev/*

RUN mkdir -p ~/.config/rclone && \
    ln -s /data/.config/rclone/rclone.conf ~/.config/rclone/rclone.conf

WORKDIR /data
ENTRYPOINT ["/scripts/dev/entrypoint"]

FROM itzg/velocity AS proxy
LABEL org.opencontainers.image.authors="yumio <csaila@live.com>"
LABEL org.opencontainers.image.version="v0.0.1"

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      rsync \
      rclone \
      wget \
      unzip \
      git \
      pipx \
      python3-venv \
      jq \
      file \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install --include-deps ansible

COPY --from=helper /keepup /usr/local

ENV\
    KEEPUP=true\
    KEEPUP_ALLOW_OVERRIDES=true\
    ANSIBLE=true\
    ANSIBLE_PULL=true\
    ANSIBLE_PULL_BRANCH=master\
    UPDATE_DATA_OWNER=true\
    SERVER_NAME=dev\
    ANSIBLE_HOME=/server

COPY scripts/dev /scripts/dev
RUN chmod +x /scripts/dev/*

WORKDIR /server

RUN cp /usr/bin/run-bungeecord.sh /start
ENTRYPOINT ["/scripts/dev/workaround"]
