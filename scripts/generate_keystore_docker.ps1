param(
    [string]$KeystorePath = "keystore/engenho-digital-upload.jks",
    [string]$Alias = "engenho_digital_upload",
    [Parameter(Mandatory = $true)]
    [string]$KeystorePassword,
    [string]$KeyPassword = "",
    [string]$Dname = "CN=Engenho Digital,O=Engenho Digital,C=BR",
    [int]$ValidityDays = 10000
)

$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name, [string]$Message)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Error $Message
        exit 1
    }
}

Require-Command "docker" "Docker not found. Install Docker Desktop and try again."

if (-not $KeyPassword) {
    $KeyPassword = $KeystorePassword
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")

$keystoreFullPath = Join-Path $repoRoot $KeystorePath
$keystoreDir = Split-Path -Parent $keystoreFullPath
$keystoreFileName = Split-Path -Leaf $keystoreFullPath

New-Item -ItemType Directory -Force -Path $keystoreDir | Out-Null

$certFileName = ([System.IO.Path]::GetFileNameWithoutExtension($keystoreFileName)) + "-cert.pem"

# Use a JDK container so no local Java install is required.
$image = "eclipse-temurin:17-jdk"

Write-Host "Pulling image (if needed): $image"
docker pull $image | Out-Null

$containerKeystorePath = "/out/$keystoreFileName"
$containerCertPath = "/out/$certFileName"

Write-Host "Generating keystore: $keystoreFullPath"
docker run --rm `
  -v "${keystoreDir}:/out" `
  $image `
  keytool -genkeypair `
    -storetype JKS `
    -keystore "$containerKeystorePath" `
    -storepass "$KeystorePassword" `
    -alias "$Alias" `
    -keypass "$KeyPassword" `
    -dname "$Dname" `
    -keyalg RSA `
    -keysize 2048 `
    -validity "$ValidityDays"

docker run --rm `
  -v "${keystoreDir}:/out" `
  $image `
  keytool -export -rfc `
    -alias "$Alias" `
    -keystore "$containerKeystorePath" `
    -storepass "$KeystorePassword" `
    -file "$containerCertPath"

$certFullPath = Join-Path $keystoreDir $certFileName
if (-not (Test-Path $keystoreFullPath)) {
    Write-Error "Keystore was not created: $keystoreFullPath"
    exit 1
}
if (-not (Test-Path $certFullPath)) {
    Write-Error "Upload certificate was not created: $certFullPath"
    exit 1
}

Write-Host "Keystore created: $keystoreFullPath"
Write-Host "Upload certificate created: $certFullPath"
