#!/usr/bin/env bash
set -euo pipefail

if [[ "${COLMAP_CONTAINER_BUILD:-}" != 1 || $EUID != 0 ]]; then
    echo "Run only inside the disposable CUDA build container as root" >&2
    exit 2
fi
: "${CUDA_RELEASE:?CUDA release label is required}"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    build-essential cmake ninja-build git curl ca-certificates binutils patchelf \
    libboost-program-options-dev libboost-graph-dev libboost-system-dev \
    libeigen3-dev libopenimageio-dev openimageio-tools libopencv-core-dev \
    libmetis-dev libgoogle-glog-dev libxkbcommon-dev \
    libsqlite3-dev libglew-dev qt6-base-dev qt6-svg-dev libceres-dev \
    libsuitesparse-dev libcurl4-openssl-dev libssl-dev libgl1-mesa-dev \
    python3 python3-numpy python3-pil sqlite3
git config --global --add safe.directory /work

cmake -S /work -B /work/build-release-ci -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/work/install-release-ci \
    -DCMAKE_INSTALL_LIBDIR=lib \
    '-DCMAKE_CUDA_ARCHITECTURES=75;80;86;89;90;100;103;120' \
    -DCUDA_ENABLED=ON -DONNX_ENABLED=ON -DFETCH_ONNX=ON \
    -DGUI_ENABLED=ON -DCGAL_ENABLED=OFF -DCASPAR_ENABLED=OFF -DTESTS_ENABLED=OFF
cmake --build /work/build-release-ci --parallel 2
cmake --install /work/build-release-ci

tools_dir="$(mktemp -d)"
trap 'rm -rf -- "$tools_dir"' EXIT
curl -fsSL https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage -o "${tools_dir}/linuxdeploy-x86_64.AppImage"
curl -fsSL https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage -o "${tools_dir}/linuxdeploy-plugin-qt-x86_64.AppImage"
printf '%s  %s\n' \
    df908b19f1ed1cdafa79508d415aa12d6c56ce4d56d4149aa8c09286718706e5 "${tools_dir}/linuxdeploy-x86_64.AppImage" \
    cfc1055b2b9dbc08412b579f20990b7b41a17b61beaa5847dc9477c96c9e9617 "${tools_dir}/linuxdeploy-plugin-qt-x86_64.AppImage" | sha256sum -c -
chmod +x "${tools_dir}"/*.AppImage
export PATH="${tools_dir}:${PATH}"
export LINUXDEPLOY="${tools_dir}/linuxdeploy-x86_64.AppImage"
export CUDNN_LIBRARY_DIR=/usr/lib/x86_64-linux-gnu
archive="/work/dist/colmap-linux-x86_64-cuda${CUDA_RELEASE}-$(git -C /work rev-parse --short=8 HEAD).tar.gz"
bash /work/scripts/release/package-linux.sh /work/install-release-ci "$archive"

# Exercise the unpacked distribution without the build environment's libraries.
tar -xzf "$archive" -C "$tools_dir"
mkdir "${tools_dir}/images"
python3 -c 'import numpy as np; from PIL import Image,ImageFilter; import sys; a=np.random.default_rng(42).integers(0,256,(256,256,3),dtype=np.uint8); im=Image.fromarray(a).filter(ImageFilter.GaussianBlur(2)); [im.save(f"{sys.argv[1]}/{i}.png") for i in (1,2)]' "${tools_dir}/images"
binary="${tools_dir}/colmap/colmap"
env -u LD_LIBRARY_PATH "$binary" feature_extractor --database_path "${tools_dir}/test.db" \
    --image_path "${tools_dir}/images" --FeatureExtraction.type ALIKED_N16ROT \
    --FeatureExtraction.use_gpu 0 --FeatureExtraction.num_threads 1 \
    --AlikedExtraction.max_num_features 512 --AlikedExtraction.min_score 0.05
env -u LD_LIBRARY_PATH "$binary" exhaustive_matcher --database_path "${tools_dir}/test.db" \
    --FeatureMatching.type ALIKED_LIGHTGLUE --FeatureMatching.use_gpu 0 \
    --FeatureMatching.num_threads 1 --FeatureMatching.skip_geometric_verification 1
[[ "$(sqlite3 "${tools_dir}/test.db" 'SELECT count(*) FROM keypoints WHERE rows > 0')" == 2 ]]
[[ "$(sqlite3 "${tools_dir}/test.db" 'SELECT coalesce(sum(rows),0) FROM matches')" -gt 0 ]]
