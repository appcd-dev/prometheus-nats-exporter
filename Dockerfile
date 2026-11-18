# syntax=docker/dockerfile:1
# Hardened prometheus-nats-exporter 0.20.3.
# go.mod requires nats-server v2.15.3. XRAY-1162975 was v2.15.1.
# The published image is one scratch layer, so Alpine zlib is not present.

FROM --platform=$BUILDPLATFORM golang:1.27.3-alpine3.24 AS build

ARG TARGETOS
ARG TARGETARCH

RUN apk add --no-cache ca-certificates tzdata \
    && update-ca-certificates

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .

ENV CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH
RUN go build -trimpath -buildvcs=false \
        -ldflags "-s -w -X main.version=0.20.3" \
        -o /tmp/prometheus-nats-exporter . \
    && go version -m /tmp/prometheus-nats-exporter | grep 'nats-server/v2' | grep -q 'v2.15.3' \
    && if go version -m /tmp/prometheus-nats-exporter | grep 'nats-server/v2' | grep -q 'v2.15.1'; then \
         echo "binary still links nats-server v2.15.1" >&2; exit 1; \
       fi \
    && mkdir -p /out/usr/local/bin /out/etc/ssl/certs /out/usr/share \
    && cp /tmp/prometheus-nats-exporter /out/usr/local/bin/prometheus-nats-exporter \
    && cp /etc/ssl/certs/ca-certificates.crt /out/etc/ssl/certs/ca-certificates.crt \
    && cp -a /usr/share/zoneinfo /out/usr/share/zoneinfo

FROM scratch

COPY --from=build /out/ /

ENV PATH="/usr/local/bin"

EXPOSE 7777

ENTRYPOINT ["prometheus-nats-exporter"]

LABEL org.opencontainers.image.title="prometheus-nats-exporter" \
      org.opencontainers.image.source="https://github.com/nats-io/prometheus-nats-exporter" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="0.20.3"
