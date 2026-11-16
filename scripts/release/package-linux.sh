#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 ]]; then
    echo "usage: $0 <installed-prefix> <output-archive.tar.gz>" >&2
    exit 2
fi
prefix="$(realpath "$1")"
archive="$(realpath -m "$2")"
: "${LINUXDEPLOY:?path to linuxdeploy AppImage is required}"
: "${BUILD_VARIANT:?build variant is required}"
cuda_home="${CUDA_HOME:-/usr/local/cuda}"
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
appdir="${tmp}/colmap"
mkdir -p "$(dirname "$archive")" "${tmp}/stubs"

export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export APPIMAGE_EXTRACT_AND_RUN=1
export QMAKE="${QMAKE:-/usr/bin/qmake6}"

libraries=(
    --library "${prefix}/lib/libonnxruntime.so.1"
)
if [[ "$BUILD_VARIANT" != cpu ]]; then
    : "${CUDNN_LIBRARY_DIR:?directory containing cuDNN shared libraries is required}"
    # CUDA's stub is used only while scanning dependencies; it is never shipped.
    ln -s "${cuda_home}/targets/x86_64-linux/lib/stubs/libcuda.so" "${tmp}/stubs/libcuda.so.1"
    export LD_LIBRARY_PATH="${prefix}/lib:${CUDNN_LIBRARY_DIR}:${cuda_home}/lib64:${tmp}/stubs${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
    libraries+=(--library "${prefix}/lib/libonnxruntime_providers_shared.so"
                --library "${prefix}/lib/libonnxruntime_providers_cuda.so")
    shopt -s nullglob
    cudnn=("${CUDNN_LIBRARY_DIR}"/libcudnn*.so.9)
    if (( ${#cudnn[@]} == 0 )); then
        echo "cuDNN libraries not found in ${CUDNN_LIBRARY_DIR}" >&2
        exit 1
    fi
    for library in "${cudnn[@]}" "${cuda_home}"/targets/x86_64-linux/lib/libnvrtc*.so.*; do
        libraries+=(--library "$library")
    done
fi
"$LINUXDEPLOY" --appdir "$appdir" \
    --executable "${prefix}/bin/colmap" \
    "${libraries[@]}" --exclude-library 'libcuda.so*' --plugin qt

install -m 755 "${repo_root}/scripts/release/colmap-launcher.sh" "${appdir}/colmap"
mkdir -p "${appdir}/licenses/onnxruntime"
cp "${repo_root}/LICENSE" "${appdir}/licenses/COLMAP.txt"
cp "${prefix}/share/colmap/third-party/onnxruntime/"* "${appdir}/licenses/onnxruntime/"
if [[ "$BUILD_VARIANT" != cpu ]]; then
    mkdir -p "${appdir}/licenses/nvidia"
    cp /NGC-DL-CONTAINER-LICENSE "${appdir}/licenses/nvidia/CONTAINER-LICENSE.txt"
    for notice in /usr/share/doc/{cuda*,libcu*,libnv*}/copyright; do
        install -Dm644 "$notice" "${appdir}/licenses/nvidia/$(basename "$(dirname "$notice")").txt"
    done
elif find "${appdir}/usr/lib" -maxdepth 1 \( -name 'libcudart.so*' -o -name 'libonnxruntime_providers_cuda.so' \) -print -quit | grep -q .; then
    echo "CPU distribution unexpectedly contains CUDA libraries" >&2
    exit 1
fi

if [[ -n "$(find "${appdir}/usr/lib" -maxdepth 1 -name 'libcuda.so*' -print -quit)" ]]; then
    echo "Refusing to bundle an NVIDIA driver or CUDA stub" >&2
    exit 1
fi
readelf --version-info "${appdir}/usr/lib/libonnxruntime.so.1" | grep -F 'VERS_1.30.0' > /dev/null
env -u LD_LIBRARY_PATH "${appdir}/colmap" version
tar -C "$tmp" -czf "$archive" colmap
(cd "$(dirname "$archive")" && sha256sum "$(basename "$archive")" > "$(basename "$archive").sha256")
