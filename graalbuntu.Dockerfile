FROM alpine as helper
ARG KEEPUP_VERSION='3.1.2'
RUN wget -nv -q -O keepup.zip https://github.com/MineInAbyss/Keepup/releases/download/v${KEEPUP_VERSION}/keepup-${KEEPUP_VERSION}.zip  \
    # unzip file inside hocon-to-json.zip into /usr/local \
    && unzip -q keepup.zip \
    && mv keepup-${KEEPUP_VERSION}/ keepup
FROM itzg/minecraft-server:java21 as graalbuntu
LABEL org.opencontainers.image.authors="Offz <offz@mineinabyss.com>; DoggySazHi <reimu@williamle.com>; yumio <csaila@live.com>"
LABEL org.opencontainers.image.version="v0.0.1"

# Needed for mimalloc


RUN set -ex; \
    apt-get update -y; \
    apt-get install -y make cmake g++; \
    cd /; \
    git clone https://github.com/microsoft/mimalloc.git; \
    cd mimalloc; \
    mkdir build; \
    cd build; \
    cmake ..; \
    make install;

# Install GraalVM
RUN mkdir /usr/lib/jvm; \
    wget "https://cdn.azul.com/zulu/bin/zulu25.28.85-ca-jdk25.0.0-linux_x64.tar.gz"; \
    tar -zxC /usr/lib/jvm -f zulu25.28.85-ca-jdk25.0.0-linux_x64.tar.gz; \
    rm -f zulu25.28.85-ca-jdk25.0.0-linux_x64.tar.gz
# Configure glibc and GraalVM
ENV JAVA_HOME=/usr/lib/jvm/zulu25.28.85-ca-jdk25.0.0-linux_x64 \
    PATH=/usr/lib/jvm/zulu25.28.85-ca-jdk25.0.0-linux_x64/bin:$PATH
# Yeet the Adoptium JDK
RUN rm -rf /opt/java/openjdk
ENV PATH $JAVA_HOME/bin:$PATH
RUN echo "PATH = $PATH" && ls /usr/lib/jvm/ && ${JAVA_HOME}/bin/java -version
# Check if the "java" command points to GraalVM
RUN echo "Testing Java..." && java --version
# Prepare Ansible and Keepup
RUN apt-get install -y software-properties-common; \
    add-apt-repository --yes --update ppa:ansible/ansible; \
    apt-get install -y ansible rclone unzip jq file openssh-client
# Needed for async profiler
RUN apt-get install -y libstdc++6
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
# Install ansible collections
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
