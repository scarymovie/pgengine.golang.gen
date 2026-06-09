# pGenie CLI image for the e2e test (see e2e/run.sh).
# The pgn binary is downloaded from the official release during the build,
# so no local binaries are required.
FROM debian:trixie-slim

ARG PGN_VERSION=0.6.2

RUN apt-get update \
 && apt-get install -y --no-install-recommends libpq5 ca-certificates curl \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL "https://github.com/pgenie-io/pgenie/releases/download/v${PGN_VERSION}/pgn-linux-x64.tar.gz" \
    | tar xz -C /usr/local/bin \
 && chmod +x /usr/local/bin/pgn

# pgn prints dhall error messages with unicode arrows; without a UTF-8
# locale that crashes the error reporting itself.
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

WORKDIR /project
ENTRYPOINT ["pgn"]
