#!/usr/bin/env bash
# Lanza un entrenamiento ACT en la nube de Hugging Face (HF Jobs, GPU Nvidia L4, ~0,80 $/h)
# y sube el modelo a tu cuenta. Después usa descargar_modelo_hf.sh para traerlo y empaquetarlo.
#
# Uso (en Ubuntu/WSL, entorno lerobot06):
#   bash /mnt/c/Users/eriel/Desktop/entrenar_hf.sh <usuario/dataset> <color> [pasos]
# Ejemplo:
#   bash /mnt/c/Users/eriel/Desktop/entrenar_hf.sh leibar0304/database_rojo rojo 20000
set -euo pipefail
REPO_ID="${1:?Falta el dataset, ej. leibar0304/database_rojo}"
COLOR="${2:?Falta el color, ej. rojo}"
STEPS="${3:-20000}"
USER_HF="${REPO_ID%%/*}"
MODEL_REPO="$USER_HF/act-$COLOR"

source "$HOME/miniforge3/etc/profile.d/conda.sh"
conda activate lerobot06
hf auth whoami >/dev/null 2>&1 || hf auth login

echo ">> Lanzando entrenamiento en Hugging Face: $REPO_ID → $MODEL_REPO ($STEPS pasos, GPU L4)"
hf jobs run --detach --flavor l4x1 --timeout 3h --secrets HF_TOKEN \
  python:3.12 bash -c "
set -e
apt-get update -qq && apt-get install -y -qq ffmpeg >/dev/null
pip install -q torch==2.10.0 torchvision==0.25.0 --index-url https://download.pytorch.org/whl/cu128
pip install -q 'lerobot[training,feetech]==0.6.0'
python -c 'import torch; print(\"GPU:\", torch.cuda.get_device_name(0))'
lerobot-train \
  --dataset.repo_id=$REPO_ID \
  --dataset.video_backend=pyav \
  --policy.type=act \
  --policy.device=cuda \
  --policy.push_to_hub=false \
  --output_dir=/tmp/out \
  --job_name=act_$COLOR \
  --steps=$STEPS \
  --save_freq=$STEPS \
  --batch_size=8 \
  --num_workers=4 \
  --wandb.enable=false
hf upload $MODEL_REPO /tmp/out/checkpoints/last/pretrained_model . --private
echo MODELO_SUBIDO_OK
"
echo ""
echo "✅ Lanzado. Para ver cómo va:   hf jobs ps        y   hf jobs logs <ID>"
echo "   Cuando termine (sale MODELO_SUBIDO_OK en los logs):"
echo "   bash /mnt/c/Users/eriel/Desktop/descargar_modelo_hf.sh $MODEL_REPO $COLOR $STEPS"
