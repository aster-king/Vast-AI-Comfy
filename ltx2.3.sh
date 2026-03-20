#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# Hugging Face Token for authenticated downloads (read from environment)
# Set HF_TOKEN in your Vast.ai template or on-start script
export HF_TOKEN="${HF_TOKEN:-}"
export HF_HUB_ENABLE_HF_TRANSFER=1

# Warn if HF_TOKEN is not set
if [[ -z "$HF_TOKEN" ]]; then
    printf "⚠️  WARNING: HF_TOKEN is not set. Some downloads may fail.\n"
    printf "   Set it in your Vast.ai template or run: export HF_TOKEN='your_token_here'\n"
fi

# Packages are installed after nodes so we can fix them...

APT_PACKAGES=(
    "aria2"
)

PIP_PACKAGES=(
    #"package-1"
    #"package-2"
)

NODES=(
    "https://github.com/Comfy-Org/ComfyUI-Manager"
    "https://github.com/Jasonzzt/ComfyUI-CacheDiT"
    "https://github.com/kijai/ComfyUI-KJNodes"
)

DIFFUSION_MODELS=(
    "https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/diffusion_models/ltx-2.3-22b-distilled_transformer_only_fp8_input_scaled_v3.safetensors"
)

VAE=(
    "https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/vae/LTX23_audio_vae_bf16.safetensors"
    "https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/vae/LTX23_video_vae_bf16.safetensors"
)

TEXT_ENCODERS=(
    "https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/text_encoders/ltx-2.3_text_projection_bf16.safetensors"
    "https://huggingface.co/DreamFast/gemma-3-12b-it-heretic-v2/resolve/main/comfyui/gemma-3-12b-it-heretic-v2_nvfp4.safetensors"
)

LTX_UPSCALER=(
    "https://huggingface.co/Lightricks/LTX-2.3/resolve/main/ltx-2.3-spatial-upscaler-x2-1.1.safetensors"
)

WORKFLOW_FILES=(
    "https://raw.githubusercontent.com/aster-king/Vast-AI-Comfy/main/ltx2.3.json"
)

# Scripts to download to WORKSPACE directory
WORKSPACE_SCRIPTS=(
    "https://raw.githubusercontent.com/aster-king/Vast-AI-Comfy/refs/heads/main/start.sh"
    "https://raw.githubusercontent.com/aster-king/Vast-AI-Comfy/refs/heads/main/ltx2.3.sh"
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    provisioning_print_header
    
    # STEP 1: Install download tools (aria2 + hf_transfer)
    printf "--- 📦 STEP 1: INSTALLING DOWNLOAD TOOLS ---\n"
    provisioning_install_download_tools
    touch "${WORKSPACE}/step1_download_tools_installed"
    printf "--- ✅ STEP 1 COMPLETE ---\n"
    
    # STEP 2: Download start.sh & ltx2.3.sh (files serve as their own markers)
    printf "--- 📜 STEP 2: DOWNLOADING WORKSPACE SCRIPTS ---\n"
    provisioning_download_workspace_scripts
    printf "--- ✅ STEP 2 COMPLETE ---\n"
    
    # STEP 3: Clone/Update custom nodes
    printf "--- 🔧 STEP 3: CLONING/UPDATING CUSTOM NODES ---\n"
    provisioning_clone_nodes
    touch "${WORKSPACE}/step3_repo_downloaded"
    printf "--- ✅ STEP 3 COMPLETE ---\n"
    
    # STEP 4: Run model downloads + pip installs in parallel
    printf "--- 🚀 STEP 4: STARTING PARALLEL DOWNLOADS & PIP INSTALLS ---\n"
    
    # 4A: Pip installs (background, then launch ComfyUI when done)
    (
        provisioning_install_node_requirements
        touch "${WORKSPACE}/step4a1_requirements_installed"
        printf "--- ✅ STEP 4A1 COMPLETE (Requirements installed) ---\n"
        
        # STEP 4A2: Launch ComfyUI as soon as pip is done (don't wait for downloads)
        printf "--- 🚀 STEP 4A2: LAUNCHING COMFYUI ---\n"
        touch "${WORKSPACE}/step4a2_comfyui_launching"
        bash "${WORKSPACE}/start.sh"
    ) &
    PIP_AND_LAUNCH_PID=$!
    
    # 4B: Model downloads (background)
    provisioning_get_all_files &
    DOWNLOAD_PID=$!
    
    # Wait for downloads to complete (pip/launch runs independently)
    wait $DOWNLOAD_PID
    touch "${WORKSPACE}/step4b_models_downloaded"
    printf "--- ✅ STEP 4B COMPLETE (Models downloaded) ---\n"
    
    # Wait for pip install and ComfyUI launch (this will hang because server runs)
    wait $PIP_AND_LAUNCH_PID
}

# STEP 1: Install aria2 and hf_transfer
function provisioning_install_download_tools() {
    printf "Installing aria2...\n"
    if [[ -n $APT_PACKAGES ]]; then
        sudo apt-get install -y ${APT_PACKAGES[@]}
    fi
    
    printf "Installing huggingface_hub with hf_transfer...\n"
    pip install --no-cache-dir "huggingface_hub[hf_transfer]"
    
    printf "Download tools installed: aria2c + hf_transfer\n"
}

# STEP 2: Download scripts to WORKSPACE and make them executable
function provisioning_download_workspace_scripts() {
    mkdir -p "${WORKSPACE}"
    for url in "${WORKSPACE_SCRIPTS[@]}"; do
        printf "Downloading script: %s\n" "${url}"
        provisioning_download "${url}" "${WORKSPACE}"
    done
    chmod +x "${WORKSPACE}/start.sh"
    chmod +x "${WORKSPACE}/ltx2.3.sh"
    printf "Scripts made executable: start.sh, ltx2.3.sh\n"
}

# STEP 3: Clone nodes if new, or pull updates if they exist
function provisioning_clone_nodes() {
    for repo in "${NODES[@]}"; do
        dir=$(basename "${repo}" .git)
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        if [[ -d $path ]]; then
            printf "Checking for updates: %s...\n" "${dir}"
            ( cd "$path" && git fetch origin && git pull --ff-only ) || \
                printf "Warning: Could not update %s, skipping...\n" "${dir}"
        else
            printf "Cloning node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
        fi
    done
}

function provisioning_install_node_requirements() {
    printf "--- 📥 INSTALLING NODE REQUIREMENTS & PIP PACKAGES ---\n"
    
    for repo in "${NODES[@]}"; do
        dir=$(basename "${repo}" .git)
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -e $requirements ]]; then
            printf "Installing requirements for: %s\n" "${dir}"
            pip install --no-cache-dir -r "${requirements}"
        fi
    done
    provisioning_get_pip_packages
    printf "--- ✅ PIP INSTALLATIONS COMPLETE ---\n"
}

function provisioning_get_all_files() {
    printf "--- 🚀 STARTING MODEL DOWNLOADS ---\n"
    provisioning_get_files "${COMFYUI_DIR}/models/vae" "${VAE[@]}" &
    provisioning_get_files "${COMFYUI_DIR}/models/diffusion_models" "${DIFFUSION_MODELS[@]}" &
    provisioning_get_files "${COMFYUI_DIR}/models/text_encoders" "${TEXT_ENCODERS[@]}" &
    provisioning_get_files "${COMFYUI_DIR}/models/latent_upscale_models" "${LTX_UPSCALER[@]}" &
    provisioning_get_files "${COMFYUI_DIR}/user/default/workflows" "${WORKFLOW_FILES[@]}" &
    
    wait
    printf "--- ✅ DOWNLOADS COMPLETE ---\n"
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
        pip install --no-cache-dir ${PIP_PACKAGES[@]}
    fi
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

function provisioning_download() {
    local url="$1"
    local dir="$2"
    local filename=$(basename "$url")
    local filepath="${dir}/${filename}"
    
    if [[ "$url" != *"huggingface.co"* ]] && [[ -f "$filepath" ]]; then
        printf "⏭️  SKIPPED (already exists): %s\n" "$filename"
        return 0
    fi
    
    if [[ "$url" == *"huggingface.co"* ]]; then
        local repo_id=$(echo "$url" | sed -E 's|https://huggingface.co/([^/]+/[^/]+)/resolve/.*|\1|')
        local file_path=$(echo "$url" | sed -E 's|https://huggingface.co/[^/]+/[^/]+/resolve/[^/]+/(.*)|\1|')
        
        printf "🚀 Trying hf_transfer for: %s (repo: %s)\n" "$filename" "$repo_id"
        
        if huggingface-cli download "$repo_id" "$file_path" --local-dir "${dir}/.hf_temp" --local-dir-use-symlinks False 2>/dev/null; then
            find "${dir}/.hf_temp" -type f -name "$filename" -exec mv {} "${dir}/" \;
            rm -rf "${dir}/.hf_temp"
            printf "✅ Downloaded via hf_transfer: %s\n" "$filename"
        else
            printf "⚠️  hf_transfer failed, falling back to aria2c...\n"
            aria2c -x 16 -s 16 -k 1M -c --console-log-level=error --summary-interval=5 \
                --header="Authorization: Bearer ${HF_TOKEN}" \
                -d "$dir" "$url" && \
                printf "✅ Downloaded via aria2c (fallback): %s\n" "$filename"
        fi
    else
        aria2c -x 16 -s 16 -k 1M -c --console-log-level=error --summary-interval=5 -d "$dir" "$url" && \
            printf "✅ Downloaded via aria2c: %s\n" "$filename"
    fi
}

if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi
