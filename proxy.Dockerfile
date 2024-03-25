FROM itzg/bungeecord
LABEL org.opencontainers.image.authors="yumio <csaila@live.com>"
LABEL org.opencontainers.image.version="v1.1"

RUN apt-get update -y \
 && apt-get install -y rsync rclone wget unzip git pipx python3-venv jq

# Install ansible
RUN PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install ansible-core

# Install ansible collections
COPY config/ansible-requirements.yml /opt/ansible/requirements.yml

RUN ansible-galaxy collection install -r /opt/ansible/requirements.yml -p /opt/ansible/collections \
    && rm /opt/ansible/requirements.yml

ARG KEEPUP_VERSION=2.0.1

ENV\
    KEEPUP=true\
    KEEPUP_ALLOW_OVERRIDES=true\
    ANSIBLE=true\
    ANSIBLE_PULL=true\
    ANSIBLE_PULL_BRANCH=master\
    UPDATE_DATA_OWNER=false\
    SERVER_NAME=dev\
    HOME=/server\
    ANSIBLE_CONFIG=/server-config/ansible.cfg

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

WORKDIR $HOME

RUN cp /usr/bin/run-bungeecord.sh /start
ENTRYPOINT ["/scripts/dev/entrypoint"]