FROM ghcr.io/shopware/shopware-cli:bin AS shopware_cli

FROM alpine:3.22

LABEL org.opencontainers.image.title="Shopware Dev Runtime" \
      org.opencontainers.image.description="Runtime helpers for Aggrosoft Shopware development instances" \
      org.opencontainers.image.source="https://github.com/aggrosoft/shopware-dev-runtime"

COPY --from=shopware_cli --chmod=0755 /shopware-cli /runtime/bin/shopware-cli
COPY --chmod=0755 scripts/ /runtime/
COPY templates/ /runtime/templates/
COPY --chmod=0755 install-runtime.sh /usr/local/bin/install-shopware-dev-runtime

ENTRYPOINT ["/usr/local/bin/install-shopware-dev-runtime"]
