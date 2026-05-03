#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/stage-1.log 2>&1

[ -f /var/lib/job-runner-init.done ] && exit 0

# Capture stage-1 entry time for the init-stage elapsed measurement.
# stage-2 reads this when it marks init-status, so the recorded time
# covers the full bootstrap (apt + uv install + NFS mount + uv sync).
date +%s > /var/lib/job-runner-stage-1.start

# Stop + mask Ubuntu's auto-update services before any apt operations.
# At first boot one of these grabs the dpkg lock to apply security
# patches, blocking stage-1 for 15-20 min on unlucky VMs. Ephemeral
# fleet VMs don't need unattended security updates — they're killed
# after the task.
systemctl stop unattended-upgrades.service apt-daily.service apt-daily-upgrade.service 2>/dev/null || true
systemctl mask unattended-upgrades.service apt-daily.service apt-daily-upgrade.service 2>/dev/null || true

META="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
HEADER="Metadata-Flavor: Google"
PUBLIC_BASE="https://raw.githubusercontent.com/matveev-project/job-runner-public/main/resource-setup"

PLATFORM=$(curl -sf -H "$HEADER" "$META/platform")
FILESTORE_IP=$(curl -sf -H "$HEADER" "$META/filestore-ip")
TASK=$(curl -sf -H "$HEADER" "$META/task")

runuser -u ubuntu -- bash -c "curl -sSL '${PUBLIC_BASE}/${PLATFORM}.sh' | bash"

apt-get install -y -qq nfs-common
mkdir -p /nss_data
mount -t nfs \
    -o nconnect=8,rsize=1048576,wsize=1048576,hard,timeo=600 \
    "${FILESTORE_IP}:/data" /nss_data

CLOUD_ROOT="/nss_data/users/am-work-space/job-runner-cloud"
ln -sfn "$CLOUD_ROOT" /root/job-runner-cloud
ln -sfn "$CLOUD_ROOT" /home/ubuntu/job-runner-cloud
chown -h ubuntu:ubuntu /home/ubuntu/job-runner-cloud

# Mark this VM's SIMD code path so list-fleet.sh can show whether
# the host has AVX-512. SIMD width — not vendor — is the principled
# axis for FOOOF reproducibility (see qeeg-calc/amd-vs-intel-fooof.md
# "Framing correction" + the AVX-512 mechanism addendum). Read
# /proc/cpuinfo flags directly so the marker is correct for any new
# CPU model, no lookup table to keep current.
SIMD_DIR="$CLOUD_ROOT/simd-status"
mkdir -p "$SIMD_DIR"
if grep -q '^flags.*\bavx512f\b' /proc/cpuinfo; then
    echo "AVX-512" > "$SIMD_DIR/$(hostname)"
else
    echo "AVX2"    > "$SIMD_DIR/$(hostname)"
fi

echo 'UV_PROJECT_ENVIRONMENT=/home/ubuntu/.venv' >> /etc/environment

touch /var/lib/job-runner-init.done
exec runuser -u ubuntu -- bash /home/ubuntu/job-runner-cloud/vm-init/stage-2.sh "$TASK"
