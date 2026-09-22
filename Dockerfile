FROM alpine:3.22

LABEL org.opencontainers.image.title="Shopware Dev Runtime" \
      org.opencontainers.image.description="Runtime helpers for Aggrosoft Shopware development instances" \
      org.opencontainers.image.source="https://github.com/aggrosoft/shopware-dev-runtime"

RUN apk add --no-cache ca-certificates curl

RUN mkdir -p /runtime/bin \
    && curl -fsSL \
      https://github.com/openai/codex/releases/latest/download/codex-x86_64-unknown-linux-musl.tar.gz \
      -o /tmp/codex.tar.gz \
    && tar -xzf /tmp/codex.tar.gz -C /tmp \
    && install -m 0755 /tmp/codex-x86_64-unknown-linux-musl /runtime/bin/codex \
    && /runtime/bin/codex --version \
    && rm -f /tmp/codex.tar.gz /tmp/codex-x86_64-unknown-linux-musl

COPY --chmod=0755 scripts/ /runtime/
COPY --chmod=0755 install-runtime.sh /usr/local/bin/install-shopware-dev-runtime

ENTRYPOINT ["/usr/local/bin/install-shopware-dev-runtime"]
