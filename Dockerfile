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

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        software-properties-common libstdc++6 rclone unzip jq file openssh-client dos2unix && \
    add-apt-repository --yes --update ppa:ansible/ansible && \
    apt-get install -y ansible && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /usr/share/man/* /usr/share/locale/* /usr/share/icons/*

RUN mkdir -p /usr/lib/jvm && cd /tmp && \
    wget -q "https://cdn.azul.com/zulu/bin/zulu25.28.85-ca-jdk25.0.0-linux_x64.tar.gz" && \
    tar -zxC /usr/lib/jvm -f zulu25.28.85-ca-jdk25.0.0-linux_x64.tar.gz && \
    rm -f zulu25.28.85-ca-jdk25.0.0-linux_x64.tar.gz

ENV JAVA_HOME=/usr/lib/jvm/zulu25.28.85-ca-jdk25.0.0-linux_x64
ENV PATH="$JAVA_HOME/bin:$PATH"

RUN rm -rf /opt/java/openjdk && java --version | grep -i zulu

COPY config/ansible-requirements.yml /opt/ansible/requirements.yml
RUN ansible-galaxy collection install -r /opt/ansible/requirements.yml -p /opt/ansible/collections && \
    rm -rf /opt/ansible/requirements.yml /root/.ansible/galaxy_cache

# Copy and process scripts in one layer
COPY scripts/dev /scripts/dev
RUN find /scripts/dev -type f -name "*.sh" -exec chmod +x {} \; && \
    find /scripts/dev -type f -name "*.sh" -exec dos2unix {} \;

# Final symlink layer
RUN mkdir -p ~/.config/rclone && \
    ln -s /data/.config/rclone/rclone.conf ~/.config/rclone/rclone.conf

WORKDIR /data
ENTRYPOINT ["/scripts/dev/entrypoint"]
FROM itzg/bungeecord AS proxy
LABEL org.opencontainers.image.authors="yumio <csaila@live.com>"
LABEL org.opencontainers.image.version="v0.0.1"

# Single layer with cleanup
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        rsync rclone wget unzip git pipx python3-venv jq file && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /usr/share/man/*

# Install ansible and cleanup pipx caches
RUN PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install --include-deps ansible && \
    rm -rf /opt/pipx/.cache

COPY --from=helper /keepup /usr/local

ENV KEEPUP=true KEEPUP_ALLOW_OVERRIDES=true ANSIBLE=true ANSIBLE_PULL=true \
    ANSIBLE_PULL_BRANCH=master UPDATE_DATA_OWNER=true SERVER_NAME=dev ANSIBLE_HOME=/server

COPY scripts/dev /scripts/dev
RUN chmod +x /scripts/dev/*

WORKDIR /server
RUN cp /usr/bin/run-bungeecord.sh /start
ENTRYPOINT ["/scripts/dev/workaround"]