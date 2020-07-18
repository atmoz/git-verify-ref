#!/bin/bash

# Path to directory with public keys to import
import_dir="$1"

# List of GitHub users to retrieve public keys from, one per line
import_github_users="$2"

# Git reference
ref="${3:-HEAD}"

# Number of required signatures
num_required="${4:-"1"}"

# Options passed to git
git_options="${*:5}"

# Temporary list of verified keys
result_file="$(mktemp)"

add_result() {
    tee /dev/stderr | grep "Primary key fingerprint" >> "$result_file"
}

log() {
    echo "$*" >&2
}

log_header() {
    echo -e "\n$*" >&2
}

import_from_dir() {
    log_header "Importing public keys from $1"
    find "$1" -type f -exec gpg --import --keyid LONG {} +
}

import_from_github_user() {
    log_header "Importing public keys from GitHub user $1"
    curl -s "https://api.github.com/users/$1/gpg_keys" \
        | jq --raw-output '.[].raw_key?' \
        | gpg --import
}

verify_ref() {
    ref="$1"
    sha="$(git rev-parse --verify "$ref")"
    tags="$(git tag --points-at "$sha")"

    log_header "Checking commit: $sha"
    # shellcheck disable=SC2086
    git $git_options verify-commit "$sha" 2>&1 | add_result

    for tag in $tags; do
        log_header "Checking tag: $tag"
        # shellcheck disable=SC2086
        git $git_options verify-tag "$tag" 2>&1 | add_result
    done
}

# Create trustdb quietly
gpg --check-trustdb -q

if [ -e "$import_dir" ]; then
    import_from_dir "$import_dir"
fi

while read -r user; do
    if [ -n "$user" ]; then
        import_from_github_user "$user"
    fi
done <<< "$import_github_users"

verify_ref "$ref"

num_uniq="$(uniq "$result_file" | wc -l)"
log_header "Result: verified $num_uniq unique signatures ($num_required is required)"

if [ "$num_uniq" -lt "$num_required" ]; then
    log "Verification failed"
    exit 1
else
    log "Verification successful"
    exit 0
fi
