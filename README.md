# Muse for Pelican

A small Pelican adapter around the official Muse Docker image. Muse remains upstream code; you do not need to maintain a bot fork to get future Muse releases.

**Status:** prepared against Muse v2.11.8 (current release checked on 2026-09-26). Egg JSON and package consistency were checked locally. Docker build, Linux smoke tests, Pelican import and live Discord playback have NOT been run here: the local Docker daemon is unavailable and no Pelican server or bot credentials were provided. Run the supplied build checks before production use.

## Files

- `egg-muse.json`: importable Pelican PLCN_v1 egg; initially points at locally built `muse-pelican:local`.
- `Dockerfile`, `entrypoint.sh`: official Muse image adapted to Pelican.
- `install.sh`: non-destructive data directory initialization, also embedded in the egg.
- `scripts/update.sh`: rebuild from a chosen upstream image and run smoke checks.
- `tests/smoke.sh`: dependencies, missing configuration and real SQLite migration checks.
- `.github/workflows/build.yml`: manually build, check and publish to GHCR, then download an egg containing the exact published image name.

## What was wrong with the old egg

The [original egg](https://github.com/pelican-eggs/chatbots/blob/main/discord/muse/egg-muse.json) refers to BOT_TOKEN although its variable is DISCORD_TOKEN, and maps SPOTIFY_CLIENT_SECRET to a second SPOTIFY_CLIENT_ID line. These are configuration errors, although process environment variables can mask some effects.

It deletes all files except data before validating a download, checks only whether the downloaded file exists, silently falls back to latest for an unknown version, and uses a moving installer Node LTS tag with a Node 22 runtime. It installs only production dependencies even though Muse calls the Prisma CLI declared as a development dependency. It also does not explicitly provision the yt-dlp + JavaScript extraction dependencies now required by Muse.

This adapter uses upstream's built image with Node, FFmpeg, yt-dlp and EJS already included, ensures the Prisma CLI matches the generated client, and uses panel environment variables directly. Code stays in /usr/app; data stays in /home/container/data. No dependency download or source update runs when the bot starts. The process runs as container, with Tini forwarding stop signals.

## Option A: build on your Linux Wings host

Requires Docker and Bash. Run these commands from this package directory:

```bash
bash scripts/update.sh ghcr.io/museofficial/muse:2.11.8 muse-pelican:local
```

Import egg-muse.json under Pelican's administration egg management. Create a server using this egg and image. The image must exist on **every Wings node** that can run the server. If Wings requires a registry pull, use Option B or push the image to your own registry and change the egg/server image accordingly.

Enter DISCORD_TOKEN and YOUTUBE_API_KEY under Startup. Spotify is optional; enter both fields or leave both empty. Keep the startup command exactly /entrypoint.sh. Start the server, wait for “Ready! Invite the bot with”, then follow the logged invite URL.

Start with 1 GiB RAM and disk space above your cache limit (default cache: 2 GB); tune for your usage. Pelican may require an allocation, but Muse does not serve a public listening port. The host needs outbound HTTPS plus Discord voice TCP/UDP connectivity.

## Option B: publish with GitHub Actions

1. Create your own GitHub repository and upload **all** package files, including .github and .gitattributes.
2. In Actions, manually run “Build Muse for Pelican” with upstream_tag = 2.11.8.
3. The workflow builds and smoke-tests a linux/amd64 image before publishing it to ghcr.io/YOUR-OWNER/YOUR-REPO:2.11.8-pelican-RUN-NUMBER.
4. Make the GHCR package public, or configure registry authentication on your Wings nodes.
5. Download the muse-pelican-egg artifact and import egg-muse-built.json into Pelican.

No registry image has been published by this chat. Workflow publishing needs repository Actions package-write permission. ARM64 builds are not configured or validated by this workflow.

## Move an existing Muse server

1. Stop the bot and take a full Pelican backup. Download a copy outside the server.
2. Record existing startup settings, token and image. Keep the same Discord token to retain the bot identity.
3. Confirm the existing database/cache is in the server's data folder. If you used another DATA_DIR, copy its complete contents into data while stopped.
4. Build/publish the new image, then change the server's egg, image and startup command. Review the variables after changing eggs.
5. Run the new egg's installation if Pelican requires it. It only creates data if absent; it does not delete or overwrite existing files.
6. Start and confirm migrations complete, “Ready!” appears, and a real track plays in Discord. Test stop/start and check settings survive.

Old application files and .env may remain in the server volume but are not used. The adapter intentionally forces ENV_FILE=/dev/null and DATA_DIR=/home/container/data and clears DATABASE_URL, so stale settings cannot redirect the database. Transfer custom environment settings into the new egg if needed. Panel variables and backups may contain secrets; give access only to trusted operators.

## Update from the original Muse project

Check [upstream releases](https://github.com/museofficial/muse/releases). Choose an exact supported image tag, then run Option A with that image or manually rerun Option B with its tag. Use a **new output image tag for each build**.

Example for a refreshed yt-dlp build:

```bash
bash scripts/update.sh ghcr.io/museofficial/muse:yt-dlp-latest ghcr.io/YOUR-OWNER/muse-pelican:refresh-1
docker push ghcr.io/YOUR-OWNER/muse-pelican:refresh-1
```

Replace YOUR-OWNER with your lowercase registry account and log in before pushing. Back up the stopped server, select the newly published image in Pelican (add it to the egg's allowed images first), and start. The data directory survives image changes. You do not need to reinstall or git pull inside the server.

The moving latest/yt-dlp-latest tags are useful for testing but exact tags or image digests are easier to reproduce. Even an exact upstream Muse tag can be republished; use a digest for a strict pin. The bundled yt-dlp is read-only to the runtime user; YT_DLP_AUTO_UPDATE is forced off. Refresh it by rebuilding from an upstream yt-dlp refresh image.

Database migrations may make an old application image incompatible with the upgraded database. Roll back by restoring the stopped-server backup **and** selecting the previous image.

If you later want custom bot features, keep those in a Muse fork with museofficial/muse as the upstream Git remote. Merge upstream changes in that fork, run Muse's tests, publish its image, and pass that image as MUSE_IMAGE. The adapter assumes the upstream layout (/usr/app, Node 22+, compiled migrate-and-start script, generated Prisma client, /opt/yt-dlp) remains compatible; review and smoke-test on upgrades.

## Optional configuration

Cache limit, SponsorBlock, Discord presence, global command registration and YouTube cookies are exposed in the egg. For STREAMING activity, also set BOT_ACTIVITY_URL.

Upload YouTube-only Netscape cookies to secrets/youtube-cookies.txt and set YT_DLP_COOKIES_PATH=/home/container/secrets/youtube-cookies.txt, or use an administrator-managed read-only secret mount. The cookie file is sensitive and may be included in panel backups. Do not commit it or include it in image builds.

## Validation and troubleshooting

Run `bash tests/smoke.sh IMAGE` after every build. It exercises a real non-root Prisma client against migrations in a persistent Docker volume. It does not contact Discord or prove audio playback.

- Missing credentials: enter variables in Pelican, not in .env.
- Wrong startup: set /entrypoint.sh after switching from the old egg.
- Permissions: ensure Wings owns the server volume correctly; do not use chmod 777.
- Prisma or image-layout build failure: review the selected upstream release; the build intentionally fails rather than guessing a new layout.
- Playback failure: check outbound Discord voice connectivity and upstream yt-dlp extraction logs. Never paste tokens or cookies into issue reports.
- Cannot pull image: publish it and configure visibility/credentials, or build the local tag on the actual Wings node.

## Sources and attribution

- [Muse v2.11.8](https://github.com/museofficial/muse/releases/tag/v2.11.8), [upstream Dockerfile](https://github.com/museofficial/muse/blob/v2.11.8/Dockerfile), and [configuration](https://github.com/museofficial/muse/blob/v2.11.8/src/services/config.ts).
- [Pelican custom image requirements](https://pelican.dev/docs/eggs/creating-a-custom-yolk/).
- Original egg authors: David Wolfe (Red-Thirten), TubaApollo and parkervcp. The egg retains its original author field for attribution; this adaptation is not an official upstream release.
- Muse and the original egg retain their upstream licenses. This package does not vendor Muse source.
