#!/bin/bash

# 1. VS CODE & SYSTEM PREP
# We install these first so VS Code can connect even while the rest of the script runs
echo "--- 🛠️ PREPPING FOR VS CODE REMOTE SSH ---"
apt-get update && apt-get install -y \
    tar curl procps git build-essential python3-dev wget aria2 screen \
    ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 libsndfile1

# 2. BLACKWELL OPTIMIZATION & PERSISTENCE
export TORCH_CUDA_ARCH_LIST="12.0"
# Write variables to /etc/environment so VS Code 'sees' them in its remote shell
echo "TORCH_CUDA_ARCH_LIST=12.0" >> /etc/environment
echo "COMFY_PATH=/workspace/ComfyUI" >> /etc/environment
env >> /etc/environment

echo "--- 🚀 STARTING SEQUENTIAL RTX 5090 SETUP ---"

COMFY_PATH="/workspace/ComfyUI"
mkdir -p "$COMFY_PATH"
cd "$COMFY_PATH"

# 3. BASE INSTALL
if [ ! -d ".git" ]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git .
fi

# 4. CUSTOM NODES
echo "Cloning Nodes..."
NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
)

for repo in "${NODES[@]}"; do
    dir_name=$(basename "$repo")
    if [ ! -d "custom_nodes/$dir_name" ]; then
        git clone "$repo" "custom_nodes/$dir_name"
    fi
done

# 5. SEQUENTIAL MODEL DOWNLOADS (-j 1)
cat <<EOF > download_list.txt
https://huggingface.co/TencentGameMate/chinese-wav2vec2-base/resolve/main/config.json
  dir=models/transformers/TencentGameMate/chinese-wav2vec2-base
  out=config.json
https://huggingface.co/TencentGameMate/chinese-wav2vec2-base/resolve/main/pytorch_model.bin
  dir=models/transformers/TencentGameMate/chinese-wav2vec2-base
  out=pytorch_model.bin
https://huggingface.co/TencentGameMate/chinese-wav2vec2-base/resolve/main/chinese-wav2vec2-base-fairseq-ckpt.pt
  dir=models/wav2vec2
  out=chinese-wav2vec2-base-fairseq-ckpt.pt
https://huggingface.co/TencentGameMate/chinese-wav2vec2-base/resolve/main/preprocessor_config.json
  dir=models/transformers/TencentGameMate/chinese-wav2vec2-base
  out=preprocessor_config.json
https://huggingface.co/TencentGameMate/chinese-wav2vec2-base/resolve/main/vocab.json
  dir=models/transformers/TencentGameMate/chinese-wav2vec2-base
  out=vocab.json
https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors
  dir=models/diffusion_models/infinite_talk
  out=Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors
https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/I2V/Wan2_1-I2V-14B-480p_fp8_e4m3fn_scaled_KJ.safetensors
  dir=models/diffusion_models/infinite_talk
  out=Wan2_1-I2V-14B-480p_fp8_e4m3fn_scaled_KJ.safetensors
https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-fp8_e4m3fn.safetensors
  dir=models/text_encoders/wan
  out=umt5-xxl-enc-fp8_e4m3fn.safetensors
https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors
  dir=models/clip_vision/wan
  out=clip_vision_h.safetensors
https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors
  dir=models/vae/wan
  out=Wan2_1_VAE_bf16.safetensors
https://huggingface.co/lightx2v/Wan2.1-I2V-14B-480P-StepDistill-CfgDistill-Lightx2v/resolve/main/loras/Wan21_I2V_14B_lightx2v_cfg_step_distill_lora_rank64.safetensors
  dir=models/loras/infinite_talk
  out=Wan21_I2V_14B_lightx2v_cfg_step_distill_lora_rank64.safetensors
https://huggingface.co/Kijai/LTXV2_comfy/resolve/main/VAE/LTX2_video_vae_bf16.safetensors
  dir=models/vae/ltx
  out=LTX2_video_vae_bf16.safetensors
https://huggingface.co/Kijai/LTXV2_comfy/resolve/main/VAE/LTX2_audio_vae_bf16.safetensors
  dir=models/vae/ltx
  out=LTX2_audio_vae_bf16.safetensors
https://huggingface.co/Kijai/LTXV2_comfy/resolve/main/diffusion_models/ltx-2-19b-dev_fp4_transformer_only.safetensors
  dir=models/diffusion_models/ltx
  out=ltx-2-19b-dev_fp4_transformer_only.safetensors
https://huggingface.co/Kijai/MelBandRoFormer_comfy/resolve/main/MelBandRoformer_fp16.safetensors
  dir=models/diffusion_models
  out=MelBandRoformer_fp16.safetensors
https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors
  dir=models/text_encoders/ltx
  out=gemma_3_12B_it_fp4_mixed.safetensors
https://huggingface.co/Kijai/LTXV2_comfy/resolve/main/text_encoders/ltx-2-19b-embeddings_connector_dev_bf16.safetensors
  dir=models/text_encoders/ltx
  out=ltx-2-19b-embeddings_connector_dev_bf16.safetensors
https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-spatial-upscaler-x2-1.0.safetensors
  dir=models/latent_upscale_models/ltx
  out=ltx-2-spatial-upscaler-x2-1.0.safetensors
https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-distilled-lora-384.safetensors
  dir=models/loras/ltx
  out=ltx-2-19b-distilled-lora-384.safetensors
https://huggingface.co/Lightricks/LTX-2-19b-IC-LoRA-Detailer/resolve/main/ltx-2-19b-ic-lora-detailer.safetensors
  dir=models/loras/ltx
  out=ltx-2-19b-ic-lora-detailer.safetensors
EOF

echo "Starting Sequential Download..."
aria2c -i download_list.txt -j 1 -x 16 -s 16 --console-log-level=error &
DOWNLOAD_PID=$!

# 6. SOFTWARE STACK
echo "Installing Python Stack..."
pip install --upgrade pip setuptools wheel
pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128
pip install cupy-cuda12x
pip install --upgrade sageattention --no-build-isolation

if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
fi

echo "Installing Node Dependencies..."
find custom_nodes -maxdepth 2 -name "requirements.txt" | while read req; do
    grep -vE '^(torch|torchvision|torchaudio)' "$req" > temp_reqs.txt
    pip install -r temp_reqs.txt
    rm temp_reqs.txt
done

pip install onnxruntime-gpu --extra-index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-12/pypi/simple/

# 7. FINALIZATION & BACKGROUND LAUNCH
echo "Waiting for downloads..."
wait $DOWNLOAD_PID

echo "--- ✅ SETUP COMPLETE. LAUNCHING COMFYUI IN BACKGROUND ---"

# Launch in a screen session called 'comfy'
# This allows the process to survive if you disconnect VS Code
screen -dmS comfy bash -c "python3 main.py --listen 0.0.0.0 --port 8188"

echo "Setup finished. You can now connect via VS Code Remote SSH."
echo "ComfyUI is running on port 8188 in a 'screen' session."
