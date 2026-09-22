#!/bin/sh
set -eu

if [ -z "${SSH_PASSWORD:-}" ] && [ -z "${SSH_AUTHORIZED_KEYS:-}" ]; then
    printf '%s\n' 'Set SSH_PASSWORD and/or SSH_AUTHORIZED_KEYS.' >&2
    exit 1
fi

export SSH_USER=developer

if [ -n "${SSH_PASSWORD:-}" ]; then
    export SSH_PWD="$SSH_PASSWORD"
else
    export SSH_PWD="$(openssl rand -hex 32)"
fi

export BASH_ENV=/dev/null

sudo ln -sf /opt/aggro/boot-end.sh /var/www/boot_end.sh

exec /bin/bash /entrypoint.sh "$@"
