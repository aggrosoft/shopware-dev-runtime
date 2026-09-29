#!/usr/bin/env bash
set -euo pipefail

[[ "${1:-}" == "get" ]] || exit 0

protocol=
host=
path=

while IFS='=' read -r key value; do
    case "$key" in
        protocol) protocol="$value" ;;
        host) host="$value" ;;
        path) path="$value" ;;
    esac
done

[[ "$protocol" == "https" ]] || exit 0
[[ "$host" == "github.com" ]] || exit 0

repo_path="${path#/}"
repo_path="${repo_path%.git}"

if [[ ! "$repo_path" =~ ^[^/[:space:]@]+/[^/[:space:]@]+$ ]]; then
    printf 'GitHub credential helper requires an owner/repository path, got: %s\n' "$path" >&2
    exit 1
fi

owner="${repo_path%%/*}"
repository="${repo_path#*/}"

github_dir=/var/www/.config/aggro-github
client_id_file="$github_dir/client-id"
private_key="$github_dir/private-key.pem"

if [[ ! -s "$client_id_file" || ! -s "$private_key" ]]; then
    printf '%s\n' 'GitHub App credentials are not initialized.' >&2
    exit 1
fi

client_id="$(<"$client_id_file")"
now="$(date +%s)"

b64url() {
    openssl base64 -A | tr '+/' '-_' | tr -d '='
}

header="$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | b64url)"
payload="$(
    printf '{"iat":%d,"exp":%d,"iss":"%s"}' \
        "$((now - 60))" \
        "$((now + 540))" \
        "$client_id" \
        | b64url
)"

unsigned="$header.$payload"
signature="$(
    printf '%s' "$unsigned" \
        | openssl dgst -sha256 -sign "$private_key" -binary \
        | b64url
)"
jwt="$unsigned.$signature"

if ! installation_response="$(
    curl -fsS \
        --url "https://api.github.com/repos/$owner/$repository/installation" \
        --header 'Accept: application/vnd.github+json' \
        --header "Authorization: Bearer $jwt" \
        --header 'X-GitHub-Api-Version: 2022-11-28'
)"; then
    printf 'GitHub App is not installed for or has no access to %s.\n' "$repo_path" >&2
    exit 1
fi

installation_id="$(
    printf '%s' "$installation_response" \
        | php -r '
            $data = json_decode(stream_get_contents(STDIN), true);
            if (!is_array($data) || empty($data["id"])) {
                fwrite(STDERR, "GitHub did not return an installation id\n");
                exit(1);
            }
            echo $data["id"];
        '
)"

token_file="$github_dir/installation-token-$installation_id"
token=

if [[ -s "$token_file" ]]; then
    token_mtime="$(stat -c %Y "$token_file" 2>/dev/null || printf '0')"
    if (( now - token_mtime < 3000 )); then
        token="$(<"$token_file")"
    fi
fi

if [[ -z "$token" ]]; then
    response="$(
        curl -fsS \
            --request POST \
            --url "https://api.github.com/app/installations/$installation_id/access_tokens" \
            --header 'Accept: application/vnd.github+json' \
            --header "Authorization: Bearer $jwt" \
            --header 'X-GitHub-Api-Version: 2022-11-28'
    )"

    token="$(
        printf '%s' "$response" \
            | php -r '
                $data = json_decode(stream_get_contents(STDIN), true);
                if (!is_array($data) || empty($data["token"])) {
                    fwrite(STDERR, "GitHub did not return an installation token\n");
                    exit(1);
                }
                echo $data["token"];
            '
    )"

    umask 077
    printf '%s' "$token" > "$token_file"
fi

printf 'username=x-access-token\n'
printf 'password=%s\n\n' "$token"
