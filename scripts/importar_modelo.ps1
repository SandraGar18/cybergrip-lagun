# Importa un modelo .zip en SenseCraft (con SenseCraft abierta y el proyecto activo).
# Uso en PowerShell:  powershell -ExecutionPolicy Bypass -File "$HOME\Desktop\importar_modelo.ps1" azul
param([Parameter(Mandatory=$true)][string]$Color)

$zip = Join-Path $HOME "Desktop\modelo-$Color.zip"
if (-not (Test-Path $zip)) { Write-Host "No encuentro $zip" -ForegroundColor Red; exit 1 }

# 1) Comprobar que SenseCraft está abierta
curl.exe -sk --max-time 5 "https://127.0.0.1:18100/api/models" | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Host "SenseCraft no responde. Ábrela, espera a que cargue del todo y vuelve a ejecutar este script." -ForegroundColor Red
  exit 1
}

# 2) Importar
Write-Host "Importando $zip en SenseCraft (puede tardar un poco)..."
$url = "https://127.0.0.1:18100/api/models/import-file?name=modelo-$Color"
$resp = curl.exe -sSk --max-time 300 -X POST -H "Content-Type: application/zip" --data-binary "@$zip" $url
Write-Host $resp
if ($resp -match '"code":\s*200' -or $resp -match '"model_id"') {
  Write-Host ""
  Write-Host "OK: modelo-$Color importado. Aparece en SenseCraft > Models. En la app pulsa Recargar modelos." -ForegroundColor Green
} else {
  Write-Host ""
  Write-Host "No se ha importado. Manda una foto de este mensaje." -ForegroundColor Red
}
