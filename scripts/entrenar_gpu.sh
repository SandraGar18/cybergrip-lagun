#!/usr/bin/env bash
# Entrena un modelo ACT con la GPU (WSL + LeRobot 0.6.0, la misma versión que SenseCraft)
# y lo empaqueta en un .zip que SenseCraft puede importar.
#
# Uso (en la terminal de Ubuntu/WSL):
#   bash /mnt/c/Users/eriel/Desktop/entrenar_gpu.sh <usuario_hf/dataset> <color> [pasos] ["descripción de la tarea"]
# Ejemplo:
#   bash /mnt/c/Users/eriel/Desktop/entrenar_gpu.sh leibar0304/database_1-azul azul 20000 "Pick the blue piece and place it in the tray"
set -euo pipefail

REPO_ID="${1:?Falta el dataset de Hugging Face, ej. leibar0304/database_1-azul}"
COLOR="${2:?Falta el color, ej. azul}"
STEPS="${3:-20000}"
TASK="${4:-}"
BATCH="${BATCH:-4}"
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
ENV_NAME=lerobot06
OUT_DIR="$HOME/entrenamientos/$COLOR-$(date +%H%M)"
DESKTOP="/mnt/c/Users/eriel/Desktop"

source "$HOME/miniforge3/etc/profile.d/conda.sh"

# 1) Entorno con LeRobot 0.6.0 (solo la primera vez, ~10 min)
if ! conda env list | grep -q "^$ENV_NAME "; then
  echo ">> Creando entorno $ENV_NAME (solo la primera vez)..."
  conda create -y -n "$ENV_NAME" python=3.12
fi
conda activate "$ENV_NAME"
if ! python -c "import lerobot, torch" >/dev/null 2>&1 || ! command -v lerobot-train >/dev/null; then
  echo ">> Instalando LeRobot 0.6.0 con soporte de GPU (~10 min, no cierres la terminal)..."
  conda install -y ffmpeg -c conda-forge
  pip install 'lerobot[training,feetech]==0.6.0'
fi

python - <<'EOF'
import torch, sys
if not torch.cuda.is_available():
    sys.exit("ERROR: PyTorch no ve la GPU. Ejecuta nvidia-smi para comprobarlo.")
print(">> GPU:", torch.cuda.get_device_name(0))
EOF

# 2) Comprobar sesión de Hugging Face (los datasets son privados)
if ! hf auth whoami >/dev/null 2>&1; then
  echo ">> Inicia sesión en Hugging Face (pega tu token):"
  hf auth login
fi

# 3) Entrenar (los mismos ajustes que usa SenseCraft, pero en la GPU)
echo ">> Entrenando $REPO_ID → $OUT_DIR ($STEPS pasos)"
lerobot-train \
  --dataset.repo_id="$REPO_ID" \
  --policy.type=act \
  --policy.device=cuda \
  --policy.push_to_hub=false \
  --output_dir="$OUT_DIR" \
  --job_name="act_$COLOR" \
  --steps="$STEPS" \
  --save_freq="$STEPS" \
  --batch_size="$BATCH" \
  --wandb.enable=false

# 4) Empaquetar en el formato de importación de SenseCraft
ZIP="$DESKTOP/modelo-$COLOR.zip"
python - "$OUT_DIR" "$ZIP" "$COLOR" "$REPO_ID" "$STEPS" "$TASK" <<'EOF'
import json, sys, zipfile, time
from pathlib import Path
out_dir, zip_path, color, repo_id, steps, task = sys.argv[1:]
ckpt = Path(out_dir) / "checkpoints" / "last" / "pretrained_model"
if not (ckpt / "model.safetensors").is_file():
    sys.exit(f"ERROR: no encuentro el modelo en {ckpt}")
manifest = {
    "format": "sensecraft-model-archive",
    "format_version": 1,
    "checkpoint_path": "checkpoints/last/pretrained_model",
    "model_id": f"gpu_act_{color}_{int(time.time())}",
    "name": f"modelo-{color}",
    "policy": "act",
    "dataset_id": repo_id,
    "dataset_name": repo_id.split("/")[-1],
    "task_text": task or f"pick the {color} piece",
    "train_robot_type": "so_follower",
    "supported_robot_types": ["so_follower", "so100_follower", "so101_follower"],
    "train_steps": int(steps),
}
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("manifest.json", json.dumps(manifest, indent=2, ensure_ascii=False))
    for f in sorted(ckpt.rglob("*")):
        if f.is_file():
            z.write(f, "checkpoints/last/pretrained_model/" + f.relative_to(ckpt).as_posix())
print(">> Listo:", zip_path)
EOF

echo ""
echo "✅ Modelo guardado en el Escritorio como modelo-$COLOR.zip"
echo "   Impórtalo en SenseCraft (Models → Import) o con importar_modelo.ps1"
