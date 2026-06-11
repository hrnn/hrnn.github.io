#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/optimize-images-docker.sh IMAGE_DIR [MAX_WIDTH] [QUALITY]

Examples:
  scripts/optimize-images-docker.sh assets/images/2015-10-30-my-first-visit-to-the-bay-area
  scripts/optimize-images-docker.sh assets/images/2015-10-30-my-first-visit-to-the-bay-area 1500 82

Creates .webp files beside .jpg, .jpeg, .png, .heic, and .heif originals.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 ]]; then
  usage
  exit 0
fi

image_dir="${1%/}"
max_width="${2:-1500}"
quality="${3:-82}"

if [[ ! -d "$image_dir" ]]; then
  echo "Image directory does not exist: $image_dir" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required but was not found in PATH." >&2
  exit 1
fi

repo_root="$(pwd)"

echo "Image directory: $image_dir"
echo "Max width:       $max_width"
echo "WebP quality:    $quality"
echo "Docker image:    alpine:3.20"
echo

docker run --rm -i \
  -v "$repo_root:/work" \
  -w /work \
  -e IMAGE_DIR="$image_dir" \
  -e MAX_WIDTH="$max_width" \
  -e QUALITY="$quality" \
  alpine:3.20 \
  sh -eu <<'CONTAINER_SCRIPT'
echo "Installing ImageMagick in disposable container..."
apk add --no-cache imagemagick imagemagick-jpeg imagemagick-webp imagemagick-tiff imagemagick-heic >/dev/null
echo "ImageMagick installed: $(magick -version | sed -n '1s/^Version: //p')"
echo

tmp_list="$(mktemp)"
find "$IMAGE_DIR" -maxdepth 1 -type f \( \
  -iname '*.jpg' -o \
  -iname '*.jpeg' -o \
  -iname '*.png' -o \
  -iname '*.heic' -o \
  -iname '*.heif' \
\) | sort > "$tmp_list"

total="$(wc -l < "$tmp_list" | tr -d ' ')"

if [ "$total" -eq 0 ]; then
  echo "No .jpg, .jpeg, .png, .heic, or .heif files found directly in: $IMAGE_DIR" >&2
  echo "Files currently in that directory:" >&2
  find "$IMAGE_DIR" -maxdepth 1 -type f -print | sort >&2
  exit 1
fi

echo "Found $total image(s) to convert."
echo

converted=0
while IFS= read -r img; do
  base="${img%.*}"
  out="${base}.webp"
  before="$(du -h "$img" | awk '{print $1}')"

  echo "Converting: $img"

  magick "$img" \
    -auto-orient \
    -resize "${MAX_WIDTH}x${MAX_WIDTH}>" \
    -strip \
    -quality "$QUALITY" \
    "$out"

  after="$(du -h "$out" | awk '{print $1}')"
  converted=$((converted + 1))
  printf 'Created:    %s (%s -> %s)\n\n' "$out" "$before" "$after"
done < "$tmp_list"

echo "Done. Converted $converted image(s)."
CONTAINER_SCRIPT
