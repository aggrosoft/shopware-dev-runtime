# Shopware Dev Runtime

Runtime helpers for disposable Shopware development instances on Coolify.

The repository deliberately does **not** contain Shopware. The Coolify template continues to run any `dockware/shopware:${SHOPWARE_VERSION}` image and mounts these helper scripts from the tiny runtime image published by this repository.

## Responsibilities

The runtime handles development plumbing only:

- create/use Dockware's SSH user
- keep an optional SSH password in sync
- configure the default Git identity
- configure GitHub App credentials for HTTPS Git operations
- clone repositories listed in `DEV_PLUGINS` into `custom/plugins`
- leave existing Git working copies untouched on restart

The existing stock SSHPiper installation remains responsible for external SSH routing and public-key authentication.

## Runtime image

The GitHub workflow publishes:

```text
ghcr.io/aggrosoft/shopware-dev-runtime:main
```

The image is only a carrier for the scripts. A short-lived `runtime` service copies them into a named volume that the Shopware container mounts read-only at `/opt/aggro`.

## Coolify Compose

Use `compose.coolify.example.yaml` as the template.

Important: disable **Escape special characters in labels** for the Coolify service. SSHPiper relies on Coolify/Compose interpolating `${SERVICE_FQDN_SHOP}`, `${COMPOSE_PROJECT_NAME}`, and the shared SSH key variable in the labels.

## Environment

Per Shopware instance:

| Variable | Purpose |
|---|---|
| `SHOPWARE_VERSION` | Dockware/Shopware image tag |
| `SSH_PASSWORD` | Optional password login when no shared public-key variable is configured |
| `DEV_PLUGINS` | Optional multiline list of `owner/repo` GitHub repositories |
| `GIT_USER_NAME` | Defaults to `Aggrosoft Dev Server` |
| `GIT_USER_EMAIL` | Defaults to `dev-server@aggrosoft.de` |

Project-shared values:

```text
GITHUB_APP_CLIENT_ID
GITHUB_APP_INSTALLATION_ID
GITHUB_APP_PRIVATE_KEY
SSH_AUTHORIZED_KEYS_B64
```

The GitHub private key remains a normal multiline PEM value in Coolify.

## SSH

The existing stock SSHPiper Docker plugin is used unchanged.

`SSH_AUTHORIZED_KEYS_B64` contains the Base64 representation of a normal OpenSSH `authorized_keys` list. It is referenced only from SSHPiper labels and is not copied into the Shopware container.

When `SSH_AUTHORIZED_KEYS_B64` is set, the stock SSHPiper Docker plugin uses its public-key Docker-exec bridge. When it is empty, password authentication is forwarded to Dockware's SSH server.

Because the stock Docker plugin switches authentication mode when `sshpiper.authorized_keys` is present, password and public-key authentication are not offered simultaneously for the same container. With the shared project variable configured, Shopware DEV instances effectively use public-key access.

Example source text before Base64 encoding:

```text
ssh-ed25519 AAAA... developer-one
ssh-ed25519 AAAA... developer-two
```

Generate the single-line project value with:

```bash
printf '%s\n' 'ssh-ed25519 AAAA... developer-one' 'ssh-ed25519 AAAA... developer-two' | openssl base64 -A
```

To change the developer keys, update only the project-shared `SSH_AUTHORIZED_KEYS_B64` value.

## GitHub App references

Each Coolify resource should reference the project-shared GitHub values:

```text
GITHUB_APP_CLIENT_ID={{project.GITHUB_APP_CLIENT_ID}}
GITHUB_APP_INSTALLATION_ID={{project.GITHUB_APP_INSTALLATION_ID}}
GITHUB_APP_PRIVATE_KEY={{project.GITHUB_APP_PRIVATE_KEY}}
SSH_AUTHORIZED_KEYS_B64={{project.SSH_AUTHORIZED_KEYS_B64}}
```

Mark `GITHUB_APP_PRIVATE_KEY` as multiline on both the shared variable and the resource variable.

`DEV_PLUGINS` is multiline, for example:

```text
aggrosoft/shopware-firewall
aggrosoft/shopware-cms-extras
```

The runtime clones missing repositories only. It never automatically pulls, resets or deletes an existing Git checkout.
