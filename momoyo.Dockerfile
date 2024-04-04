FROM itzg/minecraft-server:java17-alpine
LABEL org.opencontainers.image.authors="yumio <csaila@live.com>"
LABEL org.opencontainers.image.version="v1.1"

RUN apk add --no-cache ansible-core rclone wget unzip jq openssh

ARG KEEPUP_VERSION=2.0.1

ENV\
    KEEPUP=true\
    KEEPUP_ALLOW_OVERRIDES=true\
    ANSIBLE=true\
    ANSIBLE_PULL=true\
    ANSIBLE_PULL_BRANCH=master\
    UPDATE_DATA_OWNER=true\
    SERVER_NAME=dev\
    ANSIBLE_HOME=/data\
    ANSIBLE_CONFIG=/server-config/ansible.cfg

WORKDIR /opt/minecraft

# Install keepup
RUN wget -nv -q -O keepup.zip https://github.com/MineInAbyss/Keepup/releases/download/v${KEEPUP_VERSION}/keepup-shadow-${KEEPUP_VERSION}.zip  \
    # unzip file inside hocon-to-json.zip into /usr/local \
    && unzip -q keepup.zip \
    && rclone copy keepup-shadow-${KEEPUP_VERSION}/ /usr/local \
    && chmod +x /usr/local/bin/keepup \
    && rm -rf keepup.zip keepup-shadow-${KEEPUP_VERSION}

COPY config/ansible-requirements.yml /opt/ansible/requirements.yml

RUN ansible-galaxy collection install -r /opt/ansible/requirements.yml -p /opt/ansible/collections \
    && rm /opt/ansible/requirements.yml

# Copy over scripts
COPY scripts/dev /scripts/dev
RUN chmod +x /scripts/dev/*
RUN dos2unix /scripts/dev/*

# Symlink for rclone after Ansible
RUN mkdir -p ~/.config/rclone
RUN ln -s /data/.config/rclone/rclone.conf ~/.config/rclone/rclone.conf

WORKDIR /data

ENTRYPOINT ["/scripts/dev/entrypoint"]
