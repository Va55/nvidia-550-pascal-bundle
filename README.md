# NVIDIA 550.163.01 + CUDA 12.4 — Pascal Legacy Driver

**Last driver branch supporting Pascal GPUs** (Tesla P4, GTX 1080, etc.).  
NVIDIA dropped Pascal support starting with the 560 driver branch.

## Quick start

### Debian / Ubuntu (apt)

```bash
sudo ./nvidia-550-pascal-install.sh
```

The script fetches packages from Debian's official non-free repositories, pins them to version 550, and installs everything — driver, CUDA runtime, kernel module, and persistence daemon.

### Fedora / RHEL / Rocky / Alma (rpm / dnf)

```bash
sudo ./nvidia-550-pascal-install-rpm.sh
```

The script downloads the official NVIDIA 550.163.01 `.run` installer (and optional CUDA 12.4.1 `.run`), installs prerequisites via `dnf`/`yum`, blacklists nouveau, builds the kernel module via DKMS, and starts `nvidia-persistenced`.

### Skip CUDA

```bash
# Debian
sudo ./nvidia-550-pascal-install.sh --no-cuda

# RPM
sudo ./nvidia-550-pascal-install-rpm.sh --no-cuda
```

## What gets installed

### Debian

| Component | Version | Source |
|-----------|---------|--------|
| NVIDIA Driver | 550.163.01-2 | Debian trixie non-free |
| CUDA Runtime | 12.4.1 | Debian trixie non-free |
| CUDA Toolkit | 12.4.131 | Debian trixie non-free |
| cuBLAS | 12.4.5.8 | Debian trixie non-free |

### RPM

| Component | Version | Source |
|-----------|---------|--------|
| NVIDIA Driver | 550.163.01 | NVIDIA official runfile |
| CUDA Toolkit | 12.4.1 | NVIDIA official runfile |

## How it works

### Debian

1. **Enables** `deb.debian.org` non-free repos (if not already configured)
2. **Pins** all nvidia packages to `550.*` so `apt upgrade` won't pull in a Pascal-incompatible driver
3. **Installs** the driver stack and optional CUDA toolkit
4. **Builds** the kernel module via DKMS
5. **Starts** `nvidia-persistenced` for stable GPU state

All packages come from **Debian's official repositories** — no redistribution of NVIDIA binaries.

### RPM

1. **Installs** build prerequisites (`dkms`, `kernel-devel`, `gcc`, etc.) via `dnf`/`yum`
2. **Blacklists** nouveau driver and regenerates initramfs
3. **Downloads** the official NVIDIA 550.163.01 `.run` installer (~307 MB)
4. **Installs** the driver with `--dkms` for automatic kernel module rebuilds
5. **Optionally** downloads and installs CUDA 12.4.1 `.run` (~4.4 GB)
6. **Starts** `nvidia-persistenced` via systemd

All binaries are downloaded directly from **NVIDIA's official servers** — no redistribution of NVIDIA binaries.

## Requirements

- **Debian**: Debian 13 (Trixie) or compatible
- **RPM**: Fedora 39+ / RHEL 9 / Rocky 9 / Alma 9
- Root access (sudo)
- Internet connection (Debian: ~600 MB; RPM: ~300 MB driver, +4.4 GB with CUDA)
- Pascal-family GPU (Tesla P4/P40, GTX 1050–1080 Ti, Quadro Pxxx)

## License

The installer scripts are provided under the MIT license.  
The NVIDIA driver and CUDA toolkit are governed by the [NVIDIA Driver License Agreement](LICENSE.txt).

## Why 550?

| Driver branch | Pascal support |
|---------------|----------------|
| 550.x | ✅ Full support |
| 560.x | ❌ Dropped (consumer) |
| 570.x | ❌ Dropped |
| 595.x | ❌ Dropped |

> **Note:** The Tesla/Data Center driver branch (R560) still supports Pascal GPUs (Tesla P4/P40/P100, Quadro Pxxxx). If your distro packages the Tesla branch, that's also an option. These scripts target the consumer 550 branch.
