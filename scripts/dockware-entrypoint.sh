#!/bin/sh
set -eu

export SSH_USER=developer

# Dockware requires SSH_PWD when it creates the custom SSH user.
# If no user-facing password is configured, use an unknown random
# bootstrap password; central SSHPiper key authentication still works.
if [ -n "${SSH_PASSWORD:-}" ]; then
    export SSH_PWD="$SSH_PASSWORD"
else
    export SSH_PWD="$(openssl rand -hex 32)"
fi

# Our wrapper runs before Dockware has unpacked NVM.
export BASH_ENV=/dev/null

sudo ln -sf /opt/aggro/boot-end.sh /var/www/boot_end.sh
sudo ln -sf /opt/aggro/bin/nc /usr/local/bin/nc

exec /bin/bash /entrypoint.sh "$@"
