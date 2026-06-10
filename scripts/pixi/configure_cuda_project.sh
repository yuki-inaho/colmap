#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 2 ]]; then echo "usage: $0 <src> <build> [extra cmake args...]" >&2; exit 2; fi
src="$1"; build="$2"; shift 2
cuda_arch="${COLMAP_CUDA_ARCH:-89}"
echo "[configure] src=$src build=$build cuda_arch=$cuda_arch"
cmake -S "$src" -B "$build" -G Ninja -DCMAKE_CUDA_ARCHITECTURES="$cuda_arch" "$@"
