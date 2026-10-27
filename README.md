# Shopware Dev Runtime

Runtime helpers for disposable Shopware development instances on Coolify.

The repository deliberately does **not** contain Shopware. The Coolify template continues to run any `dockware/shopware:${SHOPWARE_VERSION}` image and mounts these helper scripts from the tiny runtime image published by this repository.

## Responsibilities

The runtime handles development plumbing only:

- configure the default Git identity
- provide Shopware CLI as the standard extension validation/build tool
- mirror public sales-channel domains onto the internal `http://shop` origin for authenticated-gateway-free browser smoke tests
- configure Shopware to trust forwarded client metadata only from the Coolify reverse proxy
- configure GitHub App credentials for HTTPS Git operations
- clone repositories listed in `DEV_PLUGINS` into `custom/plugins`
- leave existing Git working copies untouched on restart

Remote access is provided by `aggrosoft/coolify-ssh-bridge`. The Compose template enables the resource with `AGGRO_SSH_ENABLED=true`; no per-resource SSH keys or proxy labels are required.

The Playwright MCP browser service runs with `--isolated`, so agent sessions use temporary Chromium profiles instead of sharing one persistent profile. This avoids profile-lock conflicts between sequential or concurrent Codex sessions.

## Runtime image

The GitHub workflow publishes:

```text
ghcr.io/aggrosoft/shopware-dev-runtime:main
```

The image is only a carrier for the scripts. A short-lived `runtime` service copies them into a named volume that the Shopware container mounts read-only at `/opt/aggro`.

## Coolify Compose

Use `compose.coolify.example.yaml` as the template.

### Reverse proxy network (required for HTTPS)

On the application in Coolify, enable **Advanced > Docker Compose > Connect to predefined network** and select the standard `coolify` destination. This is a deployment prerequisite for the template; do not remove the private resource network.

Coolify normally routes Compose traffic over a resource-specific network. The development provisioner resolves `coolify-proxy` and writes its IP address to `/var/www/html/config/packages/z-framework.yaml` for Symfony's trusted-proxy configuration. If Traefik connects over a different network, the request may have a different source IP, so Shopware ignores `X-Forwarded-Proto: https` and generates HTTP asset URLs despite the page being served over HTTPS.

The `shop` service therefore sets `traefik.docker.network=coolify` to match the network whose proxy address the provisioner trusts. Coolify preserves this explicit label instead of generating its default resource-network label. We deliberately keep proxy trust limited to resolved IP addresses; do not replace it with `REMOTE_ADDR` or broad private subnets merely to hide a networking mismatch.

When deploying, inspect **Show Deployable Compose** and confirm that `shop` is attached to `coolify` and retains `traefik.docker.network=coolify`. If using a nonstandard destination network, adapt both the network label and the Coolify predefined-network selection before deploying. Only redeploy a disposable test instance first; existing shops are unaffected until redeployed.


## Environment

Per Shopware instance:

| Variable | Purpose |
|---|---|
| `SHOPWARE_VERSION` | Dockware/Shopware image tag |
| `DEV_PLUGINS` | Optional multiline list of repositories with optional version/branch selectors |
| `GIT_USER_NAME` | Defaults to `Aggrosoft Dev Server` |
| `GIT_USER_EMAIL` | Defaults to `dev-server@aggrosoft.de` |

Project-shared values:

```text
GITHUB_APP_CLIENT_ID
GITHUB_APP_PRIVATE_KEY
```

The GitHub private key remains a normal multiline PEM value in Coolify.

## SSH

The Compose template enables remote access with:

```text
AGGRO_SSH_ENABLED=true
```

`aggrosoft/coolify-ssh-bridge` handles authentication and routing centrally. Do not add SSHPiper labels or per-resource authorized-key variables.

## GitHub App references

Each Coolify resource should reference the project-shared GitHub values:

```text
GITHUB_APP_CLIENT_ID={{project.GITHUB_APP_CLIENT_ID}}
GITHUB_APP_PRIVATE_KEY={{project.GITHUB_APP_PRIVATE_KEY}}
```

Mark `GITHUB_APP_PRIVATE_KEY` as multiline on both the shared variable and the resource variable.

The runtime resolves the GitHub App installation dynamically for each repository in `DEV_PLUGINS`. The same app can therefore clone repositories from multiple organizations without configuring installation IDs. The app must be installed on each repository owner account and granted access to the repository.

`DEV_PLUGINS` is multiline. Each line supports one of these forms:

```text
# Repository default branch
aggrosoft/shopware-firewall

# Highest stable Git tag matching a Composer version constraint
aggrosoft/shopware-cms-extras@4.x
aggrosoft/another-plugin@^2.3

# Explicit Git branch
aggrosoft/legacy-plugin@branch:6.6
aggrosoft/test-plugin@branch:feature/foo
```

Version selectors are resolved from remote Git tags with Composer's Semver implementation. Tags with a leading `v` are supported. Pre-release tags are ignored, and provisioning fails if no stable tag matches the requested constraint. There is no fallback to the default branch.

The runtime clones missing repositories only. It never automatically pulls, resets, checks out or deletes an existing Git checkout, even when the configured selector later changes.


## Persistent remote development state

The Coolify template persists VS Code Remote and Codex state across container recreates:

- `vscode_server:/var/www/.vscode-server`
- `codex_home:/var/www/.codex`

This keeps installed remote VS Code extensions and Codex authentication/configuration when the Shopware container is recreated.
