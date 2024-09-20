FROM alpine as helper
ARG KEEPUP_VERSION='3.0.0-alpha.3'
RUN wget -nv -q -O keepup.zip https://github.com/MineInAbyss/Keepup/releases/download/v${KEEPUP_VERSION}/keepup-shadow-${KEEPUP_VERSION}.zip  \
    # unzip file inside hocon-to-json.zip into /usr/local \
    && unzip -q keepup.zip \
    && mv keepup-shadow-${KEEPUP_VERSION}/ keepup
FROM itzg/minecraft-server:java21 as graalbuntu
LABEL org.opencontainers.image.authors="Offz <offz@mineinabyss.com>; DoggySazHi <reimu@williamle.com>"
LABEL org.opencontainers.image.version="v0.0.1"
# Install GraalVM
RUN mkdir /usr/lib/jvm; \
    wget "https://github.com/graalvm/oracle-graalvm-ea-builds/releases/download/jdk-24.0.0-ea.13/graalvm-jdk-24.0.0-ea.13_linux-x64_bin.tar.gz"; \
    tar -zxC /usr/lib/jvm -f graalvm-jdk-24.0.0-ea.13_linux-x64_bin.tar.gz; \
    rm -f graalvm-jdk-24.0.0-ea.13_linux-x64_bin.tar.gz
# Configure glibc and GraalVM
ENV JAVA_HOME=/usr/lib/jvm/graalvm-jdk-24+14.1 \
    PATH=/usr/lib/jvm/graalvm-jdk-24+14.1/bin:$PATH
# Yeet the Adoptium JDK
RUN rm -rf /opt/java/openjdk
ENV PATH $JAVA_HOME/bin:$PATH
RUN echo "PATH = $PATH" && ls /usr/lib/jvm/ && ${JAVA_HOME}/bin/java -version
# Check if the "java" command points to GraalVM
RUN echo "Testing Java..." && java --version | grep GraalVM
# Prepare Ansible and Keepup
RUN apt update; \
    apt install -y software-properties-common; \
    add-apt-repository --yes --update ppa:ansible/ansible; \
    apt install -y ansible rclone unzip jq openssh-client
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