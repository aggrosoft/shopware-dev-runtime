# Shopware Dev Runtime

Small runtime helper for disposable Shopware development instances on Coolify.

The image contains only the provisioning scripts used by the Shopware DEV template. It does not contain Shopware itself. The template continues to run `dockware/shopware:${SHOPWARE_VERSION}` and mounts these helpers from a tiny sidecar-populated volume.
