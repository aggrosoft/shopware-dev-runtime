#!/usr/bin/env bash
set -euo pipefail

export HOME=/var/www

# SSHPiper's Docker exec bridge implements direct-tcpip forwarding with nc.
# VS Code Remote SSH needs this for its remote server tunnel.
if ! command -v nc >/dev/null 2>&1; then
    printf '%s\n' 'Installing netcat-openbsd for SSH port forwarding...'
    sudo apt-get update
    sudo env DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --no-install-recommends netcat-openbsd
    sudo rm -rf /var/lib/apt/lists/*
fi

if ! id developer >/dev/null 2>&1; then
    printf '%s\n' 'Expected Dockware SSH user "developer" does not exist.' >&2
    exit 1
fi

# Git identity. Per-instance environment variables can override the defaults.
git_user_name="${GIT_USER_NAME:-Aggrosoft Dev Server}"
git_user_email="${GIT_USER_EMAIL:-dev-server@aggrosoft.de}"

sudo -u developer env HOME=/var/www     git config --global user.name "$git_user_name"

sudo -u developer env HOME=/var/www     git config --global user.email "$git_user_email"

# Keep the Dockware SSH password in sync. In SSHPiper key mode replace
# any previously configured password with a fresh unknown value.
if [[ -n ${SSH_PASSWORD:-} ]]; then
    ssh_password="$SSH_PASSWORD"
else
    ssh_password="$(openssl rand -hex 32)"
fi

printf 'developer:%s\n' "$ssh_password" | sudo chpasswd
unset ssh_password

github_dir="$HOME/.config/aggro-github"

# Configure GitHub App authentication if any app setting is present.
if [[ -n ${GITHUB_APP_CLIENT_ID:-}     || -n ${GITHUB_APP_INSTALLATION_ID:-}     || -n ${GITHUB_APP_PRIVATE_KEY:-} ]]; then

    : "${GITHUB_APP_CLIENT_ID:?GitHub App configuration requires GITHUB_APP_CLIENT_ID}"
    : "${GITHUB_APP_INSTALLATION_ID:?GitHub App configuration requires GITHUB_APP_INSTALLATION_ID}"
    : "${GITHUB_APP_PRIVATE_KEY:?GitHub App configuration requires GITHUB_APP_PRIVATE_KEY}"

    sudo install -d -o developer -g www-data -m 0700 "$github_dir"

    printf '%s\n' "$GITHUB_APP_CLIENT_ID"         | sudo -u developer tee "$github_dir/client-id" >/dev/null

    printf '%s\n' "$GITHUB_APP_INSTALLATION_ID"         | sudo -u developer tee "$github_dir/installation-id" >/dev/null

    printf '%s\n' "$GITHUB_APP_PRIVATE_KEY"         | sudo -u developer tee "$github_dir/private-key.pem" >/dev/null

    sudo chmod 0600         "$github_dir/client-id"         "$github_dir/installation-id"         "$github_dir/private-key.pem"

    sudo -u developer env HOME=/var/www         git config --global credential.helper ''

    sudo -u developer env HOME=/var/www         git config --global --add         credential.helper         /opt/aggro/github-app-credential.sh
fi

# Clone development repositories listed one owner/repo per line.
if [[ -n ${DEV_PLUGINS:-} ]]; then
    if [[ ! -s "$github_dir/client-id"         || ! -s "$github_dir/installation-id"         || ! -s "$github_dir/private-key.pem" ]]; then

        printf '%s\n'             'DEV_PLUGINS is configured but GitHub App credentials are missing.' >&2
        exit 1
    fi

    plugins_dir=/var/www/html/custom/plugins
    sudo install -d -o developer -g www-data -m 0775 "$plugins_dir"

    while IFS= read -r repo || [[ -n "$repo" ]]; do
        repo="$(printf '%s' "$repo" | tr -d '\r' | xargs)"

        [[ -z "$repo" ]] && continue
        [[ "$repo" == \#* ]] && continue

        repo="${repo%.git}"

        if [[ ! "$repo" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]]; then
            printf 'Invalid DEV_PLUGINS entry: %s\n' "$repo" >&2
            exit 1
        fi

        url="https://github.com/$repo.git"
        existing=

        # Never pull, reset or otherwise alter an existing working copy.
        for plugin_dir in "$plugins_dir"/*; do
            [[ -d "$plugin_dir/.git" ]] || continue

            origin="$(
                sudo -u developer env HOME=/var/www                     git -C "$plugin_dir"                     remote get-url origin 2>/dev/null || true
            )"

            if [[ "$origin" == "$url" || "$origin" == "git@github.com:$repo.git" ]]; then
                existing="$plugin_dir"
                break
            fi
        done

        if [[ -n "$existing" ]]; then
            printf 'Dev plugin already present: %s -> %s\n' "$repo" "$existing"
            continue
        fi

        tmp="$plugins_dir/.aggro-clone-$$-$RANDOM"
        sudo rm -rf "$tmp"

        printf 'Cloning dev plugin: %s\n' "$repo"
        sudo -u developer env HOME=/var/www             git clone "$url" "$tmp"

        # Empty repositories keep the repository name. Existing Shopware
        # plugins use the configured plugin class name.
        target_name="${repo##*/}"

        if [[ -f "$tmp/composer.json" ]]; then
            technical_name="$(
                php -r '
                    $json = json_decode(file_get_contents($argv[1]), true);
                    $class = $json["extra"]["shopware-plugin-class"] ?? "";

                    if ($class !== "") {
                        $parts = explode("\\", $class);
                        echo end($parts);
                    }
                ' "$tmp/composer.json" 2>/dev/null || true
            )"

            if [[ -n "$technical_name" ]]; then
                target_name="$technical_name"
            fi
        fi

        target="$plugins_dir/$target_name"

        if [[ -e "$target" ]]; then
            printf 'Cannot clone %s: target already exists: %s\n'                 "$repo" "$target" >&2
            sudo rm -rf "$tmp"
            exit 1
        fi

        sudo -u developer mv "$tmp" "$target"
        printf 'Dev plugin ready: %s -> %s\n' "$repo" "$target"
    done <<< "$DEV_PLUGINS"
fi
