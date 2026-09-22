FROM golang:1.25-alpine AS tools

WORKDIR /src
COPY cmd/nc/main.go /src/nc/main.go

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags='-s -w' -o /out/nc /src/nc/main.go


FROM alpine:3.22

LABEL org.opencontainers.image.title="Shopware Dev Runtime" \
      org.opencontainers.image.description="Runtime helpers for Aggrosoft Shopware development instances" \
      org.opencontainers.image.source="https://github.com/aggrosoft/shopware-dev-runtime"

COPY --from=tools /out/nc /runtime/bin/nc
COPY --chmod=0755 scripts/ /runtime/
COPY --chmod=0755 install-runtime.sh /usr/local/bin/install-shopware-dev-runtime

ENTRYPOINT ["/usr/local/bin/install-shopware-dev-runtime"]
