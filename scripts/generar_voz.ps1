param([string]$Key = $env:ELEVEN_KEY)
# Genera con ElevenLabs (voz Tornillo) un audio por cada frase de Lagun.
# Uso (PowerShell):  powershell -ExecutionPolicy Bypass -File "$HOME\Desktop\generar_voz.ps1"
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Dir   = Join-Path $HOME "Desktop\voz"
$List  = Join-Path $Dir "frases.tsv"
$Voice = "FJIJVGvTEAr0aX5Hnpxe"   # Tornillo
if (-not (Test-Path $List)) { Write-Host "No encuentro $List"; exit 1 }
if (-not $Key) { $Key = Read-Host "Pega tu API key de ElevenLabs (clic derecho para pegar) y pulsa Enter" }
$Key = "$Key".Trim()
if (-not $Key.StartsWith("sk_")) { Write-Host "La clave no se ha pegado bien (debe empezar por sk_). Vuelve a lanzar el script." -ForegroundColor Red; exit 1 }
$lines = Get-Content -Path $List -Encoding UTF8 | Where-Object { $_ -match "`t" }
$ok = 0; $skip = 0; $fail = 0; $i = 0
foreach ($line in $lines) {
  $i++
  $parts = $line -split "`t", 2
  $out = Join-Path $Dir ($parts[0] + ".mp3"); $text = $parts[1]
  if ((Test-Path $out) -and (Get-Item $out).Length -gt 0) { $skip++; continue }
  $body = @{ text = $text; model_id = "eleven_multilingual_v2"; voice_settings = @{ stability = 0.5; similarity_boost = 0.75 } } | ConvertTo-Json -Compress
  $bytes = [Text.Encoding]::UTF8.GetBytes($body)
  try {
    Invoke-WebRequest -UseBasicParsing -Method Post -TimeoutSec 60 `
      -Uri "https://api.elevenlabs.io/v1/text-to-speech/$Voice`?output_format=mp3_44100_128" `
      -Headers @{ "xi-api-key" = $Key } -ContentType "application/json; charset=utf-8" -Body $bytes -OutFile $out
    $ok++; Write-Host "OK [$i/$($lines.Count)] $text"
  } catch {
    $fail++; Write-Host "ERROR [$i] $text" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if (Test-Path $out) { Remove-Item $out }
    if ($_.Exception.Message -match "401|404") { Write-Host "Revisa la API key (401) o el Voice ID (404)."; break }
    if ($fail -ge 3 -and $ok -eq 0) { Write-Host "Fallan todas: paro aqui. Mandame el mensaje de error en rojo."; break }
  }
}
Write-Host ""
Write-Host "Hecho: $ok nuevos, $skip ya existian, $fail fallos. Audios en Escritorio\voz."
Write-Host "Abre la app (Ctrl+F5) y en Configuracion deja marcada 'Voz grabada (Tornillo)'."
