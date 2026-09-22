#!/bin/sh
set -eu

target="${1:-/target}"

if [ ! -d "$target" ]; then
    printf 'Runtime target does not exist: %s\n' "$target" >&2
    exit 1
fi

find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -a /runtime/. "$target"/

printf 'Shopware dev runtime installed into %s\n' "$target"
