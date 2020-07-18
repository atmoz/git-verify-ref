FROM debian:buster-slim

RUN apt-get update -q && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq git gnupg curl jq && \
    rm -rf /var/lib/apt/lists/*

COPY ./entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
