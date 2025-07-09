#
# --- Stage 1 ---
# Build probe-rs
#
FROM ubuntu:24.04 AS probe-rs

ENV RUST_VERSION=1.87.0
ENV PROBE_RS_VERSION=0.29.0

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo

RUN apt-get update \
    && apt-get upgrade --assume-yes \
    && apt-get install --assume-yes --no-install-recommends \
        ca-certificates \
        gcc \
        libc6-dev \
        wget \
        pkg-config \
        libudev-dev \
    && rm --recursive --force /var/lib/apt/lists/*


RUN wget --quiet --show-progress --progress=dot:giga \
        https://static.rust-lang.org/rustup/archive/1.28.2/x86_64-unknown-linux-gnu/rustup-init \
    && echo "20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c rustup-init" | sha256sum -c - \
    && chmod +x rustup-init \
    && ./rustup-init -y --profile minimal --default-toolchain $RUST_VERSION --default-host x86_64-unknown-linux-gnu \
    && rm rustup-init \
    && . "$CARGO_HOME/env" \
    && mkdir -p /opt/probe-rs \
    && cargo install probe-rs-tools@=$PROBE_RS_VERSION --locked --root /opt/probe-rs --features remote

#
# --- Stage 2 ---
# Build zephyr-box
#
FROM ubuntu:24.04

ARG ZSDK_VERSION=0.17.1

ARG UID=1001
ARG GID=1001

#
# --- Time zone ---
#
ENV TZ=Europe/Zurich
RUN ln --symbolic --no-dereference --force /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone

#
# --- General APT packages ---
#
RUN apt-get update \
    && apt-get upgrade --assume-yes \
    && apt-get install --assume-yes --no-install-recommends \
        software-properties-common \
        sudo \
        pkg-config \
        iproute2 \
        openocd \
        iptables \
        ssh \
        bzip2 \
        dos2unix \
        unzip \
        cppcheck \
        llvm-19 \
        clang-19 \
        libclang-rt-19-dev \
        clangd-19 \
        clang-tidy-19 \
        libfuzzer-19-dev \
        libunwind-19-dev \
        dotnet-sdk-8.0 \
        minicom \
        tmux \
        snmp \
        socat \
    && rm --recursive --force /var/lib/apt/lists/*

ENV PATH="/usr/lib/llvm-19/bin:$PATH"

#
# --- Configuration ---
#
ENV PKG_CONFIG_PATH=/usr/lib/i386-linux-gnu/pkgconfig
# Minicom configuration
RUN echo "pu port /dev/ttyACM0" >> /etc/minicom/minirc.ttyACM0
# Avoid pwd for sudo
RUN echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/sudo-nopasswd

#
# --- Zephyr APT packages ---
# Required according to:
# https://docs.zephyrproject.org/latest/develop/getting_started/index.html#install-dependencies
# In addition,
#   - libc6-dbg:i386, for debugging native-sim executables
#   - valgrind, for leak checking using twister with option --enable-valgrind
#
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get upgrade --assume-yes \
    && apt-get install --assume-yes --no-install-recommends \
        git \
        cmake \
        ninja-build \
        gperf \
        ccache \
        dfu-util \
        device-tree-compiler \
        wget \
        python3-venv \
        python3-dev \
        python3-pip \
        python3-setuptools \
        python3-tk \
        python3-wheel \
        xz-utils \
        file \
        make \
        gcc \
        gdb \
        gdbserver \
        gcc-multilib \
        g++-multilib \
        libsdl2-dev \
        libmagic1 \
        libc6-dbg:i386 \
        valgrind \
    && rm --recursive --force /var/lib/apt/lists/*

#
# --- Zephyr SDK toolchain ---
#
WORKDIR /opt
RUN wget --quiet --show-progress --progress=dot:giga \
        https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZSDK_VERSION}/zephyr-sdk-${ZSDK_VERSION}_linux-x86_64_minimal.tar.xz \
    && wget --quiet --show-progress --progress=dot:giga --output-document - \
        https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZSDK_VERSION}/sha256.sum \
        | shasum --check --ignore-missing \
    && tar --extract --file zephyr-sdk-${ZSDK_VERSION}_linux-x86_64_minimal.tar.xz \
    && rm zephyr-sdk-${ZSDK_VERSION}_linux-x86_64_minimal.tar.xz \
    && cd zephyr-sdk-${ZSDK_VERSION} \
    # -t toolchain
    # -h host tools
    && ./setup.sh -h -t x86_64-zephyr-elf -t arm-zephyr-eabi
ENV ZEPHYR_TOOLCHAIN_PATH=/opt/zephyr-sdk-${ZSDK_VERSION}

#
# --- Chrome (for Selenium Tests) ---
#
RUN apt-get update \
    && wget --quiet --show-progress --progress=dot:giga \
        https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes --no-install-recommends \
        ./google-chrome-stable_current_amd64.deb \
    && rm ./google-chrome-stable_current_amd64.deb \
    && wget --quiet --show-progress --progress=dot:giga \
        https://storage.googleapis.com/chrome-for-testing-public/125.0.6422.78/linux64/chromedriver-linux64.zip \
    && unzip chromedriver-linux64.zip \
    && cp ./chromedriver-linux64/chromedriver /usr/bin/ \
    && rm --recursive ./chromedriver-linux64 \
    && rm chromedriver-linux64.zip \
    && rm --recursive --force /var/lib/apt/lists/*

#
# --- Puncover ---
#
WORKDIR /opt/toolchains
RUN pip3 install --verbose --upgrade --no-cache-dir --break-system-packages \
        'puncover@git+https://github.com/HBehrens/puncover@0.4.2' \
    && wget --quiet --show-progress --progress=dot:giga --output-document archive.tar.xz \
        "https://developer.arm.com/-/media/Files/downloads/gnu/12.2.mpacbti-rel1/binrel/arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi.tar.xz?rev=71e595a1f2b6457bab9242bc4a40db90&hash=37B0C59767BAE297AEB8967E7C54705BAE9A4B95" \
    && echo 1f2277f96903551ac7b2766f17513542 archive.tar.xz > /tmp/archive.md5 \
    && md5sum --check /tmp/archive.md5 \
    && rm /tmp/archive.md5 \
    && tar --extract --file archive.tar.xz \
    && rm archive.tar.xz \
    && ln --symbolic arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi/bin/arm-none-eabi-gcc /usr/bin/arm-none-eabi-gcc \
    && ln --symbolic arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi/bin/arm-none-eabi-g++ /usr/bin/arm-none-eabi-g++ \
    && ln --symbolic arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi/bin/arm-none-eabi-gdb /usr/bin/arm-none-eabi-gdb \
    && ln --symbolic arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi/bin/arm-none-eabi-size /usr/bin/arm-none-eabi-size \
    && ln --symbolic arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi/bin/arm-none-eabi-objcopy /usr/bin/arm-none-eabi-objcopy \
    && ln --symbolic arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi/bin/arm-none-eabi-objdump /usr/bin/arm-none-eabi-objdump

#
# --- NRF command line tools ---
#
RUN wget https://nsscprodmedia.blob.core.windows.net/prod/software-and-other-downloads/desktop-software/nrf-command-line-tools/sw/versions-10-x-x/10-15-1/nrf-command-line-tools-10.15.1_linux-amd64.zip \
    && unzip nrf-command-line-tools-10.15.1_linux-amd64.zip \
    && dpkg -i --force-overwrite nrf-command-line-tools_10.15.1_amd64.deb \
    && dpkg -i --force-overwrite JLink_Linux_V758b_x86_64.deb \
    && rm nrf-command-line-tools-10.15.1_linux-amd64.zip \
    && rm JLink_Linux_V758b_x86_64.deb \
    && rm nrf-command-line-tools-10.15.1_Linux-amd64.tar.gz \
    && rm JLink_Linux_V758b_x86_64.tgz \
    && rm nrf-command-line-tools-10.15.1-1.amd64.rpm \
    && rm nrf-command-line-tools_10.15.1_amd64.deb

#
# --- APT packages for SD-card image ---
#
RUN apt-get update \
    && apt-get upgrade --assume-yes \
    && apt-get install --assume-yes --no-install-recommends \
        libparted-dev \
        dosfstools \
        lz4 \
    && rm --recursive --force /var/lib/apt/lists/*

#
# --- install nodejs used for cspell ---
#
RUN apt-get update \
    && sudo apt-get install ca-certificates curl gnupg --assume-yes \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor --output /etc/apt/keyrings/nodesource.gpg \
    && NODE_MAJOR=20 \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list \
    && sudo apt-get update \
    && sudo apt-get install nodejs --assume-yes \
    && sudo npm install -g cspell@8.x \
    && rm --recursive --force /var/lib/apt/lists/*

#
# --- Install GitHub CLI ---
#
RUN apt-get update \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor --output /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list \
    && sudo apt-get update \
    && sudo apt-get install gh --assume-yes \
    && rm --recursive --force /var/lib/apt/lists/*

#
# --- Install PowerShell ---
#
RUN wget --quiet --show-progress --progress=dot:giga \
        https://github.com/PowerShell/PowerShell/releases/download/v7.4.11/powershell_7.4.11-1.deb_amd64.deb \
    && echo "0adbcf7d3cf4f78d86b1fa568bede76a7aaaacb97089c52a2f452c799bbf38fd powershell_7.4.11-1.deb_amd64.deb" | sha256sum -c - \
    && sudo apt install --assume-yes --no-install-recommends \
        ./powershell_7.4.11-1.deb_amd64.deb \
    && rm powershell_7.4.11-1.deb_amd64.deb \
    && rm --recursive --force /var/lib/apt/lists/* \
    && pwsh -Command "Set-PSRepository -InstallationPolicy Trusted -Verbose -Name PSGallery" \
    && pwsh -Command "Install-Module -Name PSScriptAnalyzer -Verbose -Scope AllUsers"

#
# --- Install probe-rs ---
#
COPY --from=probe-rs /opt/probe-rs/bin/probe-rs /usr/local/bin/probe-rs

#
# --- Remove 'ubuntu' user and create 'user' user ---
#
RUN userdel --remove ubuntu \
    && groupadd --gid $GID --non-unique user \
    && mkdir --parents /etc/sudoers.d \
    && useradd --uid $UID --create-home --gid user --groups plugdev,dialout user \
    && echo "user ALL = NOPASSWD: ALL" > /etc/sudoers.d/user \
    && chmod 0440 /etc/sudoers.d/user \
    && chsh --shell /bin/bash user

#
# --- Add entrypoint script ---
#
RUN --mount=type=bind,source=./entrypoint.sh,target=/tmp/entrypoint.sh \
    cp /tmp/entrypoint.sh /home/user/entrypoint.sh \
    && dos2unix /home/user/entrypoint.sh \
    && chmod +x /home/user/entrypoint.sh

#
# --- Become user ---
#
USER user

ENTRYPOINT ["/home/user/entrypoint.sh"]
