#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# Hugging Face Token for authenticated downloads (read from environment)
export HF_TOKEN="${HF_TOKEN:-}"
export HF_HUB_ENABLE_HF_TRANSFER=1

# Warn if HF_TOKEN is not set
if [[ -z "$HF_TOKEN" ]]; then
    printf "⚠️  WARNING: HF_TOKEN is not set. Some downloads may fail.\n"
fi

APT_PACKAGES=("aria2")
PIP_PACKAGES=() # Add extra packages here if needed

NODES=(
    "https://github.com/Comfy-Org/ComfyUI-Manager"
    "https://github.com/Jasonzzt/ComfyUI-CacheDiT"
    "https://github.com/evanspearman/ComfyMath"
    "https://github.com/kijai/ComfyUI-KJNodes"
)

DIFFUSION_MODELS=("https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/diffusion_models/ltx-2.3-22b-distilled-1.1_transformer_only_fp8_scaled.safetensors")
VAE=(
    "https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/vae/LTX23_audio_vae_bf16.safetensors"
    "https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/vae/LTX23_video_vae_bf16.safetensors"
)
TEXT_ENCODERS=(
    "https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/text_encoders/ltx-2.3_text_projection_bf16.safetensors"
    "https://huggingface.co/DreamFast/gemma-3-12b-it-heretic-v2/resolve/main/comfyui/gemma-3-12b-it-heretic-v2_nvfp4.safetensors"
)
LTX_UPSCALER=("https://huggingface.co/Lightricks/LTX-2.3/resolve/main/ltx-2.3-spatial-upscaler-x2-1.1.safetensors")
WORKFLOW_FILES=("https://raw.githubusercontent.com/aster-king/Vast-AI-Comfy/main/ltx2.3.json")
WORKSPACE_SCRIPTS=(
    "https://raw.githubusercontent.com/aster-king/Vast-AI-Comfy/refs/heads/main/start.sh"
    "https://raw.githubusercontent.com/aster-king/Vast-AI-Comfy/refs/heads/main/ltx2.3.sh"
)

function provisioning_start() {
    provisioning_print_header
    mkdir -p "${WORKSPACE}"
    
    # STEP 1: Tools (Idempotent)
    if [[ ! -f "${WORKSPACE}/step1_download_tools_installed" ]]; then
        provisioning_install_download_tools
        touch "${WORKSPACE}/step1_download_tools_installed"
    fi
    
    # STEP 2: Scripts (Idempotent)
    provisioning_download_workspace_scripts

    # --- NEW ORDER: CORE UPDATE FIRST ---
    printf "%s\n" "--- 🔄 STEP 3: UPDATING COMFYUI CORE & DEPENDENCIES ---"
    cd "${COMFYUI_DIR}"
    git pull
    pip install --no-cache-dir -r requirements.txt
    
    # STEP 4: Custom Nodes (Now uses the updated core environment)
    printf "%s\n" "--- 🔧 STEP 4: CLONING/UPDATING CUSTOM NODES ---"
    provisioning_clone_nodes

    # STEP 5: Parallel Downloads & Node Requirements
    printf "%s\n" "--- 🚀 STEP 5: PARALLEL DOWNLOADS & NODE SETUP ---"
    
    # 5A: Node Setup & Launch
    (
        provisioning_install_node_requirements
        printf "%s\n" "--- 🚀 LAUNCHING COMFYUI ---"
        bash "${WORKSPACE}/start.sh"
    ) &
    LAUNCH_PID=$!
    
    # 5B: Model Downloads (Idempotent)
    provisioning_get_all_files &
    DOWNLOAD_PID=$!
    
    wait $DOWNLOAD_PID
    printf "%s\n" "--- ✅ DOWNLOADS COMPLETE ---"
    wait $LAUNCH_PID
}

function provisioning_install_download_tools() {
    sudo apt-get update && sudo apt-get install -y ${APT_PACKAGES[@]}
    pip install --no-cache-dir "huggingface_hub[hf_transfer]"
}

function provisioning_download_workspace_scripts() {
    for url in "${WORKSPACE_SCRIPTS[@]}"; do
        provisioning_download "${url}" "${WORKSPACE}"
    done
    chmod +x "${WORKSPACE}/start.sh" "${WORKSPACE}/ltx2.3.sh"
}

function provisioning_clone_nodes() {
    for repo in "${NODES[@]}"; do
        dir=$(basename "${repo}" .git)
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        if [[ -d $path ]]; then
            ( cd "$path" && git fetch origin && git pull --ff-only ) || printf "Warn: Update fail for %s\n" "${dir}"
        else
            git clone "${repo}" "${path}" --recursive
        fi
    done
}

function provisioning_install_node_requirements() {
    for repo in "${NODES[@]}"; do
        dir=$(basename "${repo}" .git)
        requirements="${COMFYUI_DIR}/custom_nodes/${dir}/requirements.txt"
        if [[ -e $requirements ]]; then
            pip install --no-cache-dir -r "${requirements}"
        fi
    done
    if [[ -n $PIP_PACKAGES ]]; then pip install --no-cache-dir ${PIP_PACKAGES[@]}; fi
}

function provisioning_get_all_files() {
    provisioning_get_files "${COMFYUI_DIR}/models/vae" "${VAE[@]}" &
    provisioning_get_files "${COMFYUI_DIR}/models/diffusion_models" "${DIFFUSION_MODELS[@]}" &
    provisioning_get_files "${COMFYUI_DIR}/models/text_encoders" "${TEXT_ENCODERS[@]}" &
    provisioning_get_files "${COMFYUI_DIR}/models/latent_upscale_models" "${LTX_UPSCALER[@]}" &
    provisioning_get_files "${COMFYUI_DIR}/user/default/workflows" "${WORKFLOW_FILES[@]}" &
    wait
}

function provisioning_get_files() {
    dir="$1"; shift; arr=("$@")
    mkdir -p "$dir"
    for url in "${arr[@]}"; do provisioning_download "${url}" "${dir}"; done
}

function provisioning_download() {
    local url="$1" dir="$2"
    local filename=$(basename "$url")
    local filepath="${dir}/${filename}"
    if [[ -f "$filepath" ]]; then return 0; fi
    
    if [[ "$url" == *"huggingface.co"* ]]; then
        local repo_id=$(echo "$url" | sed -E 's|https://huggingface.co/([^/]+/[^/]+)/resolve/.*|\1|')
        local file_path=$(echo "$url" | sed -E 's|https://huggingface.co/[^/]+/[^/]+/resolve/[^/]+/(.*)|\1|')
        huggingface-cli download "$repo_id" "$file_path" --local-dir "${dir}/.hf_temp" --local-dir-use-symlinks False 2>/dev/null
        find "${dir}/.hf_temp" -type f -name "$filename" -exec mv {} "${dir}/" \;
        rm -rf "${dir}/.hf_temp"
    else
        aria2c -x 16 -s 16 -k 1M -c --console-log-level=error -d "$dir" "$url"
    fi
}

function provisioning_print_header() {
    printf "\n--- PROVISIONING STARTING ---\n"
}

if [[ ! -f /.noprovisioning ]]; then provisioning_start; fi
