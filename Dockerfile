FROM ubuntu:24.04

ARG ZSDK_VERSION=0.16.8
ARG UID=1001
ARG GID=1001

#
# --- Time zone ---
#
ENV TZ=Europe/Zurich
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone

#
# --- APT packages ---
#
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        # General Packages
        software-properties-common \
        sudo \
        clang-format \
        pkg-config \
        iproute2 \
        openocd \
        iptables \
        ssh \
        bzip2 \
        dos2unix \
        unzip \
        clang-tidy \
        cppcheck \
        clang \
        minicom \
        # SD-card image tools
        libparted-dev \
        dosfstools \
        lz4 \
        # Zephyr
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
        gcc-multilib \
        g++-multilib \
        libsdl2-dev \
        libmagic1 \
    && rm -rf /var/lib/apt/lists/*

#
# --- Configure minicom ---
#
RUN echo "pu port /dev/ttyACM0" | tee /etc/minicom/minirc.qwx43 >/dev/null

#
# --- Zephyr SDK toolchain ---
#
WORKDIR /opt
RUN wget -q --show-progress --progress=bar:force:noscroll https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZSDK_VERSION}/zephyr-sdk-${ZSDK_VERSION}_linux-x86_64_minimal.tar.xz \
    && wget -O - https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZSDK_VERSION}/sha256.sum | shasum --check --ignore-missing \
    && tar xvf zephyr-sdk-${ZSDK_VERSION}_linux-x86_64_minimal.tar.xz \
    && rm zephyr-sdk-${ZSDK_VERSION}_linux-x86_64_minimal.tar.xz \
    && cd zephyr-sdk-${ZSDK_VERSION} \
    && ./setup.sh -t x86_64-zephyr-elf -t arm-zephyr-eabi -h
ENV ZEPHYR_TOOLCHAIN_PATH=/opt/zephyr-sdk-${ZSDK_VERSION}

#
# --- Chrome (for selenium tests) ---
#
RUN apt-get update \
    && wget -q --show-progress --progress=bar:force:noscroll https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
     ./google-chrome-stable_current_amd64.deb \
    && rm ./google-chrome-stable_current_amd64.deb \
    && wget https://storage.googleapis.com/chrome-for-testing-public/125.0.6422.78/linux64/chromedriver-linux64.zip \
    && unzip chromedriver-linux64.zip \
    && cp ./chromedriver-linux64/chromedriver /usr/bin/ \
    && rm -r ./chromedriver-linux64 \
    && rm chromedriver-linux64.zip \
    && rm -rf /var/lib/apt/lists/*

#
# --- Puncover ---
#
WORKDIR /opt/toolchains
RUN wget -O archive.tar.xz "https://developer.arm.com/-/media/Files/downloads/gnu/12.2.mpacbti-rel1/binrel/arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi.tar.xz?rev=71e595a1f2b6457bab9242bc4a40db90&hash=37B0C59767BAE297AEB8967E7C54705BAE9A4B95" \
    && echo 1f2277f96903551ac7b2766f17513542 archive.tar.xz > /tmp/archive.md5 \
    && md5sum --check /tmp/archive.md5 \
    && rm /tmp/archive.md5 \
    && tar xf archive.tar.xz \
    && rm archive.tar.xz \
    && ln -s arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi/bin/arm-none-eabi-gcc /usr/bin/arm-none-eabi-gcc \
    && ln -s arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi/bin/arm-none-eabi-g++ /usr/bin/arm-none-eabi-g++ \
    && ln -s arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi/bin/arm-none-eabi-gdb /usr/bin/arm-none-eabi-gdb \
    && ln -s arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi/bin/arm-none-eabi-size /usr/bin/arm-none-eabi-size \
    && ln -s arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi/bin/arm-none-eabi-objcopy /usr/bin/arm-none-eabi-objcopy \
    && ln -s arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi/bin/arm-none-eabi-objdump /usr/bin/arm-none-eabi-objdump \
    && pip3 install git+https://github.com/HBehrens/puncover --break-system-packages

#
# --- Remove 'ubuntu' user, create 'user' user and become it ---
#
RUN userdel -r ubuntu \
    && groupadd -g $GID -o user \
    && mkdir -p /etc/sudoers.d && useradd -u $UID -m -g user -G plugdev user \
    && echo 'user ALL = NOPASSWD: ALL' > /etc/sudoers.d/user \
    && chmod 0440 /etc/sudoers.d/user \
    && usermod -a -G dialout user \
    && chsh --shell /bin/bash user
USER user
WORKDIR /home/user/west_workspace

#
# --- Python wirtual environment ---
#
ENV VIRTUAL_ENV=/home/user/west_workspace/pyEnv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

#
# --- pyOCD packs for flashing/debugging ---
#
RUN pip3 install pyocd \
    && pyocd pack install stm32h5 nrf52840 nrf91

#
# --- Initialize west workspace including zephyr-project ---
#
RUN --mount=type=bind,source=./zephyr-box/west_base.yml,target=./project/west.yml \
    pip3 install west \
    && west init -l ./project \
    && west update \
    # default board:
    && west config build.board stm32h573i_dk \
    && west zephyr-export
ENV ZEPHYR_BASE=/home/user/west_workspace/zephyr
ENV QEMU_EXTRA_FLAGS="-serial pty"

#
# --- Pip packages required by zephyr ---
#
RUN pip3 install -r $ZEPHYR_BASE/scripts/requirements.txt

#
# --- Load west workspace: volatile but sped up by previous step ---
#
WORKDIR /home/user/west_workspace
RUN --mount=type=bind,source=west.yml,target=./project/west.yml \
    cd ./project \
    && west update \
    && cd ..

#
# --- Pip packages required by mainfest-revision zephyr ---
#
RUN pip3 install -r $ZEPHYR_BASE/scripts/requirements.txt

#
# --- Pip packages required by project ---
#
RUN --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
    pip3 install --requirement /tmp/requirements.txt

CMD ["bash"]
