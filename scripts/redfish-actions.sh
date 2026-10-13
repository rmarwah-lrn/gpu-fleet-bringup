#!/bin/sh
set -eu
base=${1:-http://127.0.0.1:8000}
systems=$(curl --fail --silent "$base/redfish/v1/Systems/")
system=$(printf '%s' "$systems" | python3 -c 'import json,sys; print(json.load(sys.stdin)["Members"][0]["@odata.id"])')

printf '%s\n' "--- system: $system ---"
curl --fail --silent "$base$system" | python3 -m json.tool
printf '%s\n' '--- power on ---'
curl --fail --silent --show-error -X POST -H 'Content-Type: application/json' \
  -d '{"ResetType":"On"}' "$base$system/Actions/ComputerSystem.Reset" || true
printf '%s\n' '--- request PXE boot on next boot ---'
curl --fail --silent --show-error -X PATCH -H 'Content-Type: application/json' \
  -d '{"Boot":{"BootSourceOverrideEnabled":"Once","BootSourceOverrideTarget":"Pxe"}}' \
  "$base$system" || true
printf '%s\n' '--- power cycle ---'
curl --fail --silent --show-error -X POST -H 'Content-Type: application/json' \
  -d '{"ResetType":"ForceRestart"}' "$base$system/Actions/ComputerSystem.Reset" || true
printf '%s\n' 'The mockup may reject writes; run this against sushy-tools for live VM operations.'
