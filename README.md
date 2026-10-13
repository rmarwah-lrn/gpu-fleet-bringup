# Redfish / IPMI simulation lab

This lab follows the hands-on sequence:

1. Serve the DMTF Redfish Mockup Server and walk its resource tree with `curl`.
2. Define two empty libvirt domains.
3. Put `sushy-tools` in front of the domains and exercise power and PXE boot operations.
4. Put VirtualBMC in front of the same domains and exercise the equivalent IPMI operations.
5. Record the protocol comparison and observed failures in [`notes/redfish-vs-ipmi.md`](notes/redfish-vs-ipmi.md).

## Host requirements

The VM-backed portions need a Linux host, or macOS with a working libvirt/QEMU installation. On macOS:

```sh
brew install libvirt qemu virt-install ipmitool
brew services start libvirt
python3 -m venv .venv
. .venv/bin/activate
python -m pip install sushy-tools virtualbmc
```

On Linux, install the equivalent distribution packages (`libvirt-daemon`, `qemu`, `virt-install`,
`ipmitool`) and the two Python packages in a virtual environment. The lab uses `qemu:///session`.

## Run it

```sh
make check
make mockup-start       # terminal 1; requires Docker Desktop or another Docker daemon
make mockup-walk        # terminal 2
```

The mockup server uses port 8000. Stop it before starting sushy-tools, or use another port:
`make SUSHY_PORT=8001 sushy-start` and `make SUSHY_PORT=8001 sushy-actions`.

After libvirt and the Python tools are installed:

```sh
make vms-create
make sushy-start         # terminal 1
make sushy-walk          # terminal 2
make sushy-actions
make vbmc-daemon         # terminal 1
make vbmc-start          # terminal 2
make ipmi-actions        # terminal 2
```

Clean up with `make clean`.

The two domains are powered-off management targets with small empty disks, not bootable operating
systems. PXE requests therefore demonstrate that the boot override is accepted and propagated, but
they do not install an OS.

## References

- DMTF Redfish Mockup Server: <https://github.com/DMTF/Redfish-Mockup-Server>
- DMTF Redfish standard: <https://www.dmtf.org/standards/redfish>
- sushy-tools: <https://docs.openstack.org/sushy-tools/latest/user/dynamic-emulator.html>
- VirtualBMC: <https://docs.openstack.org/virtualbmc/latest/user/index.html>
- libvirt on macOS: <https://www.libvirt.org/macos.html>
