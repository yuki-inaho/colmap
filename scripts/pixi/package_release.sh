#!/usr/bin/env bash
# Package installed COLMAP artifacts as an overlay for a matching Pixi environment.
# COLMAP_INSTALL_PREFIX defaults to the Pixi prefix; an isolated staging prefix
# lets us build without replacing an existing COLMAP installation.
set -euo pipefail
: "${CONDA_PREFIX:?must run inside the pixi environment (pixi run ...)}"
build="${COLMAP_BUILD_DIR:-build}"
out="${COLMAP_DIST_DIR:-dist}"
install_prefix="${COLMAP_INSTALL_PREFIX:-${CONDA_PREFIX}}"
manifest="${build}/install_manifest.txt"
[[ -f "$manifest" ]] || { echo "no install manifest: $manifest (run 'pixi run install-colmap' first)" >&2; exit 1; }

[[ -x "${install_prefix}/bin/colmap" ]] || { echo "no installed COLMAP: ${install_prefix}/bin/colmap" >&2; exit 1; }
version="$("${install_prefix}/bin/colmap" -h 2>&1 | head -1 | awk '{print $2}')"
arch="$(sed -n 's/^CMAKE_CUDA_ARCHITECTURES:[^=]*=//p' "${build}/CMakeCache.txt")"
[[ -n "$arch" ]] || { echo "no CUDA architecture in ${build}/CMakeCache.txt" >&2; exit 1; }
if [[ "$arch" == *";"* ]]; then archtag="multiarch"; else archtag="sm${arch}"; fi
name="colmap-${version}-linux-x86_64-cuda-${archtag}"
mkdir -p "$out"

list="$(mktemp)"; trap 'rm -f "$list"' EXIT
while IFS= read -r installed_file || [[ -n "$installed_file" ]]; do
    [[ "$installed_file" == "$install_prefix/"* ]] || {
        echo "manifest entry outside install prefix: $installed_file" >&2
        exit 1
    }
    printf '%s\n' "${installed_file#"$install_prefix/"}"
done < "$manifest" | sort -u > "$list"

tar -czf "${out}/${name}.tar.gz" -C "$install_prefix" --owner=0 --group=0 -T "$list"
(cd "$out" && sha256sum "${name}.tar.gz" > "${name}.tar.gz.sha256")
echo "[package] ${out}/${name}.tar.gz ($(du -h "${out}/${name}.tar.gz" | cut -f1), $(wc -l < "$list") files)"
