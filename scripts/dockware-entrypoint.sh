#!/bin/sh
set -eu

if [ -z "${SSH_PASSWORD:-}" ] && [ -z "${SSH_AUTHORIZED_KEYS_B64:-}" ]; then
    printf '%s\n' 'Set SSH_PASSWORD and/or SSH_AUTHORIZED_KEYS_B64.' >&2
    exit 1
fi

export SSH_USER=developer

# Dockware requires a password when it creates its custom SSH user.
# Public-key mode is authenticated by SSHPiper, so use an unknown
# bootstrap password when no user-facing password was configured.
if [ -n "${SSH_PASSWORD:-}" ]; then
    export SSH_PWD="$SSH_PASSWORD"
else
    export SSH_PWD="$(openssl rand -hex 32)"
fi

# Our wrapper runs before Dockware has unpacked NVM.
export BASH_ENV=/dev/null

sudo ln -sf /opt/aggro/boot-end.sh /var/www/boot_end.sh

exec /bin/bash /entrypoint.sh "$@"
