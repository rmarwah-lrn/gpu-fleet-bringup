# Part 1 — GPU Fleet Bring-Up: Out-of-Band Control and Virtualization

## Before the OS: Controlling a GPU Fleet Through Redfish and IPMI

*A hands-on exploration of Redfish, IPMI, libvirt, sushy-tools, and VirtualBMC on Apple Silicon macOS.*

This lab was run on an Apple Silicon Mac, so the virtualization results include platform-specific
constraints—most notably, the test VMs could not use the default TAP-based virtual networking.

**TL;DR:** How do you control and recover a fleet node before its operating system is available?
This lab compares two paths to the same virtual machines: Redfish through sushy-tools and libvirt,
and IPMI through VirtualBMC and libvirt. The main lesson is operational: an accepted management
request is not the same as a verified machine state.

**Lab materials:** [repository and Makefile](PUBLIC_REPOSITORY_URL)  
**Series context:** [Part 1 inference post](PART_1_SUBSTACK_URL)

There is a difference between reading a standard and making it do something.

For this lab, I wanted to follow a simple management path all the way down:

```text
curl / Redfish client  ->  sushy-tools  ->  libvirt  ->  QEMU VM
ipmitool               ->  VirtualBMC   ->  libvirt  ->  QEMU VM
```

The examples use ARM virtual machines on Apple Silicon macOS, so some low-level virtualization and
networking details differ from a typical Linux/KVM deployment.

The goal was not to build a production BMC. It was to understand what each layer contributes,
exercise the same operations through two management protocols, and pay attention to the failures
that are easy to hide in a successful demo.

## First stop: walking a Redfish tree

The DMTF Redfish Mockup Server provides a static collection of Redfish JSON resources. It is a good
place to learn the shape of the API because the server can be explored with ordinary HTTP requests:

```sh
curl http://127.0.0.1:8000/redfish/v1/
```

The service root points to the major collections:

```json
{
  "Id": "RedvirtService",
  "Name": "Redvirt Service",
  "RedfishVersion": "1.5.0",
  "Chassis": {"@odata.id": "/redfish/v1/Chassis"},
  "Systems": {"@odata.id": "/redfish/v1/Systems"},
  "Managers": {"@odata.id": "/redfish/v1/Managers"}
}
```

The important idea is hypermedia. A client discovers the next URL from `@odata.id` instead of
assuming that every vendor uses the same identifier layout.

The Systems collection exposed two systems:

```json
{
  "Members@odata.count": 2,
  "Members": [
    {"@odata.id": "/redfish/v1/Systems/ccd3215f-d86f-42cd-9bd7-02ae446a3a17"},
    {"@odata.id": "/redfish/v1/Systems/fffe0f7f-2a7b-4118-a6bb-6ca7133bf17b"}
  ]
}
```

Following the first link produced a system resource with power state, boot settings, reset actions,
and links back to its chassis and manager:

```json
{
  "Name": "redfish-lab-node0",
  "PowerState": "On",
  "Boot": {
    "BootSourceOverrideEnabled": "Continuous",
    "BootSourceOverrideTarget": "Pxe",
    "BootSourceOverrideMode": "UEFI"
  }
}
```

That was the first useful distinction in the exercise: a static mockup teaches the resource model,
but it is not itself a live machine.

## Putting Redfish in front of libvirt

Next, I created two small, empty libvirt domains. Libvirt is the backend that knows how to define,
start, stop, and inspect the virtual machines. sushy-tools sits in front of it and exposes a Redfish
API.

The same kind of request a physical BMC would receive can then be sent to the emulator:

```sh
curl -X POST \
  -H 'Content-Type: application/json' \
  -d '{"ResetType":"ForceRestart"}' \
  http://127.0.0.1:8001/redfish/v1/Systems/<system-id>/Actions/ComputerSystem.Reset
```

For boot configuration, the controller can update the system resource:

```sh
curl -X PATCH \
  -H 'Content-Type: application/json' \
  -d '{"Boot":{"BootSourceOverrideEnabled":"Once","BootSourceOverrideTarget":"Pxe"}}' \
  http://127.0.0.1:8001/redfish/v1/Systems/<system-id>
```

The PATCH returned success, and the emulator reflected the PXE setting. The power operation also
worked once the VM definition was made compatible with Apple Silicon Hypervisor Framework.

That qualification matters. The first VM definitions failed because macOS libvirt could not create
Linux TAP devices for the default virtual network. Removing the NIC solved that part. QEMU then
failed because HVF does not support GICv2 emulation; pinning the ARM `virt` machine to GICv3 solved
that problem.

The protocol request was straightforward. The platform details were not.

## Putting IPMI in front of the same VMs

VirtualBMC provides the second management path. It exposes an IPMI endpoint while translating the
commands into libvirt operations:

```sh
ipmitool -I lanplus -H ::1 -p 6230 \
  -U admin -P password chassis status
```

The equivalent power and boot operations were:

```sh
ipmitool -I lanplus -H ::1 -p 6230 \
  -U admin -P password chassis power on

ipmitool -I lanplus -H ::1 -p 6230 \
  -U admin -P password chassis bootdev pxe options=efiboot
```

Status, power-on, and PXE selection worked. `chassis power cycle` did not: VirtualBMC returned
“Invalid data field in request.” The compatible command was:

```sh
ipmitool -I lanplus -H ::1 -p 6230 \
  -U admin -P password chassis power reset
```

That is a small but valuable lab result. “IPMI-compatible” does not mean every implementation
supports every command with identical semantics.

## Once versus Continuous boot override

Boot override is usually a one-boot instruction. `Once` means: use PXE for the next boot, then return
to the normal boot order. `Continuous` means every boot keeps trying PXE.

Continuous mode is useful during a tightly controlled provisioning workflow, but dangerous as a
default fleet state. If the deployment network is unavailable, a node can stop booting its local OS.
If provisioning succeeds but the controller forgets to clear the override, the next reboot can start
another installation or enter a deployment loop.

A fleet controller should therefore model boot override as state with an owner, an expiry, and an
explicit clear operation—not as a fire-and-forget flag.

## What does a 202 actually mean?

A Redfish power-cycle response of `202 Accepted` means the request was accepted for processing. It
does not mean the machine has completed its reboot or that it will become reachable again.

The controller should follow the operation or task if one is provided, poll the BMC and system
resources, apply a timeout and backoff policy, and verify that the node transitions through the
expected power states. If the BMC disappears, the node becomes `unknown` or `unreachable`; it does
not become “success” merely because the HTTP request was accepted.

Most importantly, the controller should avoid blindly issuing repeated destructive resets. A failed
power cycle can be a hardware problem, a BMC problem, a network problem, or a backend problem.

## Why IPMI is still around

Redfish is easier to inspect and automate: resources are JSON, links are discoverable, and the schema
can grow without adding an entirely new command family. Yet IPMI remains deeply embedded in existing
hardware, firmware, monitoring systems, and recovery playbooks.

Replacing it is not just a protocol migration. It is a fleet migration involving old hardware,
vendor-specific behavior, operational habits, and emergency procedures. Redfish may be the strategic
interface while IPMI remains the compatibility and recovery interface.

## What the emulators leave out

sushy-tools and VirtualBMC are useful precisely because they are small and testable. They validate
the control-plane integration: discovery, power commands, boot settings, and translation into a
virtualization backend.

They do not reproduce the full behavior of a physical BMC. Missing or simplified areas include:

- real temperature, voltage, fan, and power sensors;
- realistic System Event Log behavior;
- firmware-update workflows and rollback;
- vendor OEM commands;
- physical reset timing and hardware faults;
- BMC-specific authentication, TLS, and network quirks;
- the messy failure modes of real hardware.

The lab therefore proves that a controller can speak the protocol and drive a backend. It does not
prove that the controller is ready for every vendor’s hardware.

## The fleet-scale version

In a 10,000-node fleet, 2% unreachable means 200 nodes. A healthy control plane should isolate those
nodes rather than allowing them to block the other 9,800. It should retry with bounded exponential
backoff, spread retries over time, record the last known state, and alert operators.

It should refuse to claim success, repeatedly power-cycle an unreachable node, or create a retry storm
that takes down the management network. If another path exists—IPMI, serial console, provider API,
or a physical-location workflow—the controller can use it as a fallback, but it should preserve the
uncertainty in its state model.

## Closing thought

The most useful part of this exercise was not the happy path. It was seeing the layers clearly:

```text
Redfish client  ->  sushy-tools  ->  libvirt  ->  QEMU
IPMI client     ->  VirtualBMC   ->  libvirt  ->  QEMU
```

Both protocols can drive the same virtual machines. Neither emulator is a physical BMC. And a
successful management request is only the beginning of the verification story.
