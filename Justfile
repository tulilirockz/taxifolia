image := env("IMAGE_NAME", "localhost/taxifolia:latest")
filesystem := env("BUILD_FILESYSTEM", "ext4")

default: build load ostree-rechunk

build:
    mkosi -B

load:
    #!/usr/bin/env bash
    set -x
    sudo podman load -i "$(find mkosi.profiles/bootc-ostree/mkosi.output/* -maxdepth 0 -type d -printf "%T@ ,%p\n" -iname "_*" -print0 | sort -n | head -n1 | cut -d, -f2)" -q | cut -d: -f3 | xargs -I{} sudo podman tag {} {{image}}

ostree-rechunk:
    #!/usr/bin/env bash
    sudo podman run --rm \
          --privileged \
          -t \
          -v /var/lib/containers:/var/lib/containers \
          "quay.io/centos-bootc/centos-bootc:stream10" \
          /usr/libexec/bootc-base-imagectl rechunk \
          "{{image}}" \
          "{{image}}" || exit 1

bootc *ARGS:
    sudo podman run \
        --rm --privileged --pid=host \
        -it \
        -v /sys/fs/selinux:/sys/fs/selinux \
        -v /etc/containers:/etc/containers:Z \
        -v /var/lib/containers:/var/lib/containers:Z \
        -v /dev:/dev \
        -v "${BUILD_BASE_DIR:-.}:/data" \
        --security-opt label=type:unconfined_t \
        "{{image}}" bootc {{ARGS}}

disk-image $filesystem=filesystem:
    #!/usr/bin/env bash
    if [ ! -e "${BUILD_BASE_DIR:-.}/bootable.img" ] ; then
        fallocate -l 20G "${BUILD_BASE_DIR:-.}/bootable.img"
    fi
    just bootc install to-disk --via-loopback /data/bootable.img --filesystem "${filesystem}" --wipe
rechunk:
    #!/usr/bin/env bash
    IMG="{{ image }}"
    # podman pull $IMG # image must be available locally
    export CHUNKAH_CONFIG_STR=$(sudo podman inspect $IMG)
    sudo podman run --rm --mount=type=image,src=$IMG,dest=/chunkah -e CHUNKAH_CONFIG_STR quay.io/jlebon/chunkah build --label ostree.bootable=1 | sudo podman load
