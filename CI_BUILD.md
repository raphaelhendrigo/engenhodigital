# Build AAB via GitHub Actions (mínimo de passos)

Este fluxo gera um `.aab` assinado automaticamente usando Buildozer.

## 1) Criar repositório
- Crie um repositório no GitHub e faça o push deste projeto.
- Garanta que o branch principal se chame `main`.

## 2) Gerar upload key (uma vez)
No seu computador (com JDK instalado):
```bash
./scripts/generate_keystore.sh keystore/engenho-digital-upload.jks engenho_digital_upload
```
Isso vai criar `keystore/engenho-digital-upload.jks`.

Exporte o certificado da upload key (para cadastrar no Play Console):
```bash
keytool -export -rfc \
  -alias engenho_digital_upload \
  -keystore keystore/engenho-digital-upload.jks \
  -file keystore/engenho-digital-upload-cert.pem
```

## 3) Criar secrets no GitHub
No repositório, vá em **Settings → Secrets and variables → Actions** e adicione:
- `ANDROID_KEYSTORE_BASE64` = conteúdo base64 do arquivo JKS
  - Gere com: `base64 -i keystore/engenho-digital-upload.jks | pbcopy` (macOS)
- `ANDROID_KEYSTORE_PASSWORD` = senha do keystore
- `ANDROID_KEY_ALIAS` = alias usado na criação (padrão: `engenho_digital_upload`)
- `ANDROID_KEY_ALIAS_PASSWORD` = senha do alias
- `PLAY_SERVICE_ACCOUNT_JSON` = JSON da Service Account com acesso ao Play Console

Se o upload falhar com erro de API desabilitada, habilite no Google Cloud:
- API: **Google Play Android Developer API** (`androidpublisher.googleapis.com`)
- Depois aguarde 2-5 minutos e rode o workflow novamente.

Opcional (menos cliques): configurar o `PLAY_SERVICE_ACCOUNT_JSON` via GitHub CLI (`gh`):
```bash
cp play-service-account.json.example play-service-account.json
# Edite play-service-account.json e cole o JSON real (nao commitar; esta no .gitignore)
./scripts/play/set_play_service_account_secret.sh
```

## 4) Rodar o workflow
- Vá em **Actions → Android AAB (Buildozer)** e clique em **Run workflow**.
- Para publicar automaticamente, use:
  - `publish = true`
  - `track = internal | closed | production`
  - `release_status = draft | inProgress | completed | halted`
- Ao terminar, baixe o artifact `engenho-digital-aab` (se quiser o AAB local).

Opcional (automatizado via `gh`):
```bash
./scripts/play/publish_internal.sh internal completed
```

## 5) Subir no Play Console
- Se `publish = true`, o upload é feito automaticamente.
- Se preferir manual, faça upload do `.aab` no Play Console e finalize os formulários.
- Se for a primeira vez com a upload key nova, vá em **Integridade do app → Chaves de assinatura do app → Substituir chave de upload** e envie `keystore/engenho-digital-upload-cert.pem`.

---

## Observações
- O workflow usa `buildozer.spec` e injeta as credenciais de assinatura no CI.
- Se quiser mudar o keystore, basta atualizar os secrets.
- O `android.numeric_version` é calculado automaticamente no CI (baseado na data) para evitar conflitos de versionCode no Play Console.
