#!/usr/bin/env bash

set -xeuo pipefail

dnf -y remove \
  libdnf-plugin-subscription-manager \
  python3-subscription-manager-rhsm \
  subscription-manager \
  subscription-manager-rhsm-certificates

dnf -y install --setopt=install_weak_deps=False \
  atheros-firmware \
  audit \
  brcmfmac-firmware \
  cockpit-machines \
  cockpit-networkmanager \
  cockpit-podman \
  cockpit-selinux \
  cockpit-storaged \
  cockpit-system \
  firewalld \
  git-core \
  hdparm \
  ipcalc \
  iwlegacy-firmware \
  iwlwifi-dvm-firmware \
  iwlwifi-mvm-firmware \
  libvirt-client \
  libvirt-daemon \
  libvirt-daemon-kvm \
  man-db \
  man-pages \
  mt7xxx-firmware \
  NetworkManager-wifi \
  nxpwireless-firmware \
  open-vm-tools \
  pcp-zeroconf \
  qemu-guest-agent \
  realtek-firmware \
  rsync \
  systemd-container \
  tiwilink-firmware \
  usbutils \
  virt-install \
  wireguard-tools \
  xdg-dbus-proxy \
  xdg-user-dirs \

dnf config-manager --add-repo https://pkgs.tailscale.com/stable/centos/"$(rpm -E %centos)"/tailscale.repo
dnf config-manager --set-disabled tailscale-stable

dnf -y install --enablerepo='tailscale-stable' tailscale

dnf -y copr enable ublue-os/packages
dnf -y copr disable ublue-os/packages
dnf -y install --enablerepo="copr:copr.fedorainfracloud.org:ublue-os:packages" --setopt=install_weak_deps=False \
    ublue-os-libvirt-workarounds

install -Dpm0644 -t /usr/lib/systemd /tmp/files/usr/lib/systemd/zram-generator.conf
install -Dpm0644 -t /usr/lib/systemd/system /tmp/files/usr/lib/systemd/system/cockpit.service

sed -i 's|^ExecStart=.*|ExecStart=/usr/bin/bootc update --quiet|' /usr/lib/systemd/system/bootc-fetch-apply-updates.service
sed -i 's|^OnUnitInactiveSec=.*|OnUnitInactiveSec=7d\nPersistent=true|' /usr/lib/systemd/system/bootc-fetch-apply-updates.timer
sed -i 's|#AutomaticUpdatePolicy.*|AutomaticUpdatePolicy=stage|' /etc/rpm-ostreed.conf
sed -i 's|#LockLayering.*|LockLayering=true|' /etc/rpm-ostreed.conf

systemctl enable firewalld

cat >/usr/lib/systemd/system-preset/91-resolved-default.preset <<'EOF'
enable systemd-resolved.service
EOF
cat >/usr/lib/tmpfiles.d/resolved-default.conf <<'EOF'
L /etc/resolv.conf - - - - ../run/systemd/resolve/stub-resolv.conf
EOF

systemctl preset systemd-resolved.service

systemctl enable tailscaled

KERNEL_VERSION="$(rpm -q --queryformat="%{EVR}.%{ARCH}" kernel-core)"
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --zstd -v --add ostree -f "/lib/modules/$KERNEL_VERSION/initramfs.img"
chmod 0600 /lib/modules/"$KERNEL_VERSION"/initramfs.img
KERNEL_VERSION="$(rpm -q kernel-core --queryformat '%{EVR}.%{ARCH}')"

kernel_dirs=("$(ls -1 /usr/lib/modules)")
if [[ ${#kernel_dirs[@]} -gt 1 ]]; then
    for kernel_dir in "${kernel_dirs[@]}"; do
        echo "$kernel_dir"
        if [[ "$kernel_dir" != "$KERNEL_VERSION" ]]; then
            echo "Removing $kernel_dir"
            rm -rf "/usr/lib/modules/$kernel_dir"
        fi
    done
fi

bootc container lint
