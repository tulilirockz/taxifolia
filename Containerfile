FROM scratch AS ctx

COPY build.sh /build.sh

FROM quay.io/centos-bootc/centos-bootc:c10s@sha256:812128e7ae86fd375c8c229e3d8f6b3048b4b31578f76556fe8df76d22425af1

RUN --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/boot \
    --mount=type=tmpfs,dst=/run \
    --mount=type=bind,from=ctx,source=/,dst=/tmp/build-scripts \
    /tmp/build-scripts/build.sh

RUN rm -rf /var/* && bootc container lint --fatal-warnings
