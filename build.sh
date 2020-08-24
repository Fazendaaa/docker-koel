#!/usr/bin/sh
docker buildx build --platform linux/amd64 --push --tag fazenda/koel .
# ,linux/arm/v7,linux/arm/v6,linux/arm64/v8,linux/ppc64le,linux/s390x,linux/386
