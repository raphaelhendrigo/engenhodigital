# Release Android (Google Play) via CI/CD

Este repositório **não** é um app Android Gradle (Flutter/RN/Ionic/Cordova). É um app **Python/Kivy** empacotado para Android via **Buildozer** (`buildozer.spec`). A publicação automatizada no Google Play é feita via **Fastlane (supply)**.

## Quickstart (PowerShell, Windows)

```powershell
cd c:\apps\engenhodigital
gh auth login
gcloud auth login
.\scripts\bootstrap_play_ci.ps1 -GcpProjectId "<GCP_PROJECT_ID (ex: engenhodigital)>"
git tag v1.2.3; git push origin v1.2.3
```

## Workflows (GitHub Actions)

- `android-ci.yml`
  - Triggers: `pull_request`, `push` em `main`
  - Faz: lint básico (syntax) + testes + build `debug` via Buildozer
- `android-release.yml`
  - Triggers: tag `v*` e `workflow_dispatch`
  - Faz: valida config, gera `.aab` **release** assinado e publica no Google Play.
  - Tag `vX.Y.Z`: publica sempre em `internal` (padrão seguro).
  - `workflow_dispatch`: permite escolher track e (opcional) **promover para production**.

## Autenticação no Google Play (2 modos)

### Modo A (preferido): WIF (keyless) via GitHub OIDC

Sem JSON de chave privada. O workflow usa `google-github-actions/auth@v2` e passa o arquivo de credenciais gerado para o Fastlane como `json_key`.

Configuração (GitHub Actions -> Variables):
- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT_EMAIL`

O script `scripts/bootstrap_play_ci.ps1` configura isso automaticamente quando você passa `-GcpProjectId`.

### Modo B (fallback): JSON da service account em Secret

Configuração (GitHub Actions -> Secrets):
- `PLAY_SERVICE_ACCOUNT_JSON` (conteúdo do JSON com `private_key`)

Observação: este modo é suportado, mas a recomendação é migrar para WIF por segurança (ver `SECURITY_NOTES.md`).

## Android Signing (Secrets obrigatórios)

Configure em `Settings -> Secrets and variables -> Actions`:
- `ANDROID_KEYSTORE_BASE64` (base64 do `.jks` da upload key)
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
  - Compatibilidade: o CI também aceita `ANDROID_KEY_ALIAS_PASSWORD` (legado), mas prefira `ANDROID_KEY_PASSWORD`.

O script `scripts/bootstrap_play_ci.ps1` gera o keystore e configura esses secrets automaticamente via `gh`.

## Como publicar

### 1) Release por tag (recomendado)

Publica automaticamente no track **internal**:

```bash
git tag v1.2.3
git push origin v1.2.3
```

### 2) Release manual (workflow_dispatch)

Em `Actions -> Android Release (Play Store) -> Run workflow`:
- `release_track`: `internal` (default), `beta`, `alpha`, `production` (`closed` é aceito como alias de `beta`)
- `version_name`: opcional (ex: `1.2.3`) para `workflow_dispatch` (em tags `vX.Y.Z` é automático)
- `promote_to_production`: `true/false` (se `true`, promove o release do track escolhido para `production`)

## Versionamento (CI)

- `versionName`: em tags `vX.Y.Z`, vira `X.Y.Z` (sem `v`) e é injetado no `buildozer.spec`.
- `versionCode` (`android.numeric_version`): calculado no CI como `YYYYMMDD * 100 + (run_number % 100)` em UTC, evitando colisão e mantendo < 2.147.483.647.

## ONE-TIME SETUP (Play Console) - o inevitável

Checklist completo: `CHECKLIST_MANUAL_PLAY_CONSOLE.md`

Pontos principais:
1. Criar o app (se ainda não existe): https://play.google.com/console
2. Habilitar Play App Signing (Setup -> App integrity).
   - Se o Play Console pedir o certificado da upload key, selecione o arquivo gerado pelo bootstrap:
     - `c:\apps\engenhodigital\keystore\engenho-digital-upload-cert.pem` (Windows)
3. (Opcional) Linkar um projeto do Google Cloud na conta do Play Console:
   - Developer account -> API access
   - Link curto (as vezes redireciona): https://play.google.com/console/developers/api-access
   - Link "fixo" (use seu Developer Account ID): https://play.google.com/console/u/0/developers/<DEVELOPER_ACCOUNT_ID>/api-access
   - Dica: se você cair em `.../developers/<ID>/app-list`, troque `app-list` por `api-access`.
   - Se a pagina de **API access** redirecionar/nao existir, siga em frente: o fluxo via **Users and permissions** e suficiente.
4. Conceder acesso para a service account (no Play Console, no app):
   - API access -> Service accounts -> Grant access
5. Completar formulários obrigatórios antes do primeiro release (Store listing, Data safety, Content rating, etc).
6. Para publicar em **production**, o Play Console pode exigir **Teste fechado** (ex.: 12 testadores por 14 dias) antes de liberar acesso de producao.

## Rodar release local (Linux/WSL) (opcional)

Pré-requisitos:
- Buildozer + toolchain Android (SDK/NDK/JDK) em Linux/WSL
- Ruby + Bundler (para Fastlane) ou rode o upload só via CI

Passos (exemplo, fallback JSON):

```bash
export ANDROID_KEYSTORE_PATH="$PWD/keystore/engenho-digital-upload.jks"
export ANDROID_KEYSTORE_PASSWORD="..."
export ANDROID_KEY_ALIAS="engenho_digital_upload"
export ANDROID_KEY_PASSWORD="..."

export ANDROID_VERSION_NAME="1.2.3"
export ANDROID_NUMERIC_VERSION="2026020701"  # exemplo; precisa ser inteiro e sempre crescente no Play

python3 scripts/ci_prepare_buildozer.py
buildozer android release

export PLAY_JSON_KEY_PATH="$PWD/play-service-account.json"
export PLAY_PACKAGE_NAME="com.engenhodigital.app"
export PLAY_TRACK="internal"
export AAB_PATH="$(ls -1 bin/*.aab | head -n 1)"

bundle install
bundle exec fastlane android upload
```

## Links diretos (para autorizações manuais)

```text
GitHub Secrets/Variables (Actions):
https://github.com/raphaelhendrigo/engenhodigital/settings/secrets/actions

Workflows:
https://github.com/raphaelhendrigo/engenhodigital/actions/workflows/android-ci.yml
https://github.com/raphaelhendrigo/engenhodigital/actions/workflows/android-release.yml

GitHub auth (device flow, para gh cli):
https://github.com/login/device

Play Console:
https://play.google.com/console

Google Cloud - Service Accounts:
https://console.cloud.google.com/iam-admin/serviceaccounts

Google Cloud - Enable Android Publisher API:
https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com
```
