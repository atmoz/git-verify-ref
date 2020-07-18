#!/bin/bash

# Path to directory with public keys to import
public_key_dir="$1"

# Git reference
ref="${2:-HEAD}"

# Number of required signatures
num_required="${3:-"1"}"

# Options passed to git
git_options="${*:4}"

# Temporary list of verified keys
result_file="$(mktemp)"
add_result() {
    tee /dev/stderr | grep "Primary key fingerprint" >> "$result_file"
}

log() {
    echo -e ">>> $*" >&2
}

log_space() {
    echo -e "\n>>> $*\n" >&2
}

# Get SHA and tags (if any)
sha="$(git rev-parse --verify "$ref")"
tags="$(git tag --points-at "$sha")"

if [ -z "$sha" ]; then
    log "Not a valid git reference: $ref"
    exit 1
fi

if [ -z "$public_key_dir" ]; then
    log "Missing public_key_dir argument"
    exit 1
fi


log_space "Importing public keys"
find "$public_key_dir" -type f -exec gpg --import --keyid LONG {} +

log_space "Checking commit: $sha"
# shellcheck disable=SC2086
git $git_options verify-commit "$sha" 2>&1 | add_result

for tag in $tags; do
    log_space "Checking tag: $tag"
    # shellcheck disable=SC2086
    git $git_options verify-tag "$tag" 2>&1 | add_result
done

echo # newline

num_uniq="$(uniq "$result_file" | wc -l)"
log "Result: verified $num_uniq unique signatures ($num_required is required)"

if [ "$num_uniq" -lt "$num_required" ]; then
    log "Verification failed"
    exit 1
else
    log "Verification successful"
    exit 0
fi
