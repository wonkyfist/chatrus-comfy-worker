# Chat R' Us picture worker: ComfyUI on RunPod serverless with Chroma1-HD
# (uncensored, Flux-based) and PuLID face lock so she is the same person in
# every picture. Big model files live on a network volume (see
# download-models.sh); the small face-lock pieces are baked in here so a cold
# start never waits on a download.
#
# Build happens on RunPod itself: Serverless -> New Endpoint -> GitHub ->
# point it at the repo holding this file. See README.md next to it.

FROM runpod/worker-comfyui:5.10.0-base

# insightface compiles a small extension at install time
RUN apt-get update && apt-get install -y --no-install-recommends build-essential unzip wget \
    && rm -rf /var/lib/apt/lists/*

# PuLID for Flux and Chroma: keeps her face across pictures from one reference portrait
RUN cd /comfyui/custom_nodes \
    && git clone --depth 1 https://github.com/PaoloC68/ComfyUI-PuLID-Flux-Chroma.git \
    && pip install --no-cache-dir -r ComfyUI-PuLID-Flux-Chroma/requirements.txt timm ftfy

# face-lock weights (1 GB) and the face detector (300 MB) ride inside the image
RUN mkdir -p /comfyui/models/pulid /comfyui/models/insightface/models/antelopev2 \
    && wget -q -O /comfyui/models/pulid/pulid_flux_v0.9.1.safetensors \
       https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.1.safetensors \
    && wget -q -O /tmp/antelopev2.zip https://github.com/deepinsight/insightface/releases/download/v0.7/antelopev2.zip \
    && unzip -q -o /tmp/antelopev2.zip -d /comfyui/models/insightface/models/ \
    && rm -f /tmp/antelopev2.zip \
    && ls /comfyui/models/insightface/models/antelopev2

# EVA-CLIP for PuLID (downloaded once into the image's Hugging Face cache)
RUN python -c "from huggingface_hub import hf_hub_download; hf_hub_download('QuanSun/EVA-CLIP', 'EVA02_CLIP_L_336_psz14_s6B.pt')"
