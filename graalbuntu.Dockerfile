FROM alpine AS helper
ARG KEEPUP_VERSION='3.1.2'
RUN wget -nv -q -O keepup.zip https://github.com/MineInAbyss/Keepup/releases/download/v${KEEPUP_VERSION}/keepup-${KEEPUP_VERSION}.zip  \
    && unzip -q keepup.zip \
    && mv keepup-${KEEPUP_VERSION}/ keepup

FROM itzg/minecraft-server:java21 AS graalbuntu
LABEL org.opencontainers.image.authors="Offz <offz@mineinabyss.com>; DoggySazHi <reimu@williamle.com>; yumio <csaila@live.com>"
LABEL org.opencontainers.image.version="v0.0.1"

# Build and install mimalloc for performance optimization
RUN set -ex; \
    apt-get update -y; \
    apt-get install -y make cmake g++ git; \
    cd /; \
    git clone https://github.com/microsoft/mimalloc.git; \
    cd mimalloc; \
    mkdir build; \
    cd build; \
    cmake ..; \
    make install; \
    cd /; \
    rm -rf mimalloc; \
    apt-get remove -y git; \
    apt-get autoremove -y

# Install Zulu JDK 25
RUN mkdir -p /usr/lib/jvm; \
    wget -q "https://cdn.azul.com/zulu/bin/zulu25.28.85-ca-jdk25.0.0-linux_x64.tar.gz"; \
    tar -zxC /usr/lib/jvm -f zulu25.28.85-ca-jdk25.0.0-linux_x64.tar.gz; \
    rm -f zulu25.28.85-ca-jdk25.0.0-linux_x64.tar.gz

# Configure Zulu as default Java
ENV JAVA_HOME=/usr/lib/jvm/zulu25.28.85-ca-jdk25.0.0-linux_x64 \
    PATH=/usr/lib/jvm/zulu25.28.85-ca-jdk25.0.0-linux_x64/bin:$PATH

# Remove the default JDK
RUN rm -rf /opt/java/openjdk

# Verify Java installation
RUN java --version | grep -i zulu

# Install system dependencies
RUN apt-get install -y software-properties-common libstdc++6; \
    add-apt-repository --yes --update ppa:ansible/ansible; \
    apt-get install -y ansible rclone unzip jq file openssh-client dos2unix

# Install Keepup
COPY --from=helper /keepup /usr/local

# Environment variables
ENV KEEPUP=true \
    KEEPUP_ALLOW_OVERRIDES=true \
    ANSIBLE=true \
    ANSIBLE_PULL=true \
    ANSIBLE_PULL_BRANCH=master \
    UPDATE_DATA_OWNER=true \
    SERVER_NAME=dev \
    ANSIBLE_HOME=/data

# Install ansible collections
COPY config/ansible-requirements.yml /opt/ansible/requirements.yml
RUN ansible-galaxy collection install -r /opt/ansible/requirements.yml -p /opt/ansible/collections \
    && rm /opt/ansible/requirements.yml

# Copy and prepare scripts
COPY scripts/dev /scripts/dev
RUN chmod +x /scripts/dev/* && dos2unix /scripts/dev/*

# Setup rclone config symlink
RUN mkdir -p ~/.config/rclone && \
    ln -s /data/.config/rclone/rclone.conf ~/.config/rclone/rclone.conf

WORKDIR /data
ENTRYPOINT ["/scripts/dev/entrypoint"]