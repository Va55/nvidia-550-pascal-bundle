# NVIDIA 550.163.01 + CUDA 12.4 — Pascal Offline Installer

**Last driver branch supporting Pascal GPUs** (Tesla P4, GTX 1080, etc.).  
NVIDIA dropped Pascal support starting with the 560 driver branch.

## Quick start

```bash
sudo ./nvidia-550-pascal-install.sh
```

The script fetches packages from Debian's official non-free repositories, pins them to version 550, and installs everything — driver, CUDA runtime, kernel module, and persistence daemon.

### Skip CUDA

```bash
sudo ./nvidia-550-pascal-install.sh --no-cuda
```

## What gets installed

| Component | Version | Source |
|-----------|---------|--------|
| NVIDIA Driver | 550.163.01-2 | Debian trixie non-free |
| CUDA Runtime | 12.4.1 | Debian trixie non-free |
| CUDA Toolkit | 12.4.131 | Debian trixie non-free |
| cuBLAS | 12.4.5.8 | Debian trixie non-free |

## How it works

1. **Enables** `deb.debian.org` non-free repos (if not already configured)
2. **Pins** all nvidia packages to `550.*` so `apt upgrade` won't pull in a Pascal-incompatible driver
3. **Installs** the driver stack and optional CUDA toolkit
4. **Builds** the kernel module via DKMS
5. **Starts** `nvidia-persistenced` for stable GPU state

All packages come from **Debian's official repositories** — no redistribution of NVIDIA binaries.

## Requirements

- Debian 13 (Trixie) or compatible
- Root access (sudo)
- Internet connection (fetches ~600 MB of packages)
- Pascal-family GPU (Tesla P4/P40, GTX 1050–1080 Ti, Quadro Pxxx)

## License

The installer script is provided under the MIT license.  
The NVIDIA driver and CUDA toolkit are governed by the [NVIDIA Driver License Agreement](LICENSE.txt).

## Why 550?

| Driver branch | Pascal support |
|---------------|----------------|
| 550.x | ✅ Full support |
| 560.x | ❌ Dropped |
| 570.x | ❌ Dropped |
| 595.x | ❌ Dropped |
