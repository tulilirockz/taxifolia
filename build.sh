#!/usr/bin/env bash

set -xeuo pipefail

tee /usr/lib/systemd/journald.conf.d/99-audit.conf <<'EOF'
[Journal]
Audit=yes
ReadKMsg=yes
EOF

systemctl enable sshd
systemctl enable podman-auto-update.timer
systemctl enable --global podman-auto-update.timer

# Unsure why removing nfs-utils is annoying here
mkdir -p /var/lib/rpm-state/
touch /var/lib/rpm-state/nfs-server.cleanup

dnf -y remove \
  NetworkManager \
  adcli \
  bash-completion \
  bind-utils \
  chrony \
  cloud-utils-growpart \
  criu* \
  efibootmgr \
  ethtool \
  flatpak-session-helper \
  jq \
  libdnf-plugin-subscription-manager \
  nano \
  net-tools \
  nfs-server \
  nfs-utils \
  pkg-config* \
  python3-cloud-what \
  python3-subscription-manager-rhsm \
  socat \
  sos \
  sssd* \
  stalld \
  subscription-manager \
  subscription-manager-rhsm-certificates \
  sudo-python-plugin \
  toolbox \
  virt-what \
  yggdrasil*

dnf -y install --setopt=install_weak_deps=False \
  audit \
  audit-libs \
  audit-rules \
  console-login-helper-messages \
  console-login-helper-messages-issuegen \
  console-login-helper-messages-motdgen \
  console-login-helper-messages-profile \
  firewalld \
  git-core \
  greenboot \
  ppp \
  rsync \
  systemd-oomd \
  systemd-resolved \
  tcpdump \
  traceroute \
  udisks2-lvm2 \
  xdg-user-dirs

systemctl enable auditd
systemctl enable firewalld

dnf -y install epel-release
dnf config-manager --set-disabled epel
dnf -y install --enablerepo="epel" \
  just \
  systemd-networkd \
  systemd-networkd-defaults \
  systemd-timesyncd

systemctl enable systemd-networkd
systemctl enable systemd-timesyncd

sed -i 's|^ExecStart=.*|ExecStart=/usr/bin/bootc update --quiet|' /usr/lib/systemd/system/bootc-fetch-apply-updates.service
sed -i 's|^OnUnitInactiveSec=.*|OnUnitInactiveSec=7d\nPersistent=true|' /usr/lib/systemd/system/bootc-fetch-apply-updates.timer
sed -i 's|#AutomaticUpdatePolicy.*|AutomaticUpdatePolicy=stage|' /etc/rpm-ostreed.conf
sed -i 's|#LockLayering.*|LockLayering=true|' /etc/rpm-ostreed.conf

systemctl enable bootc-fetch-apply-updates

tee /usr/lib/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram, 8192)
EOF
tee /usr/lib/sysctl.d/99-rcore-memmax.conf <<'EOF'
# Required for unprivileged unbound
net.core.rmem_max=262144
EOF
tee /usr/lib/sysctl.d/99-forwarding <<'EOF'
# Kernel needs to be happy for ipv6 assignment on LAN devices
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
EOF
tee /usr/lib/systemd/system-preset/91-resolved-default.preset <<'EOF'
enable systemd-resolved.service
EOF
tee /usr/lib/tmpfiles.d/resolved-default.conf <<'EOF'
L /etc/resolv.conf - - - - ../run/systemd/resolve/stub-resolv.conf
EOF

systemctl preset systemd-resolved.service

KERNEL_VERSION="$(find "/usr/lib/modules" -maxdepth 1 -type d ! -path "/usr/lib/modules" -exec basename '{}' ';' | sort | tail -n 1)"
export DRACUT_NO_XATTR=1
dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --zstd -v --add ostree -f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"
chmod 0600 "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"
