#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/autocrop-webp-docker.sh INPUT_DIR [OUTPUT_DIR] [crop-cli options...]

Examples:
  scripts/autocrop-webp-docker.sh assets/images/foo
  scripts/autocrop-webp-docker.sh assets/images/foo assets/images/foo/cropped --object person --padding 10
  scripts/autocrop-webp-docker.sh assets/images/foo /tmp/cropped-webp --method rt-detr --confidence 0.5

Crops .webp files from INPUT_DIR into OUTPUT_DIR without changing originals.
OUTPUT_DIR defaults to INPUT_DIR/cropped.
The default AI detection method is YOLO unless --method is passed.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 ]]; then
  usage
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required but was not found in PATH." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"

input_dir="${1%/}"
shift

if [[ ! -d "$input_dir" ]]; then
  echo "Input directory does not exist: $input_dir" >&2
  exit 1
fi

if [[ $# -gt 0 && "${1:-}" != --* ]]; then
  output_dir="${1%/}"
  shift
else
  output_dir="$input_dir/cropped"
fi

mkdir -p "$output_dir"

input_abs="$(cd "$input_dir" && pwd -P)"
output_abs="$(cd "$output_dir" && pwd -P)"
image_name="local/ai-image-cropper-cli:latest"
cache_volume="ai-image-cropper-cache"
models_volume="ai-image-cropper-models"

if [[ "$input_abs" == "$output_abs" ]]; then
  echo "Output directory must be separate from the input directory to keep originals untouched." >&2
  exit 1
fi

method_args=(--method yolo)
for arg in "$@"; do
  if [[ "$arg" == "--method" || "$arg" == --method=* ]]; then
    method_args=()
    break
  fi
done

if ! docker image inspect "$image_name" >/dev/null 2>&1; then
  echo "Building Docker image: $image_name"
  docker build -f "$repo_root/Dockerfile.ai-image-cropper-cli" -t "$image_name" "$repo_root"
  echo
fi

tmp_list="$(mktemp)"
trap 'rm -f "$tmp_list"' EXIT

find "$input_abs" -maxdepth 1 -type f -iname '*.webp' -print0 | sort -z > "$tmp_list"

if [[ ! -s "$tmp_list" ]]; then
  echo "No .webp files found directly in: $input_abs" >&2
  exit 1
fi

total="$(tr -cd '\0' < "$tmp_list" | wc -c | tr -d ' ')"

echo "Input directory:  $input_abs"
echo "Output directory: $output_abs"
echo "Docker image:     $image_name"
echo "Cache volume:     $cache_volume"
echo "Models volume:    $models_volume"
echo "WebP files:       $total"
echo

processed=0
failed=0

while IFS= read -r -d '' img; do
  file_name="$(basename "$img")"
  stem="${file_name%.*}"
  input_path="/input/$file_name"
  output_path="/output/${stem}.webp"

  echo "Cropping: $file_name"

  if docker run --rm \
    --entrypoint bash \
    -v "$input_abs:/input:ro" \
    -v "$output_abs:/output" \
    -v "$cache_volume:/cache" \
    -v "$models_volume:/opt/ai-image-cropper-v2/backend/models" \
    "$image_name" \
    -lc 'uv run crop-cli "$@"' \
    _ "$input_path" "${method_args[@]}" "$@" --crop-output "$output_path"; then
    processed=$((processed + 1))
    echo "Created:  $output_abs/${stem}.webp"
  else
    failed=$((failed + 1))
    echo "Failed:   $file_name" >&2
  fi

  echo
done < "$tmp_list"

if [[ "$failed" -gt 0 ]]; then
  echo "Done with failures. Cropped $processed image(s); failed $failed." >&2
  exit 1
fi

echo "Done. Cropped $processed image(s)."
