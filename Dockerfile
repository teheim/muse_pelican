# syntax=docker/dockerfile:1
ARG MUSE_IMAGE=ghcr.io/museofficial/muse:2.11.8
FROM ${MUSE_IMAGE}
USER root

# Node's official base already owns UID/GID 1000; reuse it for Pelican.
RUN usermod --login container --home /home/container --move-home node \
    && groupmod --new-name container node \
    && mkdir -p /home/container/data \
    && chown -R container:container /home/container

# Upstream invokes the Prisma CLI at startup, but declares it as a dev dependency.
# Install the exact CLI matching the generated client, independent of prod pruning.
RUN set -eu; \
    version="$(cd /usr/app && node -p "require('@prisma/client').Prisma.prismaVersion.client")"; \
    npm install --prefix /opt/muse-prisma --omit=dev --no-audit --no-fund "prisma@${version}"; \
    mkdir -p /usr/app/node_modules/.bin; \
    ln -sf /opt/muse-prisma/node_modules/.bin/prisma /usr/app/node_modules/.bin/prisma; \
    test -f /usr/app/dist/scripts/migrate-and-start.js; \
    test -x /opt/yt-dlp/bin/yt-dlp

COPY --chmod=755 entrypoint.sh /entrypoint.sh
ENV USER=container HOME=/home/container \
    DATA_DIR=/home/container/data ENV_FILE=/dev/null \
    CI=true NODE_ENV=production YT_DLP_AUTO_UPDATE=false
WORKDIR /home/container
USER container
STOPSIGNAL SIGINT
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/entrypoint.sh"]
