# Instalador da CLI codisec (Windows, PowerShell nativo — sem WSL).
#
#   iwr https://labs.codisec.com.br/install.ps1 -useb | iex
#
# Baixa o binário de uma GitHub Release, confere o checksum SHA-256
# publicado junto (ver docs/SECURITY.md) antes de instalar, e adiciona
# ao PATH do usuário. Não precisa de administrador.

$ErrorActionPreference = "Stop"

$Repo = "codisec-io/codisec-labs"
$InstallDir = if ($env:CODISEC_INSTALL_DIR) { $env:CODISEC_INSTALL_DIR } else { Join-Path $env:USERPROFILE ".codisec\bin" }

# A CLI só publica windows/amd64 por enquanto (ver cli/.goreleaser.yml).
if ($env:PROCESSOR_ARCHITECTURE -ne "AMD64") {
    Write-Error "codisec CLI ainda não publica binário para Windows $($env:PROCESSOR_ARCHITECTURE) — só windows/amd64 por enquanto."
    exit 1
}

Write-Host "Consultando a última versão..."
try {
    $Release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
} catch {
    Write-Error "Não consegui consultar a API do GitHub: $_"
    exit 1
}
$Version = $Release.tag_name
if (-not $Version) {
    Write-Error "Não consegui determinar a versão mais recente. Veja https://github.com/$Repo/releases"
    exit 1
}
Write-Host "Última versão: $Version"

$Archive = "codisec_windows_amd64.zip"
$BaseUrl = "https://github.com/$Repo/releases/download/$Version"

$TmpDir = Join-Path $env:TEMP ("codisec-install-" + [System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $TmpDir | Out-Null

try {
    $ArchivePath = Join-Path $TmpDir $Archive
    $ChecksumsPath = Join-Path $TmpDir "checksums.txt"

    Write-Host "Baixando $Archive..."
    Invoke-WebRequest -Uri "$BaseUrl/$Archive" -OutFile $ArchivePath
    Invoke-WebRequest -Uri "$BaseUrl/checksums.txt" -OutFile $ChecksumsPath

    Write-Host "Conferindo checksum..."
    $ChecksumLine = Select-String -Path $ChecksumsPath -Pattern ([Regex]::Escape($Archive)) | Select-Object -First 1
    if (-not $ChecksumLine) {
        Write-Error "Checksum de $Archive não encontrado em checksums.txt — abortando, não é seguro instalar."
        exit 1
    }
    $Expected = ($ChecksumLine.Line -split '\s+')[0].ToLower()
    $Actual = (Get-FileHash -Path $ArchivePath -Algorithm SHA256).Hash.ToLower()
    if ($Expected -ne $Actual) {
        Write-Error "Checksum não bate (esperado $Expected, obtido $Actual) — abortando, não é seguro instalar."
        exit 1
    }
    Write-Host "Checksum ok."

    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Expand-Archive -Path $ArchivePath -DestinationPath $TmpDir -Force
    $BinarySource = Join-Path $TmpDir "codisec.exe"
    if (-not (Test-Path $BinarySource)) {
        Write-Error "O arquivo baixado não contém o binário codisec.exe esperado."
        exit 1
    }
    Copy-Item -Path $BinarySource -Destination (Join-Path $InstallDir "codisec.exe") -Force

    Write-Host "✓ codisec instalado em $InstallDir\codisec.exe"

    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $UserPath) { $UserPath = "" }
    if ($UserPath -notlike "*$InstallDir*") {
        $NewUserPath = if ($UserPath.Trim().Length -eq 0) { $InstallDir } else { "$UserPath;$InstallDir" }
        [Environment]::SetEnvironmentVariable("Path", $NewUserPath, "User")
        $env:Path = "$env:Path;$InstallDir"
        Write-Host "Adicionado $InstallDir ao PATH do usuário. Abra um novo terminal para ele valer em todo lugar."
    }

    Write-Host ""
    Write-Host "Pronto! Teste com: codisec lab list"
    Write-Host "Pre-requisito para rodar labs: Docker Desktop instalado e aberto (ele cuida do WSL2 por baixo — nao precisa configurar nada manualmente)."
} finally {
    Remove-Item -Path $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
