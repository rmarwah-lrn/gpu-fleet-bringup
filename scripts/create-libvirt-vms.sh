#!/bin/sh
set -eu
uri=${DOMAIN_URI:-qemu:///session}
# Homebrew's embedded virt-install Python needs Homebrew's matching expat on macOS.
if [ "$(uname -s)" = "Darwin" ]; then
    export DYLD_LIBRARY_PATH="/opt/homebrew/opt/expat/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
fi
command -v virsh >/dev/null 2>&1 || { echo 'virsh is required' >&2; exit 1; }
command -v virt-install >/dev/null 2>&1 || { echo 'virt-install is required' >&2; exit 1; }

for name in redfish-lab-node0 redfish-lab-node1; do
    if virsh -c "$uri" dominfo "$name" >/dev/null 2>&1; then
        echo "$name already exists; leaving it unchanged"
        continue
    fi
    # macOS mktemp requires the XXXXXX template at the end of the filename.
    tmp=$(mktemp "${TMPDIR:-/tmp}/$name.XXXXXX")
    # Keep the domains NIC-less: macOS libvirt cannot create Linux TAP devices.
    virt-install --connect "$uri" --name "$name" --memory 512 --vcpus 1 \
        --disk size=1,format=qcow2 \
        --osinfo detect=on,require=off --graphics none --noautoconsole \
        --machine virt --xml ./features/gic/@version=3 --boot hd --print-xml > "$tmp"
    virsh -c "$uri" define "$tmp"
    rm -f "$tmp"
    echo "defined $name"
done
virsh -c "$uri" list --all
