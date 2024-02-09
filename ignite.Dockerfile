FROM itzg/minecraft-server:java21-graalvm
LABEL org.opencontainers.image.authors="DoggySazHi <reimu@williamle.com>"
LABEL org.opencontainers.image.version="v0.0.1"

ENV LANG='en_US.UTF-8'

RUN dnf install ansible glibc-langpack-en glibc-locale-source rclone wget unzip jq -y
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
RUN localedef -v -c -i en_US -f UTF-8 en_US.UTF-8

ARG KEEPUP_VERSION=1.2.3

ENV\
    KEEPUP=true\
    KEEPUP_ALLOW_OVERRIDES=true\
    ANSIBLE=true\
    ANSIBLE_PULL=true\
    ANSIBLE_PULL_BRANCH=master\
    UPDATE_DATA_OWNER=true\
    SERVER_NAME=dev\
    HOME=/data\
    USE_IGNITE_LOADER=true

WORKDIR /opt/minecraft

# Install keepup
RUN wget -nv -O keepup.zip https://github.com/MineInAbyss/Keepup/releases/download/v${KEEPUP_VERSION}/keepup-${KEEPUP_VERSION}.zip  \
    # unzip file inside hocon-to-json.zip into /usr/local \
    && unzip -q keepup.zip \
    && rclone copy keepup-${KEEPUP_VERSION}/ /usr/local \
    && chmod +x /usr/local/bin/keepup \
    && rm -rf keepup.zip keepup-${KEEPUP_VERSION}

# Copy over scripts
COPY scripts/dev /scripts/dev
RUN chmod +x /scripts/dev/*

WORKDIR $HOME

ENTRYPOINT ["/scripts/dev/entrypoint"]
