#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/stage-1.log 2>&1

[ -f /var/lib/job-runner-init.done ] && exit 0

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

echo 'UV_PROJECT_ENVIRONMENT=/home/ubuntu/.venv' >> /etc/environment

touch /var/lib/job-runner-init.done
exec runuser -u ubuntu -- bash /home/ubuntu/job-runner-cloud/vm-init/stage-2.sh "$TASK"
