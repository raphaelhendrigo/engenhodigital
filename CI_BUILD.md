# Android CI/CD (Buildozer + Play Store)

Este repositório gera Android via **Buildozer** (`buildozer.spec`). A publicação automatizada no Google Play é feita via **Fastlane (supply)**.

Documentação completa:
- `docs/RELEASE_PLAYSTORE.md`
- `CHECKLIST_MANUAL_PLAY_CONSOLE.md`
- `SECURITY_NOTES.md`

## Workflows

- **Android CI (Buildozer)** (`.github/workflows/android-ci.yml`)
  - `pull_request` e `push` em `main`
  - lint básico + build `debug`

- **Android Release (Play Store)** (`.github/workflows/android-release.yml`)
  - tag `v*` e `workflow_dispatch`
  - build `release` (`.aab`) assinado + upload no Google Play

## Secrets (GitHub Actions)

Em `Settings -> Secrets and variables -> Actions`:
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD` (senha do alias)
  - compatibilidade: `ANDROID_KEY_ALIAS_PASSWORD` também funciona (legado), mas prefira `ANDROID_KEY_PASSWORD`
- `PLAY_SERVICE_ACCOUNT_JSON`

## Publicação por tag (sem cliques)

Push de tag `vX.Y.Z` publica no track `internal`:

```bash
git tag v1.2.3
git push origin v1.2.3
```

## Publicação manual (workflow_dispatch)

`Actions -> Android Release (Play Store) -> Run workflow`:
- `release_track`: `internal`, `closed`, `open`, `production` (também aceita `beta` como alias de `closed`)
- `promote_to_production`: `true/false`

## Scripts auxiliares (opcionais)

- Bash:
```bash
./scripts/play/publish_internal.sh internal completed
```

- PowerShell (Windows):
```powershell
.\scripts\play\publish.ps1 `
  -KeystorePath .\keystore\engenho-digital-upload.jks `
  -KeystorePassword "SENHA_DO_KEYSTORE" `
  -KeyAlias "engenho_digital_upload" `
  -KeyAliasPassword "SENHA_DO_ALIAS" `
  -ServiceAccountJsonPath .\play-service-account.json `
  -Track internal `
  -ReleaseStatus completed `
  -Watch
```
