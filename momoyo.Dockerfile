FROM itzg/minecraft-server:java21-alpine
LABEL org.opencontainers.image.authors="yumio <csaila@live.com>"
LABEL org.opencontainers.image.version="v1.0"

RUN apk add --no-cache ansible rclone wget unzip jq

ARG KEEPUP_VERSION=2.0.0-beta.2

ENV\
    KEEPUP=true\
    KEEPUP_ALLOW_OVERRIDES=true\
    ANSIBLE=true\
    ANSIBLE_PULL=true\
    ANSIBLE_PULL_BRANCH=master\
    UPDATE_DATA_OWNER=true\
    SERVER_NAME=dev\
    ANSIBLE_HOME=/data

WORKDIR /opt/minecraft

# Install keepup
RUN wget -nv -O keepup.zip https://github.com/MineInAbyss/Keepup/releases/download/v${KEEPUP_VERSION}/keepup-shadow-${KEEPUP_VERSION}.zip  \
    # unzip file inside hocon-to-json.zip into /usr/local \
    && unzip -q keepup.zip \
    && rclone copy keepup-shadow-${KEEPUP_VERSION}/ /usr/local \
    && chmod +x /usr/local/bin/keepup \
    && rm -rf keepup.zip keepup-shadow-${KEEPUP_VERSION}

# Copy over scripts
COPY scripts/dev /scripts/dev
RUN chmod +x /scripts/dev/*
RUN dos2unix /scripts/dev/*

# Symlink for rclone after Ansible
RUN mkdir -p ~/.config/rclone
RUN ln -s /data/.config/rclone/rclone.conf ~/.config/rclone/rclone.conf

WORKDIR /data

ENTRYPOINT ["/scripts/dev/entrypoint"]
