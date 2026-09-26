#!/usr/bin/env bash
set -euo pipefail
image="${1:-muse-pelican:local}"
volume="muse-pelican-test-$$-$RANDOM"
docker volume create "$volume" >/dev/null
trap 'docker volume rm "$volume" >/dev/null' EXIT

docker run --rm --entrypoint /bin/sh "$image" -ec '
  test "$(id -un)" = container
  test "$HOME" = /home/container
  test "$PWD" = /home/container
  node -e "const [a,b]=process.versions.node.split(\".\").map(Number); if(a<22 || (a===22 && b<12)) process.exit(1)"
  ffmpeg -version >/dev/null
  /opt/yt-dlp/bin/yt-dlp --version
  /opt/yt-dlp/bin/python -c "import yt_dlp_ejs"
  cd /usr/app
  node_modules/.bin/prisma --version
  node -e "require(\"@discordjs/opus\"); require(\"@prisma/client\")"
'
# Fail before network access if credentials are missing; never print secret values.
if output="$(docker run --rm "$image" 2>&1)"; then
  echo 'Expected failure without credentials' >&2; exit 1
fi
[[ "$output" == *'Set DISCORD_TOKEN'* ]]
if output="$(docker run --rm -e DISCORD_TOKEN=test "$image" 2>&1)"; then
  echo 'Expected failure without YouTube key' >&2; exit 1
fi
[[ "$output" == *'Set YOUTUBE_API_KEY'* ]]
if output="$(docker run --rm -e DISCORD_TOKEN=test -e YOUTUBE_API_KEY=test -e SPOTIFY_CLIENT_ID=test "$image" 2>&1)"; then
  echo 'Expected failure with incomplete Spotify credentials' >&2; exit 1
fi
[[ "$output" == *'Set both Spotify credentials'* ]]
if output="$(docker run --rm -e DISCORD_TOKEN=test -e YOUTUBE_API_KEY=test -e YT_DLP_COOKIES_PATH=/missing "$image" 2>&1)"; then
  echo 'Expected failure with missing cookie file' >&2; exit 1
fi
[[ "$output" == *'readable cookie file'* ]]

# Exercise real SQLite migrations twice across distinct containers, as non-root.
docker run --rm --user root --entrypoint /bin/sh -v "$volume:/home/container" "$image" -ec '
  mkdir -p /home/container/data
  chown -R container:container /home/container
'
for attempt in 1 2; do
  docker run --rm --entrypoint /bin/sh -v "$volume:/home/container" \
    -e DATABASE_URL=file:/home/container/data/smoke.sqlite "$image" -ec '
      cd /usr/app
      node_modules/.bin/prisma migrate deploy
      test -s /home/container/data/smoke.sqlite
      node --input-type=module -e '"'"'
        import Prisma from "@prisma/client";
        const db = new Prisma.PrismaClient();
        await db.$queryRawUnsafe("SELECT COUNT(*) FROM _prisma_migrations");
        await db.$disconnect();
      '"'"'
    '
done
echo 'Image dependencies, configuration failures and persistent migrations passed.'
