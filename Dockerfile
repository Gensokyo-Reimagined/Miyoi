FROM alpine as helper
ARG KEEPUP_VERSION='3.0.0-alpha.3'
RUN wget -nv -q -O keepup.zip https://github.com/MineInAbyss/Keepup/releases/download/v${KEEPUP_VERSION}/keepup-shadow-${KEEPUP_VERSION}.zip  \
    # unzip file inside hocon-to-json.zip into /usr/local \
    && unzip -q keepup.zip \
    && mv keepup-shadow-${KEEPUP_VERSION}/ keepup

FROM itzg/minecraft-server:java21-graalvm as minecraft
LABEL org.opencontainers.image.authors="yumio <csaila@live.com>; DoggySazHi <reimu@williamle.com>"
LABEL org.opencontainers.image.version="v0.0.2"

RUN dnf reinstall glibc-common -yq
RUN dnf install glibc-langpack-en glibc-locale-source rclone wget unzip jq python3-pip -yq
# ansible ansible-collection-community-general ansible-collection-ansible-posix might be out of date? Use pip
# CHAT WE'RE INSTALLING RUST??

# Install Rust for Ansible

RUN dnf install cmake gcc make curl clang openssl-devel python3-devel -yq
RUN dnf module install python39 -yq
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Actually install Ansible

RUN python3.9 -m pip install --user setuptools-rust
RUN python3.9 -m pip install --user ansible
ENV PATH="/root/.local/bin:${PATH}"
# Should be already up-to-date
# RUN ansible-galaxy collection install community.general
# RUN ansible-galaxy collection install ansible.posix

# Clean up build dependencies

RUN dnf remove cmake gcc make clang openssl-devel python3-devel -yq

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

# Copy over scripts
COPY scripts/dev /scripts/dev
RUN chmod +x /scripts/dev/*
RUN dos2unix /scripts/dev/*

# Symlink for rclone after Ansible
RUN mkdir -p ~/.config/rclone
RUN ln -s /data/.config/rclone/rclone.conf ~/.config/rclone/rclone.conf

WORKDIR /data

ENTRYPOINT ["/scripts/dev/entrypoint"]

FROM itzg/bungeecord as proxy
LABEL org.opencontainers.image.authors="yumio <csaila@live.com>"
LABEL org.opencontainers.image.version="v0.0.1"

RUN apt-get update -y \
 && apt-get install -y rsync rclone wget unzip git pipx python3-venv jq

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

# Copy over scripts
COPY scripts/dev /scripts/dev
RUN chmod +x /scripts/dev/*

WORKDIR /server

RUN cp /usr/bin/run-bungeecord.sh /start
ENTRYPOINT ["/scripts/dev/workaround"]
