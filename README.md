# job-runner-public

Public mirror of the one-time init scripts that register a fresh VM
into a private job-runner resource pool. The canonical source lives
in a private repository; this mirror exists only so a fresh VM can
`curl` the script without needing credentials.

## Usage

On a fresh Ubuntu 24 cloud VM, for CPU-only Python workloads:

```
curl -sSL https://raw.githubusercontent.com/matveev-project/job-runner-public/main/resource-setup/ubuntu-python-cpu.sh | bash
```

The script installs minimal system dependencies plus `uv`, runs a
single-thread `sysbench cpu` benchmark, and prints machine facts
(`os`, `cpu_cores`, `cpu_score`, `ram_gb`) on its final line.

## Layout

```
resource-setup/
  ubuntu-python-cpu.sh     # fresh Ubuntu 24 cloud VM, CPU-only Python workloads
```

Additional variants (GPU, Rust) are mirrored here as they are
implemented upstream.
