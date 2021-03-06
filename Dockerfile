FROM openjdk:8-jdk

# Initial Command run as `root`.

ADD bin/circle-android /bin/circle-android

# Skip the first line of the Dockerfile template (FROM ${BASE})

# make Apt non-interactive
RUN echo 'APT::Get::Assume-Yes "true";' > /etc/apt/apt.conf.d/90circleci \
  && echo 'APT::Get::force-Yes "true";' >> /etc/apt/apt.conf.d/90circleci \
  && echo 'DPkg::Options "--force-confnew";' >> /etc/apt/apt.conf.d/90circleci

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y \
    git mercurial xvfb \
    locales sudo openssh-client ca-certificates tar gzip parallel \
    net-tools netcat unzip zip

# Set timezone to UTC by default
RUN ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime

# Use unicode
RUN locale-gen C.UTF-8 || true
ENV LANG=C.UTF-8

# install jq
RUN JQ_URL=$(curl -sSL https://api.github.com/repos/stedolan/jq/releases/latest  |grep browser_download_url |grep '/jq-linux64"' | grep -o -e 'https.*jq-linux64') \
  && curl -sSL --fail -o /usr/bin/jq $JQ_URL \
  && chmod +x /usr/bin/jq

# install docker
RUN set -ex && DOCKER_VERSION=$(curl -sSL https://api.github.com/repos/docker/docker/releases/latest | jq -r '.tag_name' | sed 's|^v||g' ) \
  && DOCKER_URL="https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}.tgz" \
  && curl -sSL -o /tmp/docker.tgz "${DOCKER_URL}" \
  && echo $DOCKER_URL \
  && ls -lha /tmp/docker.tgz \
  && tar -xz -C /tmp -f /tmp/docker.tgz \
  && mv /tmp/docker/* /usr/bin \
  && rm -rf /tmp/docker /tmp/docker.tgz

# docker compose
RUN COMPOSE_URL=$(curl -sSL https://api.github.com/repos/docker/compose/releases/latest | jq -r '.assets[] | select(.name == "docker-compose-Linux-x86_64") | .browser_download_url') \
  && curl -sSL -o /usr/bin/docker-compose $COMPOSE_URL \
  && chmod +x /usr/bin/docker-compose

# install dockerize
RUN DOCKERIZE_URL=$(curl -sSL https://api.github.com/repos/jwilder/dockerize/releases/latest | jq -r '.assets[] | select(.name | startswith("dockerize-linux-amd64")) | .browser_download_url') \
  && curl -sSL -o /tmp/dockerize-linux-amd64.tar.gz $DOCKERIZE_URL \
  && tar -C /usr/local/bin -xzvf /tmp/dockerize-linux-amd64.tar.gz \
  && rm -rf /tmp/dockerize-linux-amd64.tar.gz

RUN groupadd --gid 3434 circleci \
  && useradd --uid 3434 --gid circleci --shell /bin/bash --create-home circleci \
  && echo 'circleci ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-circleci \
  && echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep

# BEGIN IMAGE CUSTOMIZATIONS
# END IMAGE CUSTOMIZATIONS

USER circleci

CMD ["/bin/sh"]


# Now command run as `circle`

ARG sdk_version=sdk-tools-linux-3859397.zip
ARG android_home=/opt/android/sdk

# SHA-256 444e22ce8ca0f67353bda4b85175ed3731cae3ffa695ca18119cbacef1c1bea0

RUN sudo apt-get update && \
    sudo apt-get install --yes xvfb gcc-multilib lib32z1 lib32stdc++6

# Download and install Android SDK
RUN sudo mkdir -p ${android_home} && \
    sudo chown -R circleci:circleci ${android_home} && \
    curl --output /tmp/${sdk_version} https://dl.google.com/android/repository/${sdk_version} && \
    unzip -q /tmp/${sdk_version} -d ${android_home} && \
    rm /tmp/${sdk_version}

# Set environmental variables
ENV ANDROID_HOME ${android_home}
ENV ADB_INSTALL_TIMEOUT 120
ENV PATH=${ANDROID_HOME}/emulator:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:${PATH}

RUN mkdir ~/.android && echo '### User Sources for Android SDK Manager' > ~/.android/repositories.cfg

RUN sdkmanager --update && yes | sdkmanager --licenses

# Update SDK manager and install system image, platform and build tools
RUN echo y | sdkmanager "tools"
RUN echo y | sdkmanager "platform-tools"
RUN echo y | sdkmanager "extras;android;m2repository"
RUN echo y | sdkmanager "extras;google;m2repository"
RUN echo y | sdkmanager "extras;google;google_play_services"
RUN echo y | sdkmanager "emulator"
RUN echo y | sdkmanager "build-tools;25.0.3"

RUN echo y | sdkmanager "platforms;android-23"
RUN echo y | sdkmanager "system-images;android-23;google_apis;armeabi-v7a"

RUN echo y | sdkmanager "platforms;android-24"
RUN echo y | sdkmanager "system-images;android-24;google_apis;armeabi-v7a"

RUN echo y | sdkmanager "platforms;android-25"
RUN echo y | sdkmanager "system-images;android-25;google_apis;armeabi-v7a"
