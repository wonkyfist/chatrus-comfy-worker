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

# Impact Pack + Subpack: the FaceDetailer pass (finds her face, repaints it sharp) and the YOLO face
# detector it uses. Turn it on in the bridge config: gpu.comfy.faceDetail = true.
RUN cd /comfyui/custom_nodes \
    && git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Pack.git \
    && git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git \
    && pip install --no-cache-dir ultralytics segment-anything piexif scikit-image opencv-python-headless \
    && (pip install --no-cache-dir -r ComfyUI-Impact-Pack/requirements.txt || true) \
    && (pip install --no-cache-dir -r ComfyUI-Impact-Subpack/requirements.txt || true) \
    && mkdir -p /comfyui/models/ultralytics/bbox \
    && wget -q -O /comfyui/models/ultralytics/bbox/face_yolov8m.pt \
       https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt

# EVA-CLIP for PuLID (downloaded once into the image's Hugging Face cache)
RUN python -c "from huggingface_hub import hf_hub_download; hf_hub_download('QuanSun/EVA-CLIP', 'EVA02_CLIP_L_336_psz14_s6B.pt')"

# Frame interpolation (RIFE): doubles a clip's frames so 16 fps Wan output plays at 32 fps.
# Turn it on in the bridge config: gpu.comfy.videoSmooth = true (the bridge falls back to 16 fps
# on a worker without it). The RIFE weights are baked in so a cold start never downloads them.
RUN cd /comfyui/custom_nodes \
    && git clone --depth 1 https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git \
    && (pip install --no-cache-dir -r ComfyUI-Frame-Interpolation/requirements-no-cupy.txt || true) \
    && mkdir -p ComfyUI-Frame-Interpolation/ckpts/rife \
    && (wget -q -O ComfyUI-Frame-Interpolation/ckpts/rife/rife47.pth \
       https://github.com/Fannovel16/ComfyUI-Frame-Interpolation/releases/download/models/rife47.pth \
       || wget -q -O ComfyUI-Frame-Interpolation/ckpts/rife/rife47.pth \
       https://huggingface.co/marduk191/rife/resolve/main/rife47.pth)

# ReActor: her face swapped onto every clip frame that shows a face, so Wan cannot drift her into
# someone else when she turns around. Turn it on in the bridge config: gpu.comfy.videoFaceSwap = true.
# The swap model and the GFPGAN restore weights are baked in.
RUN cd /comfyui/custom_nodes \
    && git clone --depth 1 https://github.com/Gourieff/ComfyUI-ReActor.git \
    && (pip install --no-cache-dir -r ComfyUI-ReActor/requirements.txt || true) \
    && mkdir -p /comfyui/models/insightface /comfyui/models/facerestore_models \
    && wget -q -O /comfyui/models/insightface/inswapper_128.onnx \
       https://huggingface.co/ezioruan/inswapper_128.onnx/resolve/main/inswapper_128.onnx \
    && wget -q -O /comfyui/models/facerestore_models/GFPGANv1.4.pth \
       https://github.com/TencentARC/GFPGAN/releases/download/v1.3.4/GFPGANv1.4.pth \
    && python -c "import insightface; from insightface.app import FaceAnalysis; FaceAnalysis(name='buffalo_l', root='/comfyui/models/insightface').prepare(ctx_id=-1)" || true

# ReActor ships a built-in content filter that silently DROPS every frame it flags and returns a black
# 512x512 frame when it flags them all: a 15-second clip came back as one frame. This worker only ever
# renders adult fiction for its owner, so the filter is switched off in this image.
RUN cd /comfyui/custom_nodes/ComfyUI-ReActor \
    && sed -i 's/if not sfw.nsfw_image(img_byte_arr, NSFWDET_MODEL_PATH):/if True:/' nodes.py \
    && grep -c "if True:" nodes.py
