#!/usr/bin/env bash
set -euo pipefail

sudo -n apt-get update -qq
sudo -n apt-get install -y -qq git sysbench htop btop

# Pre-seed btop config so tmux-fleet's `btop -p 2` actually renders
# preset 2's boxes (cpu+mem+net). btop's compiled default for
# `shown_boxes` includes proc, and `-p N` doesn't override the saved
# config — so without this line, btop's auto-written config would
# render all four boxes regardless of the preset flag.
mkdir -p ~/.config/btop
echo 'shown_boxes = "cpu mem net"' > ~/.config/btop/btop.conf

if ! command -v uv >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

cpu_cores="$(nproc)"
ram_kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
ram_gb="$(( (ram_kb + 524288) / 1048576 ))"
os="$(. /etc/os-release && printf '%s-%s' "$ID" "$VERSION_ID")"

cpu_score="$(sysbench cpu --threads=1 --time=10 run \
    | awk '/events per second:/ {printf "%d", $4}')"

echo
echo "os=${os} cpu_cores=${cpu_cores} cpu_score=${cpu_score} ram_gb=${ram_gb}"
