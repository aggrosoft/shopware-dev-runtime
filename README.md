# Shopware Dev Runtime

Runtime helpers for disposable Shopware development instances on Coolify.

This repository deliberately does **not** contain Shopware. The Coolify template continues to run any `dockware/shopware:${SHOPWARE_VERSION}` image and mounts the helper scripts from the tiny runtime image published by this repository.

## Responsibilities

The runtime handles only development plumbing:

- create/use the Dockware SSH user
- keep the optional SSH password in sync
- configure the default Git identity
- configure GitHub App credentials for HTTPS Git operations
- clone repositories listed in `DEV_PLUGINS` into `custom/plugins`
- leave existing Git working copies untouched on restart

The Coolify Compose definition stays responsible for Shopware, persistent volumes, routing and SSHPiper labels.

## Runtime image

The GitHub workflow publishes:

```text
ghcr.io/aggrosoft/shopware-dev-runtime:main
```

The image is only a carrier for the scripts. A short-lived `runtime` service copies them into a named volume that the Shopware container mounts read-only at `/opt/aggro`.

## Coolify Compose

Use `compose.coolify.example.yaml` as the template.

Important: disable **Escape special characters in labels** for the Coolify service. SSHPiper relies on Coolify/Compose interpolating `${SERVICE_FQDN_SHOP}` and `${COMPOSE_PROJECT_NAME}` in the labels.

## Environment

Per Shopware instance:

| Variable | Purpose |
|---|---|
| `SHOPWARE_VERSION` | Dockware/Shopware image tag |
| `SSH_PASSWORD` | Optional password login through SSHPiper |
| `SSH_AUTHORIZED_KEYS_B64` | Optional Base64-encoded downstream `authorized_keys` for SSHPiper public-key mode |
| `DEV_PLUGINS` | Optional multiline list of `owner/repo` GitHub repositories |
| `GIT_USER_NAME` | Defaults to `Aggrosoft Dev Server` |
| `GIT_USER_EMAIL` | Defaults to `dev-server@aggrosoft.de` |

Project-shared values:

```text
GITHUB_APP_CLIENT_ID
GITHUB_APP_INSTALLATION_ID
GITHUB_APP_PRIVATE_KEY
SSH_AUTHORIZED_KEYS_B64   # optional
```

The GitHub private key remains a normal multiline PEM value in Coolify.

### SSH modes

At least one of `SSH_PASSWORD` or `SSH_AUTHORIZED_KEYS_B64` must be present.

- without `SSH_AUTHORIZED_KEYS_B64`, SSHPiper forwards password authentication to Dockware's SSH server
- with `SSH_AUTHORIZED_KEYS_B64`, the stock SSHPiper Docker plugin switches to its public-key Docker-exec bridge

SSHPiper's Docker plugin requires the downstream authorized-keys label in Base64 form. This is a proxy requirement, not a runtime-image requirement.

Create the shared value from an authorized-keys file with:

```bash
openssl base64 -A -in authorized_keys
```

### GitHub App references

Each Coolify resource should reference the project-shared GitHub values:

```text
GITHUB_APP_CLIENT_ID={{project.GITHUB_APP_CLIENT_ID}}
GITHUB_APP_INSTALLATION_ID={{project.GITHUB_APP_INSTALLATION_ID}}
GITHUB_APP_PRIVATE_KEY={{project.GITHUB_APP_PRIVATE_KEY}}
```

Mark `GITHUB_APP_PRIVATE_KEY` as multiline on both the shared variable and the resource variable.

`DEV_PLUGINS` is multiline, for example:

```text
aggrosoft/shopware-firewall
aggrosoft/shopware-cms-extras
```

The runtime clones missing repositories only. It never automatically pulls, resets or deletes an existing Git checkout.
