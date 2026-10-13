# Redfish vs IPMI — lab note

## What was exercised

Redfish is an HTTP/REST management API. A client walks resources using `GET`, changes state with
`PATCH`, and invokes actions with `POST`. In this lab, `sushy-tools` translates those requests into
libvirt domain operations. The DMTF mockup server is a static fixture: it is useful for learning
the resource tree, but it is not a live BMC and may reject or ignore state-changing requests.

IPMI is a command-oriented management protocol traditionally carried over UDP port 623. With
VirtualBMC, `ipmitool` sends chassis commands to a virtual BMC, which translates them into libvirt
operations. The common equivalent checks are `chassis status`, `chassis power on`, `chassis power
cycle`, and `chassis bootdev pxe`.

| Concern | Redfish | IPMI |
|---|---|---|
| Interface | JSON resources over HTTP(S) | Binary command protocol, commonly UDP |
| Discovery | Hypermedia via `@odata.id` and collections | Fixed command families and numeric completion codes |
| Boot request | PATCH `BootSourceOverride*` properties | `chassis bootdev pxe` |
| Power request | POST `ComputerSystem.Reset` action | `chassis power on/cycle` |
| Extensibility | Schema-defined resources and vendor extensions | Older, narrower command surface; OEM commands are common |
| Debugging | HTTP status, JSON body, headers, resource state | Completion codes, `ipmitool` output, packet diagnostics |

## What failed and why

On the original Apple-Silicon macOS host, the VM-backed portions could not be run initially:

- `virsh`, `virt-install`, QEMU, `sushy-emulator`, `vbmc`, and `ipmitool` were not installed.
- Docker Compose was installed, but no Docker daemon was running, so the mockup container could
  not be started.
- The workspace had no existing source or fixture files; the compose file builds directly from the
  DMTF Mockup Server repository instead of duplicating its contents.

After installing prerequisites and starting Docker/libvirt, the expected remaining failure is
instructive: empty domains have no operating system or PXE server, so a successful BMC request does
not imply a successful guest boot. Static mockups are not suitable for write operations; those should
be tested through `sushy-emulator` and VirtualBMC. On this macOS host, VirtualBMC accepted status,
power-on, and PXE selection through `ipmitool`, but rejected `chassis power cycle` with “Invalid data
field”; `chassis power reset` was accepted as the compatible reset operation. The VM definitions also
had to omit NICs because macOS libvirt cannot create Linux TAP devices, and use GICv3 because HVF
does not support GICv2 emulation.

## Takeaway

Redfish is generally easier to inspect, automate, and extend because its state is represented as
discoverable JSON resources. IPMI remains useful for compatibility with existing tooling and
out-of-band workflows, but its terse command model and completion codes make vendor-specific
behavior and debugging less transparent. Both interfaces still depend on a real backend: the
protocol operation can succeed while the guest fails to boot because it has no bootable media or
PXE infrastructure.
