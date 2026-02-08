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

function Read-DotenvFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $map = @{}
    foreach ($raw in (Get-Content -Path $Path -ErrorAction Stop)) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith("#")) { continue }
        $idx = $line.IndexOf("=")
        if ($idx -lt 1) { continue }
        $k = $line.Substring(0, $idx).Trim()
        $v = $line.Substring($idx + 1).Trim()
        if ($k) { $map[$k] = $v }
    }
    return $map
}

function Read-SecretPlain {
    param([Parameter(Mandatory = $true)][string]$Prompt)

    $sec = Read-Host $Prompt -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

function Invoke-NativeChecked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Args,
        [string]$ErrorMessage = ""
    )

    $output = & $FilePath @Args 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        $cmdLine = ($Args -join " ")
        $prefix = if ($ErrorMessage) { $ErrorMessage } else { "$FilePath failed (exit $code): $cmdLine" }
        Write-Error ($prefix + "`n" + ($output -join "`n"))
        exit 1
    }

    return $output
}

function Ensure-GcloudAuth {
    param([string]$ProjectId = "")

    Require-Command "gcloud" "gcloud not found. Install Google Cloud SDK and retry: https://cloud.google.com/sdk/docs/install"

    $active = ((& gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>$null) -join "`n").Trim()

    if (-not $active) {
        Write-Host "gcloud not authenticated. Starting: gcloud auth login" -ForegroundColor Yellow
        & gcloud auth login
        if ($LASTEXITCODE -ne 0) {
            Write-Error "gcloud authentication failed (gcloud auth login)."
            exit 1
        }
    }

    if ($ProjectId) {
        # Ensure project is set for subsequent commands.
        & gcloud config set project $ProjectId | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to set gcloud project: $ProjectId"
            exit 1
        }
    }
}

function Resolve-GcpProjectId {
    param([Parameter(Mandatory = $true)][string]$ProjectIdOrNumber)

    $value = $ProjectIdOrNumber.Trim()
    if (-not $value) {
        Write-Error "Missing GCP project value."
        exit 1
    }

    # If the user passed a project NUMBER, map it to the project ID (required by many gcloud IAM commands).
    if ($value -match "^[0-9]+$") {
        Ensure-GcloudAuth
        $rows = & gcloud projects list --format="value(projectId,projectNumber)" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to list GCP projects (gcloud projects list)."
            exit 1
        }

        foreach ($row in $rows) {
            $parts = ($row -split '\s+')
            if ($parts.Length -lt 2) { continue }
            $pid = $parts[0].Trim()
            $pnum = $parts[1].Trim()
            if ($pnum -eq $value) {
                return $pid
            }
        }

        Write-Error "Project number $value not found in 'gcloud projects list'. Use the project ID (example: engenhodigital)."
        exit 1
    }

    return $value
}

function Provision-WifForGitHub {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectId,
        [Parameter(Mandatory = $true)][string]$GithubOwner,
        [Parameter(Mandatory = $true)][string]$GithubRepo
    )

    Ensure-GcloudAuth -ProjectId $ProjectId

    $projectNumber = ((Invoke-NativeChecked -FilePath "gcloud" -Args @("projects", "describe", $ProjectId, "--format=value(projectNumber)")) -join "`n").Trim()
    if (-not $projectNumber) {
        Write-Error "Could not resolve projectNumber for project: $ProjectId"
        exit 1
    }

    Write-Host "Enabling Android Publisher API (androidpublisher.googleapis.com)..." -ForegroundColor Cyan
    Invoke-NativeChecked -FilePath "gcloud" -Args @("services", "enable", "androidpublisher.googleapis.com", "--project", $ProjectId) | Out-Null

    $saId = "gh-play-publisher"
    $saEmail = "$saId@$ProjectId.iam.gserviceaccount.com"

    Write-Host "Ensuring service account exists: $saEmail" -ForegroundColor Cyan
    & gcloud iam service-accounts describe $saEmail --project $ProjectId *> $null
    $saExists = ($LASTEXITCODE -eq 0)
    if (-not $saExists) {
        Invoke-NativeChecked -FilePath "gcloud" -Args @(
            "iam",
            "service-accounts",
            "create",
            $saId,
            "--project",
            $ProjectId,
            "--display-name",
            "GitHub Play Publisher"
        ) | Out-Null
    }

    # Use deterministic pool/provider IDs per repo to avoid collisions across projects.
    $poolId = ("gh-" + $GithubRepo.ToLower()) -replace "[^a-z0-9-]", "-"
    if ($poolId.Length -gt 32) {
        $poolId = $poolId.Substring(0, 32)
    }
    $providerId = "github"

    Write-Host "Ensuring Workload Identity Pool exists: $poolId" -ForegroundColor Cyan
    & gcloud iam workload-identity-pools describe $poolId --project $ProjectId --location "global" *> $null
    $poolExists = ($LASTEXITCODE -eq 0)
    if (-not $poolExists) {
        Invoke-NativeChecked -FilePath "gcloud" -Args @(
            "iam",
            "workload-identity-pools",
            "create",
            $poolId,
            "--project",
            $ProjectId,
            "--location",
            "global",
            "--display-name",
            "GitHub Actions pool ($GithubOwner/$GithubRepo)"
        ) | Out-Null
    }

    Write-Host "Ensuring Workload Identity Provider exists: $providerId" -ForegroundColor Cyan
    & gcloud iam workload-identity-pools providers describe $providerId `
        --project $ProjectId `
        --location "global" `
        --workload-identity-pool $poolId *> $null
    $providerExists = ($LASTEXITCODE -eq 0)
    if (-not $providerExists) {
        $cond = "assertion.repository=='$GithubOwner/$GithubRepo'"
        Invoke-NativeChecked -FilePath "gcloud" -Args @(
            "iam",
            "workload-identity-pools",
            "providers",
            "create-oidc",
            $providerId,
            "--project",
            $ProjectId,
            "--location",
            "global",
            "--workload-identity-pool",
            $poolId,
            "--display-name",
            "GitHub Actions ($GithubOwner/$GithubRepo)",
            "--issuer-uri",
            "https://token.actions.githubusercontent.com",
            "--attribute-mapping",
            "google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref,attribute.actor=assertion.actor",
            "--attribute-condition",
            $cond
        ) | Out-Null
    }

    Write-Host "Binding roles/iam.workloadIdentityUser to repo principalSet..." -ForegroundColor Cyan
    $member = "principalSet://iam.googleapis.com/projects/$projectNumber/locations/global/workloadIdentityPools/$poolId/attribute.repository/$GithubOwner/$GithubRepo"
    Invoke-NativeChecked -FilePath "gcloud" -Args @(
        "iam",
        "service-accounts",
        "add-iam-policy-binding",
        $saEmail,
        "--project",
        $ProjectId,
        "--role",
        "roles/iam.workloadIdentityUser",
        "--member",
        $member
    ) | Out-Null

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
$keystoreFullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $KeystorePath))
$keystoreDir = Split-Path -Parent $keystoreFullPath
$keystoreFile = Split-Path -Leaf $keystoreFullPath
$certFile = ([System.IO.Path]::GetFileNameWithoutExtension($keystoreFile)) + "-cert.pem"
$certFullPath = Join-Path $keystoreDir $certFile
$credLocalPath = Join-Path $keystoreDir (([System.IO.Path]::GetFileNameWithoutExtension($keystoreFile)) + ".credentials.local.txt")

$keystorePassword = ""
$keyPassword = ""
if (Test-Path $credLocalPath) {
    $envMap = Read-DotenvFile -Path $credLocalPath
    if ($envMap.ContainsKey("ANDROID_KEYSTORE_PASSWORD")) { $keystorePassword = $envMap["ANDROID_KEYSTORE_PASSWORD"] }
    if ($envMap.ContainsKey("ANDROID_KEY_PASSWORD")) { $keyPassword = $envMap["ANDROID_KEY_PASSWORD"] }
    if ($envMap.ContainsKey("ANDROID_KEY_ALIAS") -and $envMap["ANDROID_KEY_ALIAS"]) { $KeyAlias = $envMap["ANDROID_KEY_ALIAS"] }
}

if (-not (Test-Path $keystoreFullPath)) {
    $keystorePassword = New-RandomToken -Length 48
    $keyPassword = New-RandomToken -Length 48

    Write-Host "Generating upload keystore (Docker + keytool)..." -ForegroundColor Cyan
    & (Join-Path $repoRoot "scripts\\generate_keystore_docker.ps1") `
        -KeystorePath $KeystorePath `
        -Alias $KeyAlias `
        -KeystorePassword $keystorePassword `
        -KeyPassword $keyPassword `
        -Dname $Dname `
        -ValidityDays $ValidityDays
} else {
    Write-Host "Keystore already exists. Reusing: $keystoreFullPath" -ForegroundColor Yellow
    if (-not $keystorePassword) {
        $keystorePassword = Read-SecretPlain -Prompt "Enter existing keystore password (will be stored only in GitHub Secrets)"
    }
    if (-not $keyPassword) {
        $keyPassword = Read-SecretPlain -Prompt "Enter existing key password (alias password)"
    }
}

if (-not (Test-Path $keystoreFullPath)) {
    Write-Error "Keystore not found after generation: $keystoreFullPath"
    exit 1
}

if (-not (Test-Path $certFullPath)) {
    Write-Host "Upload certificate not found. Exporting cert via Docker + keytool..." -ForegroundColor Cyan
    Require-Command "docker" "Docker not found. Install Docker Desktop and try again."
    $image = "eclipse-temurin:17-jdk"
    docker pull $image | Out-Null
    docker run --rm `
      -v "${keystoreDir}:/out" `
      $image `
      keytool -export -rfc `
        -alias "$KeyAlias" `
        -keystore "/out/$keystoreFile" `
        -storepass "$keystorePassword" `
        -file "/out/$certFile"
    if (-not (Test-Path $certFullPath)) {
        Write-Error "Upload certificate was not created: $certFullPath"
        exit 1
    }
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
    if ($GcpProjectId -match "[<>]" -or $GcpProjectId -in @("SEU_PROJECT_ID_REAL", "YOUR_PROJECT_ID", "<GCP_PROJECT_ID>")) {
        Write-Error "Invalid -GcpProjectId value. Pass the real Google Cloud project ID (example: my-project-123)."
        exit 1
    }
    Write-Host "Provisioning WIF (keyless) on Google Cloud..." -ForegroundColor Cyan
    $resolvedProjectId = Resolve-GcpProjectId -ProjectIdOrNumber $GcpProjectId
    $wif = Provision-WifForGitHub -ProjectId $resolvedProjectId -GithubOwner $GithubOwner -GithubRepo $GithubRepo

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
