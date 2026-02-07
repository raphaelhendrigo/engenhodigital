# Release Android (Google Play) via CI/CD

Este repositório **não** é um app Android Gradle (Flutter/RN/Ionic/Cordova). É um app **Python/Kivy** empacotado para Android via **Buildozer** (`buildozer.spec`), então o **Gradle Play Publisher** não se aplica aqui. A publicação automatizada é feita via **Fastlane (supply)**.

## Workflows (GitHub Actions)

- `android-ci.yml`
  - Triggers: `pull_request`, `push` em `main`
  - Faz: lint básico (syntax) + build `debug` via Buildozer

- `android-release.yml`
  - Triggers: tag `v*` e `workflow_dispatch`
  - Faz: gera `.aab` **release** assinado e publica no Google Play.
  - Tag `vX.Y.Z`: publica sempre em `internal` (padrão seguro).
  - `workflow_dispatch`: permite escolher track e opcionalmente **promover para production**.

## Secrets (obrigatórios)

Configure em `Settings -> Secrets and variables -> Actions`:

- `ANDROID_KEYSTORE_BASE64`
  - Conteúdo **base64** do seu `.jks` (upload key).
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
  - Senha do alias (key password).
  - Compatibilidade: o CI também aceita `ANDROID_KEY_ALIAS_PASSWORD` (legado), mas prefira `ANDROID_KEY_PASSWORD`.
- `PLAY_SERVICE_ACCOUNT_JSON`
  - Conteúdo do JSON da service account (chave privada). Não comitar em arquivo no repo.

Gerar `ANDROID_KEYSTORE_BASE64`:

```bash
base64 -w0 keystore/engenho-digital-upload.jks
```

PowerShell (Windows):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("keystore\\engenho-digital-upload.jks"))
```

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
- `promote_to_production`: `true/false` (se `true`, promove o release do track escolhido para `production`)

## Versionamento (CI)

- `versionName`: em tags `vX.Y.Z`, vira `X.Y.Z` (sem `v`) e é injetado no `buildozer.spec`.
- `versionCode` (`android.numeric_version`): calculado no CI como `YYYYMMDD * 100 + (run_number % 100)` em UTC, evitando colisão e mantendo < 2.147.483.647.

## Rodar release local (Linux/WSL)

Pré-requisitos:
- Buildozer + toolchain Android (SDK/NDK/JDK) em Linux/WSL
- Ruby + Bundler (para Fastlane) ou rode o upload só via CI

Passos (exemplo):

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

Checklist do Play Console e setup inicial (service account, permissões, app signing):
- `CHECKLIST_MANUAL_PLAY_CONSOLE.md`

## Links diretos (para autorizações manuais)

```text
GitHub Secrets (Actions):
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
