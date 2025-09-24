## This tag does not exist: https://github.com/rancher/elemental-toolkit/issues/2328
# FROM ghcr.io/rancher/elemental-toolkit/elemental-cli:v2.2.5 AS toolkit

# run `make build` to build local/elemental-toolkit image
ARG TOOLKIT_IMAGE=local/elemental-toolkit:v2.2.5
FROM ${TOOLKIT_IMAGE} AS toolkit

# OS base image of our choice
FROM ubuntu:24.04 AS os

# install kernel, systemd, dracut, grub2 and other required tools
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    apparmor \
    bash-completion \
    bridge-utils \
    btrfsmaintenance \
    btrfs-progs \
    ca-certificates \
    curl \
    dbus-daemon \
    dmsetup \
    dosfstools \
    dracut-core \
    dracut-live \
    dracut-network \
    dracut-squash \
    e2fsprogs \
    eject \
    findutils \
    fdisk \
    gdisk \
    grub2-common \
    grub-efi-amd64 \
    haveged \
    htop \
    iproute2 \
    ipset \
    iptables \
    iputils-ping \
    kbd \
    kmod \
    less \
    linux-generic \
    locales \
    lvm2 \
    mtools \
    netplan.io \
    net-tools \
    nfs-common \
    open-iscsi \
    openssh-client \
    openssh-server \
    parted \
    patch \
    psmisc \
    rsync \
    shim \
    shim-signed \
    squashfs-tools \
    sudo \
    systemd \
    systemd-resolved \
    systemd-sysv \
    systemd-timesyncd \
    tzdata \
    vim \
    wget \
    xorriso \
    xz-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Use legacy iptables because Docker does not have native support for nftables
# https://github.com/moby/moby/issues/49634
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy \
    && update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# Include iSCSI performance optimizations
COPY iscsid.conf /etc/iscsi/

# Hack to prevent systemd-firstboot failures while setting keymap, this is known
# Debian issue (T_T) https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=790955
ARG KBD=2.6.4
RUN curl -L https://mirrors.edge.kernel.org/pub/linux/utils/kbd/kbd-${KBD}.tar.xz --output kbd-${KBD}.tar.xz \
    && tar xaf kbd-${KBD}.tar.xz \
    && mkdir -p /usr/share/keymaps \
    && cp -Rp kbd-${KBD}/data/keymaps/* /usr/share/keymaps/ \
    && rm kbd-${KBD}.tar.xz

# Symlink grub2-editenv
RUN ln -sf /usr/bin/grub-editenv /usr/bin/grub2-editenv

# Just add the elemental cli
COPY --from=toolkit /usr/bin/elemental /usr/bin/elemental

# Enable essential services
RUN systemctl enable systemd-networkd.service

# Enable /tmp to be on tmpfs
RUN cp /usr/share/systemd/tmp.mount /etc/systemd/system

# Generate en_US.UTF-8 locale, this the locale set at boot by
# the default cloud-init
RUN locale-gen --lang en_US.UTF-8

# Hide some useless default infos on login
RUN rm -f /etc/update-motd.d/10-help-text \
    && rm -f /etc/update-motd.d/50-motd-news \
    && rm -f /etc/update-motd.d/60-unminimize

# Add configuration
COPY config.yaml /etc/elemental/

# Generate initrd with required elemental services
RUN elemental --debug init -f

# Store version number
ARG VERSION
ENV VERSION=${VERSION}
RUN echo IMAGE_TAG=\"${VERSION}\" >> /etc/os-release \
    && sed -i -e "s/__VERSION__/$VERSION/" /etc/elemental/config.yaml

# Branding
COPY /oem/ /system/oem/
COPY bootargs.cfg /etc/elemental/

# Arrange bootloader binaries into /usr/lib/elemental/bootloader
# this way elemental installer can easily fetch them
RUN mkdir -p /usr/lib/elemental/bootloader && \
    cp /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed /usr/lib/elemental/bootloader/grubx64.efi && \
    cp /usr/lib/shim/shimx64.efi.signed.latest /usr/lib/elemental/bootloader/shimx64.efi && \
    cp /usr/lib/shim/mmx64.efi /usr/lib/elemental/bootloader/mmx64.efi

# Add Docker
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/docker/*

# Good for validation after the build
CMD ["/bin/bash"]
