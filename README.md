# job-runner-public

Public mirror of the init scripts and per-case dependency manifests
that prepare a fresh VM for the private job-runner framework. The
canonical sources live in a private repository; this mirror exists
only so a fresh VM can `curl` files without needing credentials.

## How VMs use this

In the production fleet flow, **VMs do not run these scripts
manually**. Each VM is created with `startup-script-url` pointing
at `resource-setup/stage-1.sh`; GCP runs it as root on first boot
and the VM bootstraps itself end-to-end (platform install →
Filestore mount → workload setup → init test). The operator just
runs `./create-fleet.sh <vcpus> <task_name>` from the service VM
and waits for status files to appear in
`~/job-runner-cloud/init-status/`.

The two-stage chain:

1. **`stage-1.sh` (entry)** — universal: reads VM metadata
   (`platform`, `filestore-ip`, `task`), curls the matching
   platform script (e.g. `ubuntu-python-cpu.sh`) for OS/runtime
   install, mounts Filestore, sets up the `~/job-runner-cloud`
   symlink, then hands off to stage-2.
2. **`stage-2.sh` (private, on Filestore)** — clones into the
   workspace for the given task, runs `uv sync`, runs the
   workload's `init-test.py`, writes a per-VM `.ok` or `.fail`
   marker.

Only stage-1 and the platform scripts are mirrored here; stage-2
is private and the operator copies it to Filestore manually.

## Manual standalone use

If you're setting up a single VM by hand (no fleet, no Filestore):

```bash
# Just the platform install (apt + uv + sysbench + machine facts):
curl -sSL https://raw.githubusercontent.com/matveev-project/job-runner-public/main/resource-setup/ubuntu-python-cpu.sh | bash

# Optional: case-specific deps if you want a Python env ready
curl -sSL https://raw.githubusercontent.com/matveev-project/job-runner-public/main/case-qeeg/pyproject.toml -o pyproject.toml
uv sync
```

The platform script prints machine facts on its final line:
```
os=<id>-<version> cpu_cores=<N> cpu_score=<events/sec> ram_gb=<N>
```

## Layout

```
resource-setup/
  stage-1.sh              # universal entry; what GCP startup-script-url points at
  ubuntu-python-cpu.sh    # platform install for Ubuntu 24 + Python + CPU
case-qeeg/
  pyproject.toml          # qEEG workload Python dependencies
```

Additional platform variants (`ubuntu-python-gpu.sh`,
`ubuntu-rust-cpu.sh`) and additional case manifests get mirrored
here as they're implemented upstream.
