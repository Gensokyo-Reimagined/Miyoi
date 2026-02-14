FROM alpine AS helper
ARG KEEPUP_VERSION='3.1.2'
RUN wget -nv -q -O keepup.zip https://github.com/MineInAbyss/Keepup/releases/download/v${KEEPUP_VERSION}/keepup-${KEEPUP_VERSION}.zip \
    && unzip -q keepup.zip \
    && mv keepup-${KEEPUP_VERSION}/ keepup

FROM itzg/minecraft-server:java21 AS builder
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends make cmake g++ git && \
    cd /tmp && \
    git clone https://github.com/microsoft/mimalloc.git && \
    cd mimalloc && \
    mkdir build && cd build && \
    cmake .. && \
    make install && \
    apt-get purge -y --auto-remove make cmake g++ git && \
    rm -rf /var/lib/apt/lists/*

FROM itzg/minecraft-server:java21 AS minecraft
LABEL org.opencontainers.image.authors="Offz <offz@mineinabyss.com>; DoggySazHi <reimu@williamle.com>; yumio <csaila@live.com>"
LABEL org.opencontainers.image.version="v0.0.1"

COPY --from=builder /usr/local/lib/libmimalloc.so* /usr/local/lib/
COPY --from=helper /keepup /usr/local

COPY config/ansible-requirements.yml /opt/ansible/requirements.yml

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        libstdc++6 \
        rclone \
        unzip \
        jq \
        file \
        openssh-client \
        dos2unix \
        pipx \
        python3-venv \
    && \
    PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install --include-deps ansible && \
    ansible-galaxy collection install -r /opt/ansible/requirements.yml -p /opt/ansible/collections \
    && \
    rm /opt/ansible/requirements.yml && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/lib/jvm && \
    wget -q "https://download.java.net/java/GA/jdk26/c3cc523845074aa0af4f5e1e1ed4151d/35/GPL/openjdk-26_linux-x64_bin.tar.gz" && \
    tar -zxC /usr/lib/jvm -f openjdk-26_linux-x64_bin && \
    rm -f openjdk-26_linux-x64_bin && \
    rm -rf /opt/java/openjdk

ENV JAVA_HOME=/usr/lib/jvm/jdk-26 \
    PATH=/usr/lib/jvm/jdk-26/bin:$PATH

RUN java --version

ENV KEEPUP=true \
    KEEPUP_ALLOW_OVERRIDES=true \
    ANSIBLE=true \
    ANSIBLE_PULL=true \
    ANSIBLE_PULL_BRANCH=master \
    UPDATE_DATA_OWNER=true \
    SERVER_NAME=dev \
    ANSIBLE_HOME=/data

COPY scripts/dev /scripts/dev
RUN chmod +x /scripts/dev/* && dos2unix /scripts/dev/*

RUN mkdir -p ~/.config/rclone && \
    ln -s /data/.config/rclone/rclone.conf ~/.config/rclone/rclone.conf

WORKDIR /data
ENTRYPOINT ["/scripts/dev/entrypoint"]

FROM itzg/bungeecord AS proxy
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
    && \
    PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install --include-deps ansible && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

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
