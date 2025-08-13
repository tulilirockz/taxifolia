FROM scratch AS ctx

COPY files /files
COPY build-scripts /build-scripts

FROM quay.io/centos-bootc/centos-bootc:c10s

RUN --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/boot \
    --mount=type=tmpfs,dst=/run \
    --mount=type=bind,from=ctx,source=/build-scripts,dst=/tmp/build-scripts \
    --mount=type=bind,from=ctx,source=/files,dst=/tmp/files \
    /tmp/build-scripts/build.sh
