param(
    [Parameter(Mandatory = $true)]
    [string]$KeystorePath,
    [Parameter(Mandatory = $true)]
    [string]$KeystorePassword,
    [Parameter(Mandatory = $true)]
    [string]$KeyAlias,
    [Parameter(Mandatory = $true)]
    [string]$KeyAliasPassword,
    [Parameter(Mandatory = $true)]
    [string]$ServiceAccountJsonPath,
    [ValidateSet("internal", "closed", "production")]
    [string]$Track = "internal",
    [ValidateSet("draft", "inProgress", "completed", "halted")]
    [string]$ReleaseStatus = "completed",
    [string]$ReleaseName = "",
    [string]$Ref = "main",
    [switch]$Watch,
    [string]$Token
)

$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name, [string]$Message)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Error $Message
        exit 1
    }
}

Require-Command "gh" "GitHub CLI (gh) not found. Install it and try again."

if ($Token) {
    $env:GH_TOKEN = $Token
}

if (-not $env:GH_TOKEN -and (Get-Command git -ErrorAction SilentlyContinue)) {
    try {
        $cred = "protocol=https`nhost=github.com`n`n"
        $tokenLine = $cred | git credential fill 2>$null | Select-String "^password=" | Select-Object -First 1
        if ($tokenLine) {
            $env:GH_TOKEN = $tokenLine.Line.Substring(9)
        }
    } catch {
        # Ignore git credential errors; GH_TOKEN may be set elsewhere.
    }
}

if (-not $env:GH_TOKEN) {
    Write-Error "Missing GH_TOKEN. Provide -Token or set GH_TOKEN in the environment."
    exit 1
}

if (-not (Test-Path $KeystorePath)) {
    Write-Error "Keystore file not found: $KeystorePath"
    exit 1
}

if (-not (Test-Path $ServiceAccountJsonPath)) {
    Write-Error "Service account JSON not found: $ServiceAccountJsonPath"
    exit 1
}

try {
    $serviceJsonRaw = Get-Content -Raw -Path $ServiceAccountJsonPath
    $serviceJson = $serviceJsonRaw | ConvertFrom-Json
    if ($serviceJson.type -ne "service_account") {
        throw "JSON type is not service_account."
    }
    if (-not $serviceJson.client_email -or -not $serviceJson.private_key) {
        throw "Missing required fields in JSON."
    }
} catch {
    Write-Error "Invalid service account JSON: $($_.Exception.Message)"
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")
Set-Location $repoRoot

$keystoreBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $KeystorePath))
$keystoreB64 = [Convert]::ToBase64String($keystoreBytes)

gh secret set ANDROID_KEYSTORE_BASE64 -b $keystoreB64
gh secret set ANDROID_KEYSTORE_PASSWORD -b $KeystorePassword
gh secret set ANDROID_KEY_ALIAS -b $KeyAlias
# New standard secret name (preferred) + legacy name for backward compatibility.
gh secret set ANDROID_KEY_PASSWORD -b $KeyAliasPassword
gh secret set ANDROID_KEY_ALIAS_PASSWORD -b $KeyAliasPassword
gh secret set PLAY_SERVICE_ACCOUNT_JSON -b $serviceJsonRaw

$prevRun = ""
try {
    $prevRun = gh run list -w android-release.yml -b $Ref -e workflow_dispatch -L 1 --json databaseId --jq '.[0].databaseId' 2>$null
} catch {
    $prevRun = ""
}

$args = @("android-release.yml", "--ref", $Ref, "-f", "release_track=$Track", "-f", "release_status=$ReleaseStatus", "-f", "promote_to_production=false")
if ($ReleaseName) {
    $args += @("-f", "release_name=$ReleaseName")
}

Write-Host "Triggering workflow Android Release (Play Store)..."
gh workflow run @args

if ($Watch) {
    Write-Host "Waiting for new run to appear..."
    $runId = ""
    for ($i = 0; $i -lt 30; $i++) {
        try {
            $runId = gh run list -w android-release.yml -b $Ref -e workflow_dispatch -L 1 --json databaseId --jq '.[0].databaseId' 2>$null
        } catch {
            $runId = ""
        }
        if ($runId -and $runId -ne "null" -and $runId -ne $prevRun) {
            break
        }
        Start-Sleep -Seconds 2
    }

    if (-not $runId -or $runId -eq "null" -or $runId -eq $prevRun) {
        Write-Warning "Could not detect the run automatically. Check GitHub Actions -> Android Release (Play Store)."
        exit 0
    }

    Write-Host "Watching run $runId..."
    gh run watch $runId --exit-status
    gh run view $runId
}
