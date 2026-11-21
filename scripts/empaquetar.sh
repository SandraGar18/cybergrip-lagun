#!/usr/bin/env bash
# Vuelve a empaquetar el último modelo entrenado de un color (sin volver a entrenar).
# Uso: bash /mnt/c/Users/eriel/Desktop/empaquetar.sh azul ["descripción de la tarea"]
# Para un entrenamiento concreto: DIR=~/entrenamientos/negro-1530 NOMBRE=negro-v1 bash .../empaquetar.sh negro
set -euo pipefail
COLOR="${1:?Falta el color, ej. azul}"
TASK="${2:-}"
NOMBRE="${NOMBRE:-$COLOR}"
OUT_DIR="${DIR:-$(ls -dt "$HOME"/entrenamientos/"$COLOR"-* 2>/dev/null | head -1)}"
echo ">> Empaquetando $OUT_DIR"
[ -n "$OUT_DIR" ] || { echo "No encuentro entrenamientos de $COLOR en ~/entrenamientos"; exit 1; }
CKPT="$OUT_DIR/checkpoints/last/pretrained_model"
[ -f "$CKPT/model.safetensors" ] || { echo "No hay modelo en $CKPT"; exit 1; }
STEPS=$(python3 -c "import json;print(json.load(open('$OUT_DIR/checkpoints/last/training_state/training_step.json'))['step'])" 2>/dev/null || echo 20000)
python3 - "$CKPT" "/mnt/c/Users/eriel/Desktop/modelo-$NOMBRE.zip" "$NOMBRE" "$STEPS" "$TASK" <<'PY'
import json, sys, zipfile, time
from pathlib import Path
ckpt, zip_path, color, steps, task = sys.argv[1:]
ckpt = Path(ckpt)
manifest = {
    "format": "sensecraft-model-archive", "format_version": 1,
    "checkpoint_path": "checkpoints/last/pretrained_model",
    "model_id": f"gpu_act_{color}_{int(time.time())}", "name": f"modelo-{color}",
    "policy": "act", "task_text": task or f"pick the {color} piece",
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
PY
echo "✅ Ahora: borra el modelo-$COLOR antiguo en SenseCraft (Models) e importa de nuevo con importar_modelo.ps1 $NOMBRE"
