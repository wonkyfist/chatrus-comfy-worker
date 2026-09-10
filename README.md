# Chroma picture worker (RunPod)

Better pictures of people than the stock SDXL worker: Chroma1-HD (uncensored,
Flux-based) plus PuLID face lock, so she is the same person in every picture.
The bridge talks to it in "ComfyUI worker" mode (Settings → The crew → GPU
engine → Picture worker).

Three parts: a network volume with the big model files, a Docker image RunPod
builds from this folder, and one serverless endpoint that uses both.

## 1. Network volume (once, about 15 GB)

1. RunPod console → **Storage** → **New Network Volume**. Size **30 GB**. Pick a
   datacenter that has 24 GB and 48 GB GPUs available; the endpoint must live
   in the same one.
2. **Pods** → **Deploy** any cheap pod (a CPU pod is fine) and attach that
   volume at `/workspace` (Advanced → Network volume).
3. Open the pod's web terminal and run:

```bash
wget -qO- https://raw.githubusercontent.com/YOUR_GITHUB_USER/chatrus-comfy-worker/main/download-models.sh | bash
```

   (or paste the contents of `download-models.sh` into the terminal). Wait for
   "done", then **terminate the pod**. The files stay on the volume.

## 2. The worker image (once)

RunPod builds Docker images straight from GitHub, so no Docker is needed on
your Mac.

1. On GitHub create a new **public** repository, e.g. `chatrus-comfy-worker`.
2. Upload the two files from this folder: `Dockerfile` and
   `download-models.sh` (web UI → Add file → Upload files).
3. RunPod → **Serverless** → **New Endpoint** → **GitHub** (connect your
   GitHub account the first time) → pick the repo, branch `main`, Dockerfile
   path `Dockerfile`.
4. Endpoint settings: GPU **48 GB** if you want headroom (Chroma + T5 + face
   lock is about 20 GB; a 24 GB card works but is tight), container disk
   **30 GB**, Active workers 0, Max workers 1, Idle timeout **120** s,
   FlashBoot on. Under **Advanced** attach the network volume from step 1.
5. Create. The first build takes 10–20 minutes (it downloads the face-lock
   weights into the image). Watch **Builds** until it says ready, then wait for
   one worker to reach Idle.
6. Copy the **Endpoint ID**.

## 3. The app

Settings → The crew → GPU engine:

- **Picture worker** → **Chroma + face lock**.
- Image endpoint ID → the new endpoint's ID (keep the SDXL one around if you
  like; switching back is one tap).
- Save, then **Test the engine**. The first picture is slow (cold start plus
  model load, 2–4 minutes); after that about 20–30 s per picture on a 24 GB
  card, faster on 48 GB.
- On her page tap **Make her portrait** again. That portrait is the face
  reference PuLID locks onto from then on.

Face lock strength lives in the same settings section (default 0.85: strong
likeness without distorting proportions). A LoRA is optional: drop the
`.safetensors` into `models/loras/` on the volume and type its file name in
the app.

## Video clips (optional, same worker)

Five-second clips animated from her latest picture with Wan 2.2, so face,
body and outfit carry over. No image rebuild: the nodes ship with ComfyUI.

1. Storage → the volume → grow it to **80 GB** (the video files are ~38 GB).
2. Start a temporary pod with the volume at `/workspace` and run
   `download-video-models.sh` (paste its contents into the web terminal).
   Terminate the pod when it says done.
3. In the app, GPU engine → **video endpoint ID** → paste the same endpoint ID
   as the image endpoint. Save.
4. Ask her for a clip in your private thread. The first one loads ~30 GB of
   model on the card (a few minutes); after that a clip takes roughly a minute
   on an 80 GB class card with the fast 4-step LoRAs.

Cost: a clip is about one to three minutes of GPU time, so roughly $0.10 to
$0.30 on big cards, plus the cold start. She animates the last picture she sent
in the thread; if there is none yet, she takes a picture first, then the clip.

## If pictures fail

"Test the engine" shows the worker's real error text. The usual ones:

- *a model file is missing on the picture worker*: a file didn't land on the
  volume, or the volume isn't attached to the endpoint (Advanced → Network
  volume). The worker only scans the classic folder names on the volume:
  `models/unet`, `models/clip`, `models/vae`, `models/loras`. Files placed under
  `diffusion_models` or `text_encoders` are invisible to it.
- *the picture worker is missing a node pack*: the image was built without the
  PuLID nodes; rebuild from this Dockerfile.
- *No faces detected*: the portrait didn't contain a clear face; redo the
  portrait.
