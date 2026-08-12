$ErrorActionPreference = "Stop"

$serverDir = "C:\Users\AnnLee\Desktop\it_challenge-ai_model"
$python = Join-Path $serverDir ".venv311\Scripts\python.exe"
$logDir = "C:\Users\AnnLee\Desktop\foodaicamera\server_logs"
$outLog = Join-Path $logDir "fastapi.out.log"
$errLog = Join-Path $logDir "fastapi.err.log"

New-Item -ItemType Directory -Force -Path $logDir | Out-Null

# Some shells expose both PATH and Path, which makes Start-Process fail on Windows.
[Environment]::SetEnvironmentVariable("PATH", $null, "Process")

Start-Process `
	-FilePath $python `
	-ArgumentList "-m uvicorn ai_server:app --host 0.0.0.0 --port 8000" `
	-WorkingDirectory $serverDir `
	-RedirectStandardOutput $outLog `
	-RedirectStandardError $errLog `
	-WindowStyle Hidden
