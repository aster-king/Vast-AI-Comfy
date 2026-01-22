#!/bin/bash
set -e

cd ComfyUI
source /venv/main/bin/activate
python main.py --port 8188 --listen --fast fp16_accumulation --use-pytorch-cross-attention
