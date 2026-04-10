FROM alpine:3.21

RUN apk add --no-cache \
    bash \
    coreutils \
    findutils \
    unzip \
    zip \
    curl

WORKDIR /app
COPY pack-ensemble.sh /app/pack-ensemble.sh
COPY templ /app/templ
RUN chmod +x /app/pack-ensemble.sh

WORKDIR /work
ENTRYPOINT ["/app/pack-ensemble.sh"]
