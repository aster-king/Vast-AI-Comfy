#!/bin/bash
set -e

cd /workspace

wget -O /workspace/vastf.sh "https://raw.githubusercontent.com/aster-king/Vast-AI-Comfy/refs/heads/main/vastf.sh"
chmod +x /workspace/vastf.sh

echo "vastf.sh downloaded to /workspace and made executable."
