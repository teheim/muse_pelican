#!/bin/sh
set -eu
# Application code and dependencies live in the image, outside the server mount.
# Wings handles volume ownership. Preserve existing data, cookies and other files.
mkdir -p /mnt/server/data
printf '%s\n' 'Muse data directory is ready. Select the matching Muse Pelican image.'
