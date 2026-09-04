#!/bin/bash
# Fills a RunPod network volume with the model files the Chroma picture worker
# needs. Run it ONCE inside a temporary RunPod pod that has the volume mounted
# at /workspace (any cheap pod works; it only downloads). About 15 GB.
#
#   bash download-models.sh
#
# Afterwards terminate the pod; the files stay on the volume. The serverless
# endpoint mounts the same volume at /runpod-volume and ComfyUI finds
# everything under /runpod-volume/models/...
set -e
ROOT="${1:-/workspace}"
mkdir -p "$ROOT/models/diffusion_models" "$ROOT/models/text_encoders" "$ROOT/models/vae" "$ROOT/models/loras"

get() { # url, destination
  if [ -s "$2" ]; then echo "already there: $2"; return; fi
  echo "downloading $(basename "$2") ..."
  wget -q --show-progress -c -O "$2.part" "$1" && mv "$2.part" "$2"
}

# Chroma1-HD, fp8 (9.2 GB): uncensored Flux-based model, repackaged by Comfy-Org for ComfyUI
get https://huggingface.co/Comfy-Org/Chroma1-HD_repackaged/resolve/main/split_files/diffusion_models/Chroma1-HD-fp8mixed.safetensors \
    "$ROOT/models/diffusion_models/Chroma1-HD-fp8mixed.safetensors"

# T5-XXL text encoder, fp8 scaled (5.2 GB): the only text encoder Chroma uses
get https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn_scaled.safetensors \
    "$ROOT/models/text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors"

# Flux VAE (335 MB)
get https://huggingface.co/lodestones/Chroma/resolve/main/ae.safetensors \
    "$ROOT/models/vae/ae.safetensors"

echo
echo "done. Files on the volume:"
du -h "$ROOT/models"/*/* 2>/dev/null
echo
echo "Optional: drop any Chroma/Flux LoRA (.safetensors) into $ROOT/models/loras/ and type its file name in the app."
