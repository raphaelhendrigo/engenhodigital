param(
    # If provided, provisions Workload Identity Federation (WIF) + service account and sets GitHub Actions variables.
    [string]$GcpProjectId = "",

    # Optional override. If omitted, the script auto-detects from `git remote get-url origin`.
    [string]$GithubOwner = "",
    [string]$GithubRepo = "",

    # Android upload keystore settings
    [string]$KeystorePath = "keystore/engenho-digital-upload.jks",
    [string]$KeyAlias = "engenho_digital_upload",
    [string]$Dname = "CN=Engenho Digital,O=Engenho Digital,C=BR",
    [int]$ValidityDays = 10000,

    # Fallback mode only (if you cannot use WIF): read a local service account JSON key and set PLAY_SERVICE_ACCOUNT_JSON.
    [string]$PlayServiceAccountJsonPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Require-Command {
    param([string]$Name, [string]$Message)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Error $Message
        exit 1
    }
}

function Ensure-Gh {
    # Prefer gh from PATH, but fall back to default MSI install location.
    $ghCmd = Get-Command "gh" -ErrorAction SilentlyContinue
    if (-not $ghCmd) {
        $ghFallback = Join-Path $env:ProgramFiles "GitHub CLI\\gh.exe"
        if (Test-Path $ghFallback) {
            Set-Alias -Name gh -Value $ghFallback -Scope Local
        }
    }
    Require-Command "gh" "GitHub CLI (gh) not found. Install it and retry: https://cli.github.com/"
}

function Ensure-GhAuth {
    # Native commands don't throw on non-zero exit code; rely on $LASTEXITCODE.
    gh auth status -h github.com *> $null
    if ($LASTEXITCODE -eq 0) {
        return
    }

    Write-Host "GitHub CLI not authenticated. Starting: gh auth login" -ForegroundColor Yellow
    gh auth login
    if ($LASTEXITCODE -ne 0) {
        Write-Error "GitHub authentication failed (gh auth login)."
        exit 1
    }
}

function Get-GitHubRepoFromOrigin {
    param([string]$RepoRoot)

    Require-Command "git" "git not found. Install Git and retry."

    $origin = (git -C $RepoRoot remote get-url origin).Trim()
    if (-not $origin) {
        Write-Error "Could not read git remote 'origin'."
        exit 1
    }

    # Supports:
    # - https://github.com/OWNER/REPO.git
    # - https://github.com/OWNER/REPO
    # - git@github.com:OWNER/REPO.git
    # - git@github.com:OWNER/REPO
    #
    # PowerShell strings do NOT treat backslash as an escape character, so we must not double-escape.
    if ($origin -match "github\.com[:/](?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?$") {
        return @{
            Owner = $Matches["owner"]
            Repo  = $Matches["repo"]
            Url   = $origin
        }
    }

    Write-Error "Could not parse GitHub owner/repo from origin URL: $origin"
    exit 1
}

function New-RandomToken {
    param([int]$Length = 40)

    # Base64url-ish, no punctuation that may confuse dotenv parsing or keytool.
    $bytes = New-Object byte[] 64
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $s = [Convert]::ToBase64String($bytes)
    $s = $s -replace "[^a-zA-Z0-9]", ""
    if ($s.Length -lt $Length) {
        return ($s + (New-Guid).ToString("N")).Substring(0, $Length)
    }
    return $s.Substring(0, $Length)
}

function Ensure-GcloudAuth {
    param([string]$ProjectId)

    Require-Command "gcloud" "gcloud not found. Install Google Cloud SDK and retry: https://cloud.google.com/sdk/docs/install"

    try {
        $active = (gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>$null).Trim()
    } catch {
        $active = ""
    }

    if (-not $active) {
        Write-Host "gcloud not authenticated. Starting: gcloud auth login" -ForegroundColor Yellow
        gcloud auth login
    }

    # Ensure project is set for subsequent commands.
    gcloud config set project $ProjectId | Out-Null
}

function Provision-WifForGitHub {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectId,
        [Parameter(Mandatory = $true)][string]$GithubOwner,
        [Parameter(Mandatory = $true)][string]$GithubRepo
    )

    Ensure-GcloudAuth -ProjectId $ProjectId

    $projectNumber = (gcloud projects describe $ProjectId --format="value(projectNumber)").Trim()
    if (-not $projectNumber) {
        Write-Error "Could not resolve projectNumber for project: $ProjectId"
        exit 1
    }

    Write-Host "Enabling Android Publisher API (androidpublisher.googleapis.com)..." -ForegroundColor Cyan
    gcloud services enable androidpublisher.googleapis.com --project $ProjectId | Out-Null

    $saId = "gh-play-publisher"
    $saEmail = "$saId@$ProjectId.iam.gserviceaccount.com"

    Write-Host "Ensuring service account exists: $saEmail" -ForegroundColor Cyan
    $saExists = $true
    try {
        gcloud iam service-accounts describe $saEmail --project $ProjectId | Out-Null
    } catch {
        $saExists = $false
    }
    if (-not $saExists) {
        gcloud iam service-accounts create $saId --project $ProjectId --display-name "GitHub Play Publisher" | Out-Null
    }

    # Use deterministic pool/provider IDs per repo to avoid collisions across projects.
    $poolId = ("gh-" + $GithubRepo.ToLower()) -replace "[^a-z0-9-]", "-"
    if ($poolId.Length -gt 32) {
        $poolId = $poolId.Substring(0, 32)
    }
    $providerId = "github"

    Write-Host "Ensuring Workload Identity Pool exists: $poolId" -ForegroundColor Cyan
    $poolExists = $true
    try {
        gcloud iam workload-identity-pools describe $poolId --project $ProjectId --location "global" | Out-Null
    } catch {
        $poolExists = $false
    }
    if (-not $poolExists) {
        gcloud iam workload-identity-pools create $poolId `
            --project $ProjectId `
            --location "global" `
            --display-name "GitHub Actions pool ($GithubOwner/$GithubRepo)" | Out-Null
    }

    Write-Host "Ensuring Workload Identity Provider exists: $providerId" -ForegroundColor Cyan
    $providerExists = $true
    try {
        gcloud iam workload-identity-pools providers describe $providerId `
            --project $ProjectId `
            --location "global" `
            --workload-identity-pool $poolId | Out-Null
    } catch {
        $providerExists = $false
    }
    if (-not $providerExists) {
        $cond = "assertion.repository=='$GithubOwner/$GithubRepo'"
        gcloud iam workload-identity-pools providers create-oidc $providerId `
            --project $ProjectId `
            --location "global" `
            --workload-identity-pool $poolId `
            --display-name "GitHub Actions ($GithubOwner/$GithubRepo)" `
            --issuer-uri "https://token.actions.githubusercontent.com" `
            --attribute-mapping "google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref,attribute.actor=assertion.actor" `
            --attribute-condition $cond | Out-Null
    }

    Write-Host "Binding roles/iam.workloadIdentityUser to repo principalSet..." -ForegroundColor Cyan
    $member = "principalSet://iam.googleapis.com/projects/$projectNumber/locations/global/workloadIdentityPools/$poolId/attribute.repository/$GithubOwner/$GithubRepo"
    gcloud iam service-accounts add-iam-policy-binding $saEmail `
        --project $ProjectId `
        --role "roles/iam.workloadIdentityUser" `
        --member $member | Out-Null

    $providerResource = "projects/$projectNumber/locations/global/workloadIdentityPools/$poolId/providers/$providerId"
    return @{
        ServiceAccountEmail = $saEmail
        WorkloadIdentityProvider = $providerResource
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

Ensure-Gh
Ensure-GhAuth

if (-not $GithubOwner -or -not $GithubRepo) {
    $info = Get-GitHubRepoFromOrigin -RepoRoot $repoRoot
    if (-not $GithubOwner) { $GithubOwner = $info.Owner }
    if (-not $GithubRepo) { $GithubRepo = $info.Repo }
}

$repoFullName = "$GithubOwner/$GithubRepo"

Write-Host "Repo: $repoFullName" -ForegroundColor Green

# 1) Generate upload keystore + cert
$keystorePassword = New-RandomToken -Length 48
$keyPassword = New-RandomToken -Length 48

$keystoreFullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $KeystorePath))
$keystoreDir = Split-Path -Parent $keystoreFullPath
$keystoreFile = Split-Path -Leaf $keystoreFullPath
$certFile = ([System.IO.Path]::GetFileNameWithoutExtension($keystoreFile)) + "-cert.pem"
$certFullPath = Join-Path $keystoreDir $certFile
$credLocalPath = Join-Path $keystoreDir (([System.IO.Path]::GetFileNameWithoutExtension($keystoreFile)) + ".credentials.local.txt")

Write-Host "Generating upload keystore (Docker + keytool)..." -ForegroundColor Cyan
& (Join-Path $repoRoot "scripts\\generate_keystore_docker.ps1") `
    -KeystorePath $KeystorePath `
    -Alias $KeyAlias `
    -KeystorePassword $keystorePassword `
    -KeyPassword $keyPassword `
    -Dname $Dname `
    -ValidityDays $ValidityDays

if (-not (Test-Path $keystoreFullPath)) {
    Write-Error "Keystore not found after generation: $keystoreFullPath"
    exit 1
}
if (-not (Test-Path $certFullPath)) {
    Write-Error "Cert not found after generation: $certFullPath"
    exit 1
}

# Store locally (gitignored) so you can recover for local signing if needed.
@"
ANDROID_KEYSTORE_PATH=$keystoreFullPath
ANDROID_KEYSTORE_PASSWORD=$keystorePassword
ANDROID_KEY_ALIAS=$KeyAlias
ANDROID_KEY_PASSWORD=$keyPassword
"@ | Set-Content -Path $credLocalPath -Encoding ascii

# 2) Configure GitHub secrets (no secrets on command line)
Write-Host "Setting GitHub Actions secrets (Android signing)..." -ForegroundColor Cyan
$keystoreB64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($keystoreFullPath))

$dotenv = @"
ANDROID_KEYSTORE_BASE64=$keystoreB64
ANDROID_KEYSTORE_PASSWORD=$keystorePassword
ANDROID_KEY_ALIAS=$KeyAlias
ANDROID_KEY_PASSWORD=$keyPassword
ANDROID_KEY_ALIAS_PASSWORD=$keyPassword
"@
$dotenv | gh secret set -f - -R $repoFullName | Out-Null

# 3) Play credentials: WIF preferred, JSON fallback
$wif = $null
if ($GcpProjectId) {
    Write-Host "Provisioning WIF (keyless) on Google Cloud..." -ForegroundColor Cyan
    $wif = Provision-WifForGitHub -ProjectId $GcpProjectId -GithubOwner $GithubOwner -GithubRepo $GithubRepo

    Write-Host "Setting GitHub Actions variables (WIF)..." -ForegroundColor Cyan
    @"
GCP_WORKLOAD_IDENTITY_PROVIDER=$($wif.WorkloadIdentityProvider)
GCP_SERVICE_ACCOUNT_EMAIL=$($wif.ServiceAccountEmail)
"@ | gh variable set -f - -R $repoFullName | Out-Null
} elseif ($PlayServiceAccountJsonPath) {
    if (-not (Test-Path $PlayServiceAccountJsonPath)) {
        Write-Error "Service account JSON not found: $PlayServiceAccountJsonPath"
        exit 1
    }
    Write-Host "Setting PLAY_SERVICE_ACCOUNT_JSON (fallback mode)..." -ForegroundColor Yellow
    # Validate minimal structure (do not print private_key).
    try {
        $raw = Get-Content -Raw -Path $PlayServiceAccountJsonPath
        $json = $raw | ConvertFrom-Json
        if ($json.type -ne "service_account" -or -not $json.client_email -or -not $json.private_key) {
            throw "JSON does not look like a service_account key."
        }
    } catch {
        Write-Error "Invalid service account JSON: $($_.Exception.Message)"
        exit 1
    }
    $raw | gh secret set PLAY_SERVICE_ACCOUNT_JSON -R $repoFullName | Out-Null
} else {
    Write-Host "Play auth not configured yet." -ForegroundColor Yellow
    Write-Host "Preferred: re-run with -GcpProjectId <YOUR_PROJECT_ID> to provision WIF (keyless)." -ForegroundColor Yellow
    Write-Host "Fallback: re-run with -PlayServiceAccountJsonPath <path-to-json> to set PLAY_SERVICE_ACCOUNT_JSON." -ForegroundColor Yellow
}

# 4) Final output (no secrets)
Write-Host ""
Write-Host "Files generated (keep these OUT of git):" -ForegroundColor Green
Write-Host "- Keystore: $keystoreFullPath"
Write-Host "- Upload cert (PEM): $certFullPath"
Write-Host "- Local credentials (gitignored): $credLocalPath"

Write-Host ""
Write-Host "Release command:" -ForegroundColor Green
Write-Host "  git tag vX.Y.Z; git push origin vX.Y.Z"

Write-Host ""
Write-Host "ONE-TIME SETUP (Play Console) - inevitable UI steps:" -ForegroundColor Green
Write-Host "1) Create the app (if not created yet): https://play.google.com/console"
Write-Host "2) Enable Play App Signing (Setup -> App integrity). If asked for upload key cert, select:"
Write-Host "   $certFullPath"
Write-Host "3) Link a Google Cloud project (Developer account -> API access): https://play.google.com/console/developers/api-access"
if ($wif) {
    Write-Host "4) Grant access to the service account in Play Console (API access -> Service accounts -> Grant access):"
    Write-Host "   $($wif.ServiceAccountEmail)"
}
Write-Host "5) Complete required forms (Store listing, Data safety, Content rating, etc.) before first release."
