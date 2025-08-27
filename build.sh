#!/usr/bin/env bash

set -xeuo pipefail

systemctl enable sshd
systemctl enable podman-auto-update.timer
systemctl enable --global podman-auto-update.timer

dnf -y remove \
  adcli \
  libdnf-plugin-subscription-manager \
  python3-subscription-manager-rhsm \
  subscription-manager \
  subscription-manager-rhsm-certificates \
  toolbox \
  yggdrasil

dnf -y install --setopt=install_weak_deps=False \
  cockpit-machines \
  cockpit-networkmanager \
  cockpit-podman \
  cockpit-selinux \
  cockpit-storaged \
  cockpit-system \
  firewalld \
  git-core \
  libvirt-client \
  libvirt-daemon \
  libvirt-daemon-kvm \
  NetworkManager-wifi \
  open-vm-tools \
  pcp-zeroconf \
  qemu-guest-agent \
  rsync \
  systemd-resolved \
  udisks2-lvm2 \
  virt-install \
  xdg-user-dirs

systemctl enable firewalld

dnf config-manager --add-repo "https://pkgs.tailscale.com/stable/centos/$(rpm -E %centos)/tailscale.repo"
dnf config-manager --set-disabled tailscale-stable
dnf -y install --enablerepo='tailscale-stable' tailscale
systemctl enable tailscaled

dnf -y copr enable ublue-os/packages
dnf -y copr disable ublue-os/packages
dnf -y install --enablerepo="copr:copr.fedorainfracloud.org:ublue-os:packages" --setopt=install_weak_deps=False \
    ublue-os-libvirt-workarounds

dnf -y install epel-release
dnf config-manager --set-disabled epel
dnf -y install --enablerepo="epel" just

tee /usr/lib/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = min(ram, 8192)
EOF

sed -i 's|^ExecStart=.*|ExecStart=/usr/bin/bootc update --quiet|' /usr/lib/systemd/system/bootc-fetch-apply-updates.service
sed -i 's|^OnUnitInactiveSec=.*|OnUnitInactiveSec=7d\nPersistent=true|' /usr/lib/systemd/system/bootc-fetch-apply-updates.timer
sed -i 's|#AutomaticUpdatePolicy.*|AutomaticUpdatePolicy=stage|' /etc/rpm-ostreed.conf
sed -i 's|#LockLayering.*|LockLayering=true|' /etc/rpm-ostreed.conf

cat >/usr/lib/systemd/system-preset/91-resolved-default.preset <<'EOF'
enable systemd-resolved.service
EOF
cat >/usr/lib/tmpfiles.d/resolved-default.conf <<'EOF'
L /etc/resolv.conf - - - - ../run/systemd/resolve/stub-resolv.conf
EOF
systemctl preset systemd-resolved.service

KERNEL_VERSION="$(find "/usr/lib/modules" -maxdepth 1 -type d ! -path "/usr/lib/modules" -exec basename '{}' ';' | sort | tail -n 1)"
export DRACUT_NO_XATTR=1
dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --zstd -v --add ostree -f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"
chmod 0600 "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"
