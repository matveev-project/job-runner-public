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

# Skip `apt-get update` and rely on the cloud image's pre-baked apt
# indices. Empirically `apt-get update` was the dominant boot-time
# variance (50-280 s tail across 36 boots) — the regional GCE mirror
# trickles slowly enough that Acquire::http::Timeout=15 doesn't
# trigger (it's a no-data timeout). The standard ubuntu-2404-noble
# cloud image ships /var/lib/apt/lists/ pre-populated; the minimal
# variant strips those (verified the hard way, May 1 2026), so this
# path requires the standard image. Indices age slowly between
# Canonical's image rebuilds (~weekly); for our stable package set
# (git/sysbench/htop/btop) the risk a referenced .deb has been
# superseded is near zero — install fails fast on stale-index miss,
# so we'd notice immediately. apt-get install retains
# Timeout/Retries against transient .deb-fetch stalls.
APT_OPTS=(-o "Acquire::http::Timeout=15" -o "Acquire::Retries=3")
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
