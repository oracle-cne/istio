#!/usr/bin/env bash

# Extract the Oracle-built ztunnel without running the image or its binary.
set -euo pipefail

log() {
    printf 'extract-ztunnel.sh: %s\n' "$*"
}

if [[ $# -ne 3 ]]; then
    log "usage: $0 <image> <amd64|arm64> <output-path>" >&2
    exit 1
fi

image="$1"
arch="$2"
output="$3"
container_cli="${CONTAINER_CLI:-podman}"
container_id=""

log "checking image, architecture, and output path"
if [[ -z "$image" || -z "$output" ]]; then
    log "image and output path must not be empty" >&2
    exit 1
fi
case "$arch" in
    amd64|arm64) ;;
    *) log "unsupported architecture: $arch" >&2; exit 1 ;;
esac

log "creating temporary extraction directory"
extract_dir=$(mktemp -d)

cleanup() {
    local status=$?
    trap - EXIT
    if [[ -n "$container_id" ]]; then
        log "removing extraction container $container_id"
        if ! "$container_cli" rm "$container_id"; then
            log "failed to remove extraction container $container_id" >&2
            status=1
        fi
    fi
    log "removing temporary extraction directory $extract_dir"
    rm -rf -- "$extract_dir"
    log "extraction finished with status $status"
    exit "$status"
}
trap cleanup EXIT

log "creating stopped container from $image for linux/$arch; pulling if missing"
container_id=$("$container_cli" create --platform "linux/$arch" --pull=missing "$image")
log "copying /usr/local/bin/ztunnel from container $container_id"
"$container_cli" cp "$container_id:/usr/local/bin/ztunnel" "$extract_dir/ztunnel"
log "checking extracted binary is nonempty"
if [[ ! -s "$extract_dir/ztunnel" ]]; then
    log "image did not supply a nonempty ztunnel binary" >&2
    exit 1
fi

log "installing ztunnel to $output"
install -D -m 0755 "$extract_dir/ztunnel" "$output"
log "Oracle ztunnel binary installed successfully"
