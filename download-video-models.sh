#!/bin/bash
# Adds Wan 2.2 image-to-video (14B, fp8) plus the 4-step Lightning LoRAs to the
# same network volume the Chroma worker uses. About 38 GB, so grow the volume
# to 80 GB first (Storage -> the volume -> edit size). Run it once inside a
# temporary pod with the volume mounted at /workspace:
#
#   bash download-video-models.sh
#
# No image rebuild is needed: every node the clip uses ships with ComfyUI.
set -e
ROOT="${1:-/workspace}"
mkdir -p "$ROOT/models/unet" "$ROOT/models/clip" "$ROOT/models/vae" "$ROOT/models/loras"

get() { # url, destination
  if [ -s "$2" ]; then echo "already there: $2"; return; fi
  echo "downloading $(basename "$2") ..."
  wget -q --show-progress -c -O "$2.part" "$1" && mv "$2.part" "$2"
}

R22=https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files
R21=https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files
LX=https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1

# the two 14B experts, fp8 (14.3 GB each)
get $R22/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors "$ROOT/models/unet/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors"
get $R22/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors  "$ROOT/models/unet/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors"
# text encoder (6.3 GB) and VAE (0.25 GB)
get $R21/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors "$ROOT/models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
get $R21/vae/wan_2.1_vae.safetensors "$ROOT/models/vae/wan_2.1_vae.safetensors"
# 4-step Lightning LoRAs (1.2 GB each): 5x faster clips, same names as the official ComfyUI template
get $LX/high_noise_model.safetensors "$ROOT/models/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors"
get $LX/low_noise_model.safetensors  "$ROOT/models/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors"

echo
echo "done. Files on the volume:"
du -h "$ROOT/models"/*/* 2>/dev/null
