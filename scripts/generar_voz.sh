#!/usr/bin/env bash
# Genera con ElevenLabs (voz Tornillo) un audio por cada frase de Lagun.
# Uso (en Ubuntu): bash /mnt/c/Users/eriel/Desktop/generar_voz.sh
set -uo pipefail
DIR=/mnt/c/Users/eriel/Desktop/voz
LIST="$DIR/frases.tsv"
[ -f "$LIST" ] || { echo "No encuentro $LIST"; exit 1; }

if [ -z "${ELEVEN_KEY:-}" ]; then read -rsp "Pega tu API key de ElevenLabs (no se verá): " ELEVEN_KEY; echo; fi
VOICE_ID="${VOICE_ID:-FJIJVGvTEAr0aX5Hnpxe}"   # Tornillo
MODEL="${MODEL:-eleven_multilingual_v2}"
# Ajustes de tu prueba (s50 = estabilidad 0.50, sim75 = similitud 0.75)
STAB="${STAB:-0.5}"; SIM="${SIM:-0.75}"

echo ">> Comprobando conexión con ElevenLabs…"
if ! curl -sS --max-time 15 -o /dev/null https://api.elevenlabs.io/v1/models; then
  echo "❌ Ubuntu no llega a internet (api.elevenlabs.io). Usa la versión de Windows: generar_voz.ps1"; exit 1; fi
ok=0; skip=0; fail=0; total=$(wc -l < "$LIST")
while IFS=$'\t' read -r key text; do
  [ -n "$key" ] || continue
  out="$DIR/$key.mp3"
  if [ -s "$out" ]; then skip=$((skip+1)); continue; fi
  body=$(python3 -c 'import json,sys; print(json.dumps({"text":sys.argv[1],"model_id":sys.argv[2],"voice_settings":{"stability":float(sys.argv[3]),"similarity_boost":float(sys.argv[4])}}))' "$text" "$MODEL" "$STAB" "$SIM")
  code=$(curl -sS --max-time 60 -o "$out.tmp" -w "%{http_code}" -X POST \
    "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID?output_format=mp3_44100_128" \
    -H "xi-api-key: $ELEVEN_KEY" -H "Content-Type: application/json" -d "$body")
  if [ "$code" = "200" ]; then mv "$out.tmp" "$out"; ok=$((ok+1)); echo "✅ [$((ok+skip))/$total] $text"
  else fail=$((fail+1)); echo "❌ ($code) $text"; [ -f "$out.tmp" ] && cat "$out.tmp"; echo; rm -f "$out.tmp"
       [ "$code" = "000" ] && { echo "Sin conexión con ElevenLabs. Usa generar_voz.ps1 en PowerShell."; exit 1; }
       [ "$code" = "401" ] && { echo "La API key no es válida."; exit 1; }
       [ "$code" = "404" ] && { echo "No encuentro esa voz: revisa el Voice ID."; exit 1; }
  fi
done < "$LIST"
echo
echo "Hecho: $ok nuevos, $skip ya existían, $fail fallos. Audios en el Escritorio, carpeta voz."
echo "Abre la app (Ctrl+F5) y en Configuración deja marcada «Voz grabada (Tornillo)»."
