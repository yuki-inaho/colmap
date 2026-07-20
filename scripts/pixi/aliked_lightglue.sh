#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
database_path="${COLMAP_DATABASE_PATH:-}"

if [[ -z "$database_path" ]]; then
  echo "COLMAP_DATABASE_PATH must point to the COLMAP database file." >&2
  exit 2
fi

case "$mode" in
  extract)
    image_path="${COLMAP_IMAGE_PATH:-}"
    if [[ -z "$image_path" ]]; then
      echo "COLMAP_IMAGE_PATH must point to the input image directory." >&2
      exit 2
    fi
    exec colmap feature_extractor \
      --database_path "$database_path" \
      --image_path "$image_path" \
      --FeatureExtraction.type ALIKED_N16ROT \
      --AlikedExtraction.max_num_features 2048
    ;;
  match)
    exec colmap exhaustive_matcher \
      --database_path "$database_path" \
      --FeatureMatching.type ALIKED_LIGHTGLUE
    ;;
  *)
    echo "usage: $0 {extract|match}" >&2
    exit 2
    ;;
esac
