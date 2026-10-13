#!/bin/sh
set -eu
base=${1:-http://127.0.0.1:8000}

get() {
    printf '\n--- GET %s ---\n' "$1"
    curl --fail --silent --show-error -H 'Accept: application/json' "$base$1"
    printf '\n'
}

get /redfish/v1/
get /redfish/v1/Systems/
get /redfish/v1/Managers/
get /redfish/v1/Chassis/
printf '\nTree walk complete. Continue with the @odata.id values above.\n'
