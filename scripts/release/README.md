# Linux release builds

The `Linux CUDA release archives` workflow builds Linux x86-64 CUDA 12.9 and
13.0 archives with GUI, CUDA, and ONNX enabled. It targets compute capabilities
75, 80, 86, 89, 90, 100, 103, and 120. The MVS Blackwell path uses PTX because
of an NVCC workaround. GTX 1070 (sm_61) is not included.

Extract an archive and run `./colmap/colmap gui` or `./colmap/colmap -h`.
The archive includes CUDA user-space libraries and cuDNN, but not the NVIDIA
driver. Ubuntu 24.04 or a compatible Linux distribution, a compatible driver,
and system graphics libraries are required. CUDA 13.0.2 recommends NVIDIA driver
580.95.05 or newer. PTX JIT or newer toolkit features may require a newer driver. See the
[NVIDIA compatibility documentation](https://docs.nvidia.com/deploy/cuda-compatibility/).

The workflow checks the archive with an X11 GUI launch on Xvfb, and with CPU
ALIKED and LightGlue inference. GitHub's standard hosted runners do not have a
GPU: a successful workflow does not prove GPU inference or MVS execution.
Record separate hardware test results in the release notes. ONNX models are
downloaded on first use.

The build container must be disposable; `build-linux-container.sh` installs
system packages. `package-linux.sh` requires the installed COLMAP prefix,
`LINUXDEPLOY`, `CUDNN_LIBRARY_DIR`, and optionally `CUDA_HOME` and `QMAKE`.
The workflow pins and verifies the linuxdeploy and Qt plugin downloads.
