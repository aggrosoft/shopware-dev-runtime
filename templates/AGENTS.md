# Shopware Development Environment

This file is seeded once by the Shopware dev runtime and is intentionally not overwritten on restart.
You may edit and extend it for this development instance.

## Environment

- You are working directly inside a disposable but fully functional remote Dockware-based Shopware development environment.
- The VS Code workspace is normally opened at `/var/www`.
- Shopware root: `/var/www/html`.
- Custom plugins: `/var/www/html/custom/plugins`.
- Runtime helper scripts: `/opt/aggro`.
- Git configuration: `/var/www/.gitconfig`.
- GitHub App runtime data: `/var/www/.config/aggro-github`.
- The current shop hostname is available in `$SHOP_DOMAIN` and `$SERVICE_FQDN_SHOP`.
- Run Shopware CLI commands from `/var/www/html`, for example `bin/console ...`.
- PHP, Node.js, the database and the running Shopware installation are already available inside this environment.
- Do not add Docker wrappers or create a parallel local environment unless explicitly requested.

## Plugin repositories

- `/var/www` and `/var/www/html` are not the development Git repositories and must not be initialized as Git repositories.
- Individual directories below `/var/www/html/custom/plugins` may be independent Git repositories.
- Before changing a plugin, inspect its repository and run `git status` there.
- Never reset, clean, stash, overwrite or otherwise discard unrelated existing working-copy changes unless explicitly requested.
- Commit and push from the individual plugin repository only.
- Use existing Aggrosoft plugins in `custom/plugins` as references for structure, naming, services, administration/storefront organization, tests, Composer configuration and other established conventions before introducing new patterns.

## Implementation

- Follow Shopware conventions and supported APIs. Prefer the intended Shopware mechanism over core hacks, direct database manipulation or custom framework abstractions.
- Keep solutions as small and maintainable as practical. Do not add architecture for hypothetical future needs.
- Do not add or upgrade Composer/npm dependencies unless the task actually requires it.
- Determine the installed Shopware version from the running installation when relevant and implement for the versions the plugin actually supports.
- Do not add unnecessary backwards compatibility for unsupported old Shopware versions.
- If requirements are ambiguous, inspect the existing implementation first. Ask before making a materially different product or architecture decision when the correct choice cannot be inferred safely.

## Validation

- Do not stop after editing code.
- Run the relevant existing tests, static analysis and checks for the plugin.
- Test the change in this running Shopware instance whenever practical.
- Build the plugin after relevant changes and fix build errors caused by your work.
- For Administration or Storefront changes, run the relevant Administration/Storefront or plugin asset build rather than assuming source changes compile.
- Use Shopware lifecycle commands such as `plugin:refresh`, cache clearing, theme compilation or asset installation only when relevant to the change.
- Before declaring the task complete, state which tests/builds/checks were run and whether they passed. If something could not be tested, say what and why.

## Git workflow

- Make atomic, meaningful commits: one logical change per commit, without mixing unrelated work or artificially splitting one coherent change.
- Use clear commit messages that describe the change.
- Do not rewrite published history, force-push, rebase other people's work or modify unrelated commits unless explicitly requested.
- Never push or merge to `main` unless the user explicitly instructs you to do so in the current task.
- Local commits and work on a task/feature branch are allowed when useful.
- Never commit secrets, credentials, environment values or production configuration.
