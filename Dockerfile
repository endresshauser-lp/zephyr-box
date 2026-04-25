#
# --- Stage 1 ---
# Build probe-rs
#
FROM ubuntu:26.04 AS probe-rs

ENV RUST_VERSION=1.90.0
ENV PROBE_RS_VERSION=0.31.0

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
        https://static.rust-lang.org/rustup/archive/1.29.0/x86_64-unknown-linux-gnu/rustup-init \
    && echo "4acc9acc76d5079515b46346a485974457b5a79893cfb01112423c89aeb5aa10 rustup-init" | sha256sum -c - \
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
FROM ubuntu:26.04

ARG ZSDK_VERSION=1.0.1

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
        libusb-1.0-0-dev \
        libxml2-dev \
        libxslt1-dev \
        iptables \
        ssh \
        bzip2 \
        dos2unix \
        unzip \
        cppcheck \
        llvm-22 \
        clang-22 \
        libclang-rt-22-dev \
        clangd-22 \
        lldb-22 \
        clang-tidy-22 \
        libfuzzer-22-dev \
        libunwind-22-dev \
        dotnet-sdk-10.0 \
        minicom \
        tmux \
        snmp \
        socat \
        bash-completion \
        mc \
        less \
    && rm --recursive --force /var/lib/apt/lists/*

ENV PATH="/usr/lib/llvm-22/bin:$PATH"

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
        gdb \
        gdbserver \
        gcc-16 \
        gcc-16-multilib \
        g++-16-multilib \
        libsdl2-dev \
        libmagic1 \
        libc6-dbg:i386 \
        valgrind \
        exiftool \
        jq \
    && rm --recursive --force /var/lib/apt/lists/* \
    && for cmd in cpp g++ gcc gcov gcc-ar gcc-nm gcc-ranlib gcov-dump gcov-tool lto-dump; do update-alternatives --install /usr/bin/$cmd $cmd /usr/bin/$cmd-16 50; done \
    && for cmd in cpp g++ gcc gcov gcc-ar gcc-nm gcc-ranlib gcov-dump gcov-tool lto-dump; do update-alternatives --install /usr/bin/x86_64-linux-gnu-$cmd x86_64-linux-gnu-$cmd /usr/bin/x86_64-linux-gnu-$cmd-16 50; done \
    && update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++-16 50 \
    && update-alternatives --install /usr/bin/cc cc /usr/bin/gcc-16 50 \
    && ln -s x86_64-linux-gnu/asm /usr/include/asm

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
    # -l llvm
    && ./setup.sh -h -l -t arm-zephyr-eabi
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
        https://storage.googleapis.com/chrome-for-testing-public/147.0.7727.55/linux64/chromedriver-linux64.zip \
    && unzip chromedriver-linux64.zip \
    && cp ./chromedriver-linux64/chromedriver /usr/bin/ \
    && rm --recursive ./chromedriver-linux64 \
    && rm chromedriver-linux64.zip \
    && rm --recursive --force /var/lib/apt/lists/*

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
# --- install nodejs used for cspell and dts-linter ---
#
RUN apt-get update \
    && sudo apt-get install ca-certificates curl gnupg --assume-yes \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor --output /etc/apt/keyrings/nodesource.gpg \
    && NODE_MAJOR=24 \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list \
    && sudo apt-get update \
    && sudo apt-get install nodejs --assume-yes \
    && sudo npm install -g cspell@9.x dts-linter@0.5.x \
    && rm --recursive --force /var/lib/apt/lists/*

#
# --- Install GitHub CLI ---
#
RUN apt-get update \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor --output /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list \
    && sudo apt-get update \
    && sudo apt-get install gh --assume-yes \
    && rm --recursive --force /var/lib/apt/lists/* \
    && echo "[credential \"https://github.com\"]" >> /etc/gitconfig \
    && echo "    helper =" >> /etc/gitconfig \
    && echo "    helper = !/usr/bin/gh auth git-credential" >> /etc/gitconfig \
    && echo "[credential \"https://gist.github.com\"]" >> /etc/gitconfig \
    && echo "    helper =" >> /etc/gitconfig \
    && echo "    helper = !/usr/bin/gh auth git-credential" >> /etc/gitconfig

#
# --- Install PowerShell ---
#
RUN wget --quiet --show-progress --progress=dot:giga \
        https://github.com/PowerShell/PowerShell/releases/download/v7.6.0/powershell_7.6.0-1.deb_amd64.deb \
    && echo "2d2e57d80f72247620070a664ca3405c4897093461d6eccd71e328f0d3e2c6f8 powershell_7.6.0-1.deb_amd64.deb" | sha256sum -c - \
    && sudo apt-get update \
    && sudo apt install --assume-yes --no-install-recommends \
        ./powershell_7.6.0-1.deb_amd64.deb \
    && rm powershell_7.6.0-1.deb_amd64.deb \
    && rm --recursive --force /var/lib/apt/lists/* \
    && pwsh -Command "Set-PSRepository -InstallationPolicy Trusted -Verbose -Name PSGallery" \
    && pwsh -Command "Install-Module -Name PSScriptAnalyzer -Verbose -Scope AllUsers"

#
# --- Install JLink ---
#
RUN wget --quiet --show-progress --progress=dot:giga \
        --post-data "accept_license_agreement=accepted&submit=Download+software" \
        https://www.segger.com/downloads/jlink/JLink_Linux_V934b_x86_64.deb \
    && echo "a9905c699f7b814beead9cbf94a3d945d89e01cb0beab03d7bfc35de157d31a4 JLink_Linux_V934b_x86_64.deb" | sha256sum -c - \
    && sudo apt-get update \
    && sudo ln -s /usr/bin/true /usr/bin/udevadm \
    && sudo apt install --assume-yes --no-install-recommends \
        ./JLink_Linux_V934b_x86_64.deb \
    && rm JLink_Linux_V934b_x86_64.deb \
    && sudo rm -f /usr/bin/udevadm \
    && rm --recursive --force /var/lib/apt/lists/*

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
