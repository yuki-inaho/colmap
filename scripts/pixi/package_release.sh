#!/usr/bin/env bash
# Package the installed COLMAP artifacts into a relocatable release tarball.
# Run inside the pixi environment after `pixi run install-colmap`:
#   pixi run bash scripts/pixi/package_release.sh
set -euo pipefail
: "${CONDA_PREFIX:?must run inside the pixi environment (pixi run ...)}"
build="${COLMAP_BUILD_DIR:-build}"
out="${COLMAP_DIST_DIR:-dist}"
manifest="${build}/install_manifest.txt"
[[ -f "$manifest" ]] || { echo "no install manifest: $manifest (run 'pixi run install-colmap' first)" >&2; exit 1; }

version="$("${CONDA_PREFIX}/bin/colmap" -h 2>&1 | head -1 | awk '{print $2}')"
arch="${COLMAP_CUDA_ARCH:-120}"
name="colmap-${version}-linux-x86_64-cuda-sm${arch//;/_}"
mkdir -p "$out"

list="$(mktemp)"; trap 'rm -f "$list"' EXIT
sed "s|^${CONDA_PREFIX}/||" "$manifest" | sort -u > "$list"

tar -czf "${out}/${name}.tar.gz" -C "$CONDA_PREFIX" --owner=0 --group=0 -T "$list"
(cd "$out" && sha256sum "${name}.tar.gz" > "${name}.tar.gz.sha256")
echo "[package] ${out}/${name}.tar.gz ($(du -h "${out}/${name}.tar.gz" | cut -f1), $(wc -l < "$list") files)"
