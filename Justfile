iso:
    mkdir -p output
    sudo podman pull ghcr.io/tulilirockz/fiskar:latest
    sudo podman run \
        --rm \
        -it \
        --privileged \
        --pull=newer \
        --security-opt label=type:unconfined_t \
        -v ./config.toml:/config.toml:ro \
        -v ./output:/output \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        quay.io/centos-bootc/bootc-image-builder:latest \
        --type iso \
        --use-librepo=True \
        ghcr.io/tulilirockz/fiskar:latest
