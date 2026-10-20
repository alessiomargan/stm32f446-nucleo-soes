#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: setup_can0.sh

Configure the existing Linux SocketCAN interface can0 at 250000 bit/s.
The interface is briefly brought down to change its bitrate.
Requests sudo privileges when run as a regular user.

Requires iproute2 and a detected CAN adapter exposing can0.
EOF
}

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    usage
    exit 0
fi
if [[ $# -ne 0 ]]; then
    usage >&2
    exit 1
fi

command -v ip >/dev/null || {
    echo "Missing ip command; install iproute2." >&2
    exit 1
}
ip link show dev can0 >/dev/null 2>&1 || {
    echo "can0 does not exist. Check the CAN adapter and its driver configuration." >&2
    exit 1
}

if [[ $EUID -ne 0 ]]; then
    exec sudo -- bash "$0" "$@"
fi

ip link set dev can0 down
ip link set dev can0 type can bitrate 250000
ip link set dev can0 up
ip -details -statistics link show dev can0
