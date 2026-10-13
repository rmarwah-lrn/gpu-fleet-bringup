#!/bin/sh
set -eu
port=${VBMC_PORT_0:-6230}
host=${VBMC_HOST:-::1}
interface=${IPMI_INTERFACE:-lanplus}
printf '%s\n' '--- chassis status ---'
ipmitool -I "$interface" -H "$host" -p "$port" -U admin -P password chassis status
printf '%s\n' '--- power on ---'
ipmitool -I "$interface" -H "$host" -p "$port" -U admin -P password chassis power on
printf '%s\n' '--- set PXE boot for next boot ---'
ipmitool -I "$interface" -H "$host" -p "$port" -U admin -P password chassis bootdev pxe options=efiboot
printf '%s\n' '--- power cycle ---'
if ! ipmitool -I "$interface" -H "$host" -p "$port" -U admin -P password chassis power cycle; then
    printf '%s\n' 'VirtualBMC rejected power cycle; using IPMI reset instead.'
    ipmitool -I "$interface" -H "$host" -p "$port" -U admin -P password chassis power reset
fi
