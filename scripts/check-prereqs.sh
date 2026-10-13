#!/bin/sh
set -eu

for command in curl python3 docker virsh virt-install sushy-emulator vbmc ipmitool; do
    if command -v "$command" >/dev/null 2>&1; then
        printf 'ok   %s: %s\n' "$command" "$(command -v "$command")"
    else
        printf 'MISS %s\n' "$command"
    fi
done
