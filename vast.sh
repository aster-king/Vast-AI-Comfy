#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# Packages are installed after nodes so we can fix them...

APT_PACKAGES=(
    "aria2"
)

PIP_PACKAGES=(
    #"package-1"
    #"package-2"
)

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/city96/ComfyUI-GGUF"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/yolain/ComfyUI-Easy-Use"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
    "https://github.com/cubiq/ComfyUI_essentials"
    "https://github.com/wallish77/wlsh_nodes"
    "https://github.com/vrgamegirl19/comfyui-vrgamedevgirl"
    "https://github.com/ClownsharkBatwing/RES4LYF"
    "https://github.com/theUpsider/ComfyUI-Logic"
    "https://github.com/Fannovel16/comfyui_controlnet_aux"
    "https://github.com/Lightricks/ComfyUI-LTXVideo"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
    "https://github.com/crystian/ComfyUI-Crystools"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/Derfuu/Derfuu_ComfyUI_ModdedNodes"
    "https://github.com/kijai/ComfyUI-MelBandRoFormer"
    "https://github.com/M1kep/ComfyLiterals"
    "https://github.com/YaserJaradeh/comfyui-yaser-nodes"
    "https://github.com/olduvai-jp/ComfyUI-S3-IO"
)

LORA_MODELS=(
    "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-distilled-lora-384.safetensors"
    "https://huggingface.co/Lightricks/LTX-2-19b-IC-LoRA-Detailer/resolve/main/ltx-2-19b-ic-lora-detailer.safetensors"
)

VAE_MODELS=(
    "https://huggingface.co/Kijai/LTXV2_comfy/resolve/main/VAE/LTX2_video_vae_bf16.safetensors"
    "https://huggingface.co/Kijai/LTXV2_comfy/resolve/main/VAE/LTX2_audio_vae_bf16.safetensors"
)

WAV2VEC2_MODELS=(
    "https://huggingface.co/TencentGameMate/chinese-wav2vec2-base/resolve/main/chinese-wav2vec2-base-fairseq-ckpt.pt"
)

TRANSFORMERS_CHINESE_WAV2VEC2=(
    "https://huggingface.co/TencentGameMate/chinese-wav2vec2-base/resolve/main/config.json"
    "https://huggingface.co/TencentGameMate/chinese-wav2vec2-base/resolve/main/pytorch_model.bin"
    "https://huggingface.co/TencentGameMate/chinese-wav2vec2-base/resolve/main/preprocessor_config.json"
    "https://huggingface.co/TencentGameMate/chinese-wav2vec2-base/resolve/main/vocab.json"
)

LTX_TEXT_ENCODERS=(
    "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors"
    "https://huggingface.co/Kijai/LTXV2_comfy/resolve/main/text_encoders/ltx-2-19b-embeddings_connector_dev_bf16.safetensors"
)

LTX_DIFFUSION=(
    "https://huggingface.co/Kijai/LTXV2_comfy/resolve/main/diffusion_models/ltx-2-19b-dev_fp4_transformer_only.safetensors"
)

LTX_DIFFUSION_GGUF=(
    "https://huggingface.co/Kijai/LTXV2_comfy/resolve/main/diffusion_models/ltx-2-19b-dev_Q8_0.gguf"
)

LTX_UPSCALER=(
    "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-spatial-upscaler-x2-1.0.safetensors"
)

MISC_DIFFUSION=(
    "https://huggingface.co/Kijai/MelBandRoFormer_comfy/resolve/main/MelBandRoformer_fp16.safetensors"
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    provisioning_print_header
    
    # 1. Install APT packages first (synchronously) because model downloads depend on aria2c
    provisioning_get_apt_packages
    
    # 2. Run remaining setup (Nodes, Pip) and Downloads in parallel
    provisioning_get_remaining_requirements &
    SETUP_PID=$!
    
    provisioning_get_all_files &
    DOWNLOAD_PID=$!
    
    # Wait for both to complete
    wait $SETUP_PID
    wait $DOWNLOAD_PID
    
    provisioning_print_end
}

function provisioning_get_remaining_requirements() {
    printf "--- 🛠️ STARTING REMAINING SETUP (NODES, PIP) ---\n"
    provisioning_get_nodes
    provisioning_get_pip_packages
    printf "--- ✅ SETUP COMPLETE ---\n"
}

function provisioning_get_all_files() {
    printf "--- 🚀 STARTING MODEL DOWNLOADS ---\n"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/checkpoints" \
        "${CHECKPOINT_MODELS[@]}" &
    provisioning_get_files \
        "${COMFYUI_DIR}/models/unet" \
        "${UNET_MODELS[@]}" &
    provisioning_get_files \
        "${COMFYUI_DIR}/models/loras" \
        "${LORA_MODELS[@]}" &
    provisioning_get_files \
        "${COMFYUI_DIR}/models/controlnet" \
        "${CONTROLNET_MODELS[@]}" &
    provisioning_get_files \
        "${COMFYUI_DIR}/models/vae" \
        "${VAE_MODELS[@]}" &
    provisioning_get_files \
        "${COMFYUI_DIR}/models/esrgan" \
        "${ESRGAN_MODELS[@]}" &
    provisioning_get_files \
        "${COMFYUI_DIR}/models/wav2vec2" \
        "${WAV2VEC2_MODELS[@]}" &
    provisioning_get_files \
        "${COMFYUI_DIR}/models/transformers/TencentGameMate/chinese-wav2vec2-base" \
        "${TRANSFORMERS_CHINESE_WAV2VEC2[@]}" &
    provisioning_get_files \
        "${COMFYUI_DIR}/models/unet" \
        "${LTX_DIFFUSION_GGUF[@]}" &
    provisioning_get_files \
        "${COMFYUI_DIR}/models/diffusion_models" \
        "${LTX_DIFFUSION[@]}" &
    provisioning_get_files \
        "${COMFYUI_DIR}/models/diffusion_models" \
        "${MISC_DIFFUSION[@]}" &
    provisioning_get_files \
        "${COMFYUI_DIR}/models/text_encoders" \
        "${LTX_TEXT_ENCODERS[@]}" &
    provisioning_get_files \
        "${COMFYUI_DIR}/models/latent_upscale_models" \
        "${LTX_UPSCALER[@]}" &
    
    wait
    printf "--- ✅ DOWNLOADS COMPLETE ---\n"
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
            sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
            pip install --no-cache-dir ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir=$(basename "${repo}" .git)
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                   pip install --no-cache-dir -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip install --no-cache-dir -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_files() {
    if [[ -z $2 ]]; then return 1; fi
    
    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Application will start now\n\n"
}

# Optimized for 1Gbps+ using aria2c
function provisioning_download() {
    # -x 16: Use 16 connections per server
    # -s 16: Use 16 threads
    # -k 1M: 1MB block size
    aria2c -x 16 -s 16 -k 1M --console-log-level=error --summary-interval=5 -d "$2" "$1"
}

# Allow user to disable provisioning if they started with a script they didn't want
if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi
