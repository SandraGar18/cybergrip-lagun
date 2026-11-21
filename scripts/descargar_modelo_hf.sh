#!/usr/bin/env bash
# Descarga un modelo entrenado en Hugging Face y lo empaqueta para importarlo en SenseCraft.
# Uso: bash /mnt/c/Users/eriel/Desktop/descargar_modelo_hf.sh leibar0304/act-rojo rojo 20000 ["descripción"]
set -euo pipefail
MODEL_REPO="${1:?Falta el repo del modelo, ej. leibar0304/act-rojo}"
COLOR="${2:?Falta el color}"
STEPS="${3:-20000}"
TASK="${4:-}"
source "$HOME/miniforge3/etc/profile.d/conda.sh"
conda activate lerobot06
DIR="$HOME/modelos-hf/$COLOR"
rm -rf "$DIR"; mkdir -p "$DIR"
hf download "$MODEL_REPO" --local-dir "$DIR"
python - "$DIR" "/mnt/c/Users/eriel/Desktop/modelo-$COLOR.zip" "$COLOR" "$MODEL_REPO" "$STEPS" "$TASK" <<'EOF'
import json, sys, zipfile, time
from pathlib import Path
src, zip_path, color, repo, steps, task = sys.argv[1:]
src = Path(src)
if not (src / "model.safetensors").is_file():
    sys.exit(f"ERROR: no hay model.safetensors en {src}")
manifest = {
    "format": "sensecraft-model-archive", "format_version": 1,
    "checkpoint_path": "checkpoints/last/pretrained_model",
    "model_id": f"hf_act_{color}_{int(time.time())}", "name": f"modelo-{color}",
    "policy": "act", "dataset_id": repo, "dataset_name": repo.split("/")[-1],
    "task_text": task or f"pick the {color} piece",
    "train_robot_type": "so_follower",
    "supported_robot_types": ["so_follower", "so100_follower", "so101_follower"],
    "train_steps": int(steps),
}
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("manifest.json", json.dumps(manifest, indent=2, ensure_ascii=False))
    for f in sorted(src.rglob("*")):
        if f.is_file() and ".cache" not in f.parts and f.name != ".gitattributes" and not f.name.endswith(".md"):
            z.write(f, "checkpoints/last/pretrained_model/" + f.relative_to(src).as_posix())
print(">> Listo:", zip_path)
EOF
echo "✅ Ahora impórtalo:  powershell -ExecutionPolicy Bypass -File \"\$HOME\\Desktop\\importar_modelo.ps1\" $COLOR"
