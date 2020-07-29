docker buildx build --platform linux/amd64,linux/arm64/v8,linux/ppc64le,linux/386 --push --tag fazenda/koel .
docker buildx imagetools inspect fazenda/koel
