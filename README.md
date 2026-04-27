# job-runner-public

Public mirror of the one-time init scripts and per-case dependency
manifests that prepare a fresh VM for the private job-runner
framework. The canonical source lives in a private repository; this
mirror exists only so a fresh VM can `curl` files without needing
credentials.

## Two-step setup

A fresh VM goes through **two stages**:

1. **General init** — install OS-level dependencies (`git`,
   `sysbench`, `uv`), benchmark the CPU, print machine facts.
   One-time per VM, regardless of the workload it will run.
2. **Case-specific setup** — fetch the workload's `pyproject.toml`
   and let `uv sync` materialize its Python environment.

For a fresh Ubuntu 24 cloud VM running the qEEG workload:

```bash
# Step 1: general init
curl -sSL https://raw.githubusercontent.com/matveev-project/job-runner-public/main/resource-setup/ubuntu-python-cpu.sh | bash

# Step 2: case-specific deps (qEEG)
curl -sSL https://raw.githubusercontent.com/matveev-project/job-runner-public/main/case-qeeg/pyproject.toml -o pyproject.toml
uv sync
```

After step 2 the VM has a Python environment with `numpy`, `scipy`,
`pandas`, `mne`, `fooof`, `antropy`, `numba`, and `tqdm` ready to
use.

## Layout

```
resource-setup/
  ubuntu-python-cpu.sh     # fresh Ubuntu 24 cloud VM, CPU-only Python workloads
case-qeeg/
  pyproject.toml           # qEEG workload Python dependencies
```

Additional init-script variants (GPU, Rust) and additional case
manifests are mirrored here as they are implemented upstream.
