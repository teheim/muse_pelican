#!/bin/sh
set -eu
umask 077
fail() { printf '%s\n' "Muse startup error: $*" >&2; exit 1; }

# This egg has one fixed startup command; never eval panel variables or secrets.
[ "${STARTUP:-/entrypoint.sh}" = "/entrypoint.sh" ] ||
    fail "Set the Pelican startup command to /entrypoint.sh."
[ -n "${DISCORD_TOKEN:-}" ] || fail "Set DISCORD_TOKEN in Pelican Startup."
[ -n "${YOUTUBE_API_KEY:-}" ] || fail "Set YOUTUBE_API_KEY in Pelican Startup."
if [ -n "${SPOTIFY_CLIENT_ID:-}" ] || [ -n "${SPOTIFY_CLIENT_SECRET:-}" ]; then
    [ -n "${SPOTIFY_CLIENT_ID:-}" ] && [ -n "${SPOTIFY_CLIENT_SECRET:-}" ] ||
        fail "Set both Spotify credentials, or leave both empty."
fi

# Ignore stale .env files from the old egg. Panel variables are authoritative.
export DATA_DIR=/home/container/data ENV_FILE=/dev/null CI=true
export YT_DLP_AUTO_UPDATE=false
# Prevent accidental use of a database outside the persistent data directory.
unset DATABASE_URL
mkdir -p "$DATA_DIR" || fail "Cannot create data directory; check server volume ownership."
[ -w "$DATA_DIR" ] || fail "Data directory is not writable by the container user."
if [ -n "${YT_DLP_COOKIES_PATH:-}" ]; then
    [ -f "$YT_DLP_COOKIES_PATH" ] && [ -r "$YT_DLP_COOKIES_PATH" ] ||
        fail "YT_DLP_COOKIES_PATH must point to a readable cookie file."
fi
cd /usr/app
printf 'Muse %s | Node %s\n' "$(node -p "require('./package.json').version")" "$(node --version)"
# Migrations run before Discord login. Tini forwards panel stop signals.
exec node --enable-source-maps dist/scripts/migrate-and-start.js
