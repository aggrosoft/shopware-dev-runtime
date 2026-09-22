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
- The public shop hostname is available in `$SHOP_DOMAIN` and `$SERVICE_FQDN_SHOP`.
- The external `*.dev.aggrod.de` route is protected by Authentik and is not the normal browser-smoke path.
- The runtime mirrors matching Shopware sales-channel domains onto the internal Compose service origin `$INTERNAL_STOREFRONT_ORIGIN`, normally `http://shop`. This preserves Shopware's sales-channel, language, currency and snippet-set context while bypassing the external authentication layer.
- The disposable Dockware Administration uses the default development credentials `admin` / `shopware` unless the instance was explicitly changed.
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

## Administration UI

- Administration screens should look and behave like native Shopware Administration screens, not like a separate custom application embedded inside Shopware.
- Use Shopware's standard Administration components whenever a suitable component exists. Prefer the components and patterns provided by the installed Shopware version over custom replacements.
- Before designing a new Administration screen or interaction, inspect comparable Shopware core screens and existing Aggrosoft Administration modules and follow their established structure.
- Use the standard Shopware page structure, containers, cards, tabs, form fields, grids, empty states, modals, notifications, loading states and action areas whenever applicable.
- Keep spacing, hierarchy, labels, button placement, tab behavior and responsive layout consistent with surrounding Shopware Administration screens.
- Do not introduce custom layout systems, bespoke containers or unnecessary CSS when the same result can be achieved with Shopware's standard components and layout primitives.
- Custom styling is acceptable only where the standard Administration components cannot express the required UI. Keep such styling minimal and visually consistent with Shopware.
- Reuse current Shopware terminology and interaction patterns so users do not have to learn plugin-specific UI conventions for ordinary Administration tasks.
- When Shopware changes or deprecates Administration components between supported versions, use the conventions appropriate for the installed and supported Shopware version rather than copying outdated patterns.
- Inspect the installed Shopware version and comparable core screens before choosing Administration components. On Shopware 6.7, prefer the current Meteor-based `mt-*` components where Shopware core uses them rather than older deprecated component APIs.
- Do not add redundant explicit imports for Administration snippets that Shopware already auto-discovers. Follow the loading pattern used by comparable core modules and let the validator guide compatibility.
- When using `sw-page`, keep dialogs/modals inside the rendered `#content` area unless the core pattern for that screen requires something else; definitions outside rendered slots may never mount.
- For `mt-card`, use the intended slots such as `#toolbar` and `#grid` for search/actions and tabular content when applicable so the result matches native Shopware screen structure.

## Browser smoke tests

- A headless Chromium browser is available through the Playwright MCP server named `playwright`.
- Playwright tools may be lazy-loaded and not appear in the initial tool list. Before concluding that browser testing is unavailable, search the available tool registry for `playwright` / `mcp__playwright__`.
- Use it for relevant storefront and Administration smoke tests, navigation checks and visual verification instead of relying only on HTTP requests or source inspection.
- The Playwright browser runs in a separate container/network context. Do not assume that `localhost` or `$SHOP_DOMAIN=localhost` points to Shopware from the browser.
- For Administration checks, use `http://shop/admin`.
- For Storefront checks, use the internal mirrored sales-channel URL, normally `http://shop`. The runtime creates this as an additional `sales_channel_domain` row, so Shopware resolves the same sales-channel context without going through Authentik.
- If the shop has language or other path-based sales-channel domains, the runtime mirrors those paths as well (for example `https://example.dev.aggrod.de/en` becomes `http://shop/en`). Inspect the running sales-channel domains when the task depends on a specific one.
- Use the public `https://$SERVICE_FQDN_SHOP` URL only when explicitly testing Coolify/Traefik/Authentik behavior. Normal storefront smoke tests should stay on the internal route.
- If internal service DNS unexpectedly fails for an Administration-only check, determine the current Shopware container IPv4 address at runtime (for example via `hostname -I`) and use it only as a temporary fallback. Never hard-code a container IP because it can change after recreate/restart.
- For Administration smoke tests, the disposable Dockware credentials are normally `admin` / `shopware` unless explicitly changed for the instance.
- For UI changes, check the affected page in the browser and look for obvious JavaScript console errors, failed navigation, broken layout and unusable interactions.
- After rebuilding Administration assets, perform a cache-disabled reload before judging the result so an old plugin bundle is not mistaken for the current build.
- The Symfony debug toolbar may overlap the bottom edge of Administration screenshots in this development environment; do not report that overlap as a plugin UI defect.
- Keep browser tests focused on the change; do not perform destructive business actions unless the task requires them.
- Treat an unavailable Playwright MCP server as an environment problem. Do not present API-only checks as an equivalent substitute for a requested or relevant visual smoke test.

## PHPUnit in plugin repositories

- Custom plugin repositories normally reuse the Shopware root Composer installation and may not have their own `vendor/` directory.
- Unless a plugin-local PHPUnit executable actually exists or the repository explicitly documents another workflow, run PHPUnit from `/var/www/html`, for example: `bin/phpunit -c custom/plugins/<Plugin>/phpunit.xml.dist`.
- From a plugin directory, `../../../bin/phpunit -c phpunit.xml.dist` is also valid when the relative path matches the standard `custom/plugins/<Plugin>` layout.
- Do not assume `<plugin>/vendor/bin/phpunit` exists and do not run a separate `composer install` inside a plugin merely to obtain PHPUnit.

## Validation

- Do not stop after editing code.
- Run the relevant existing tests, static analysis and checks configured by the plugin or project.
- `shopware-cli` is installed globally in this environment and is the default Shopware extension quality/build tool.
- For PHP plugin development, static analysis is expected. Unless the plugin provides a more specific established workflow, run `shopware-cli extension validate --full <plugin-path>`; this includes PHPStan and the other applicable Shopware extension checks.
- If the plugin provides its own Composer/npm test, lint or static-analysis scripts, run those as well and prefer the repository's configuration over inventing a parallel one.
- Test the change in this running Shopware instance whenever practical.
- Build the plugin after relevant changes and fix build errors caused by your work. Unless the repository defines a more specific build command, use `shopware-cli extension build <plugin-path>` for extension assets.
- For Administration or Storefront changes, run the relevant Administration/Storefront or plugin asset build rather than assuming source changes compile.
- Use Shopware lifecycle commands such as `plugin:refresh`, cache clearing, theme compilation or asset installation only when relevant to the change.
- When validation already reports findings before or outside the changed area, distinguish the existing baseline from regressions introduced by the task. Do not claim unrelated pre-existing validator findings were caused by the current change.
- Before declaring the task complete, state which tests/builds/checks were run and whether they passed. If something could not be tested, say what and why.

## Git workflow

- Make atomic, meaningful commits: one logical change per commit, without mixing unrelated work or artificially splitting one coherent change.
- Use clear commit messages that describe the change.
- Do not rewrite published history, force-push, rebase other people's work or modify unrelated commits unless explicitly requested.
- Never push or merge to `main` unless the user explicitly instructs you to do so in the current task.
- Local commits and work on a task/feature branch are allowed when useful.
- Never commit secrets, credentials, environment values or production configuration.
