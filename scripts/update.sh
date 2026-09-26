#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
upstream="${1:-ghcr.io/museofficial/muse:2.11.8}"
image="${2:-muse-pelican:local}"
docker build --pull --build-arg "MUSE_IMAGE=$upstream" --tag "$image" .
bash tests/smoke.sh "$image"
printf '\nBuilt and checked %s from %s. Push it to your registry and select that image in Pelican.\n' "$image" "$upstream"
