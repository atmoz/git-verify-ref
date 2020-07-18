FROM debian:buster-slim

RUN apt update && \
    apt install -y git gnupg && \
    rm -rf /var/lib/apt/lists/*

COPY ./entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/public-keys"]
