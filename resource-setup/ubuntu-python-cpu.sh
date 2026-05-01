#!/usr/bin/env bash
set -euo pipefail

# Repoint Ubuntu's security suite to the GCE regional mirror. The cloud
# image's default security URL is the geo-routed security.ubuntu.com,
# which intermittently stalls or times out (~4-minute apt-get update
# on ~7% of VMs in our us-central1 fleet, observed twice in 27 boots).
# us-central1.gce.archive.ubuntu.com serves noble-security with the
# same content at ~10 ms — strict upgrade.
sudo -n sed -i 's|http://security.ubuntu.com/ubuntu|http://us-central1.gce.archive.ubuntu.com/ubuntu|' \
    /etc/apt/sources.list.d/ubuntu.sources

# Bound apt's stall behaviour. Defaults are Acquire::http::Timeout=120
# and Acquire::Retries=0; with Timeout=15 + Retries=3 a transient
# blip recovers cleanly. Note: Timeout is the no-data (idle) timer,
# so it doesn't bound a slow-trickle response. The 50-280 s tail
# we observe in apt-get update comes from the regional mirror
# trickling many small files; further reduction needs a custom
# image (pre-installed packages) — see resource-setup/README.md.
#
# Why apt-get update is required: empirically (May 1 2026) the
# stock ubuntu-2404-noble cloud images ship /var/lib/apt/lists/
# with only the security suite populated — main/universe lists
# are absent, so `apt-get install` fails for any package outside
# main-security. Minimal variants strip even those. Both
# verified the hard way; do not skip this line.
APT_OPTS=(-o "Acquire::http::Timeout=15" -o "Acquire::Retries=3")
sudo -n apt-get "${APT_OPTS[@]}" update -qq
sudo -n apt-get "${APT_OPTS[@]}" install -y -qq git sysbench htop btop

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
