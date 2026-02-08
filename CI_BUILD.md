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
- Play auth (escolha 1 modo):
  - Preferido (keyless): Variables `GCP_WORKLOAD_IDENTITY_PROVIDER` + `GCP_SERVICE_ACCOUNT_EMAIL`
  - Fallback: Secret `PLAY_SERVICE_ACCOUNT_JSON`

Bootstrap recomendado (gera keystore + configura secrets/vars via `gh`):
- PowerShell: `scripts/bootstrap_play_ci.ps1`
- Bash/WSL: `scripts/bootstrap_play_ci.sh`

## Publicação por tag (sem cliques)

Push de tag `vX.Y.Z` publica no track `internal`:

```bash
git tag v1.2.3
git push origin v1.2.3
```

## Publicação manual (workflow_dispatch)

`Actions -> Android Release (Play Store) -> Run workflow`:
- `release_track`: `internal`, `beta`, `alpha`, `production` (`closed` é aceito como alias de `beta`)
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
  -Track internal `
  -ReleaseStatus completed `
  -Watch
```

Observacao:
- Se voce usa WIF (vars `GCP_WORKLOAD_IDENTITY_PROVIDER` + `GCP_SERVICE_ACCOUNT_EMAIL`), nao precisa passar `-ServiceAccountJsonPath`.
- No modo fallback (JSON), passe `-ServiceAccountJsonPath` apontando para o arquivo local da key.
