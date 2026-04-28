#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/stage-1.log 2>&1

[ -f /var/lib/job-runner-init.done ] && exit 0

META="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
HEADER="Metadata-Flavor: Google"
PUBLIC_BASE="https://raw.githubusercontent.com/matveev-project/job-runner-public/main/resource-setup"

PLATFORM=$(curl -sf -H "$HEADER" "$META/platform")
FILESTORE_IP=$(curl -sf -H "$HEADER" "$META/filestore-ip")
TASK=$(curl -sf -H "$HEADER" "$META/task")

curl -sSL "${PUBLIC_BASE}/${PLATFORM}.sh" | bash

apt-get install -y -qq nfs-common
mkdir -p /nss_data
mount -t nfs \
    -o nconnect=8,rsize=1048576,wsize=1048576,hard,timeo=600 \
    "${FILESTORE_IP}:/data" /nss_data

CLOUD_ROOT="/nss_data/users/am-work-space/job-runner-cloud"
ln -sfn "$CLOUD_ROOT" /root/job-runner-cloud
ln -sfn "$CLOUD_ROOT" /home/ubuntu/job-runner-cloud
chown -h ubuntu:ubuntu /home/ubuntu/job-runner-cloud

touch /var/lib/job-runner-init.done
exec bash /root/job-runner-cloud/vm-init/stage-2.sh "$TASK"
