# Checklist Manual (Play Console + Google Cloud)

Este checklist cobre tudo que **não** dá para automatizar 100% via CI.

## 1) Criar o app no Play Console
1. Acesse o Play Console e clique em **Create app**:
   - Link: `https://play.google.com/console`
2. Defina:
   - App name: `<APP_NAME>`
   - Default language: `<LANG>`
   - App or game: `App`
   - Free or paid: `<FREE_OR_PAID>`
3. Crie o app e complete o onboarding inicial.

## 2) Play App Signing e Upload Key
1. Em **Setup -> App integrity** (ou equivalente), habilite **Play App Signing**.
2. Gere a **upload key** (uma vez) e guarde o keystore fora do repo.

Exemplo (repo):

```bash
./scripts/generate_keystore.sh keystore/engenho-digital-upload.jks engenho_digital_upload
```

Exemplo (Windows sem JDK local, via Docker):

```powershell
.\scripts\generate_keystore_docker.ps1 `
  -KeystorePassword "<SENHA_KEYSTORE>" `
  -KeyPassword "<SENHA_ALIAS>" `
  -Alias "engenho_digital_upload"
```

3. Exporte o certificado da upload key (para cadastrar no Play Console, se necessário):

```bash
keytool -export -rfc \
  -alias engenho_digital_upload \
  -keystore keystore/engenho-digital-upload.jks \
  -file keystore/engenho-digital-upload-cert.pem
```

## 3) Linkar um projeto Google Cloud ao Play Console
1. No Play Console, vá em **Setup -> API access**.
2. **Link** um projeto existente do Google Cloud ou crie um novo.

## 4) Habilitar a Google Play Developer API
1. No Google Cloud Console (projeto linkado), habilite:
   - **Google Play Android Developer API** (`androidpublisher.googleapis.com`)
   - Link: `https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com`
2. Aguarde alguns minutos para a permissão propagar.

## 5) Criar Service Account (Google Cloud) e gerar JSON
1. No Google Cloud Console:
   - **IAM & Admin -> Service Accounts -> Create**
   - Link: `https://console.cloud.google.com/iam-admin/serviceaccounts`
2. Crie uma chave:
   - **Keys -> Add key -> Create new key -> JSON**
3. Guarde o arquivo JSON com segurança (não comitar).

## 6) Conceder acesso da Service Account no Play Console (mínimo necessário)
1. No Play Console: **Users and permissions**.
2. Convide o e-mail `client_email` da service account.
3. Conceda permissões mínimas para publicar no(s) track(s) desejado(s).

Sugestão pragmática:
- Para publicar `internal` e promover para `production`: papel equivalente a **Release manager** (somente para o app).
- Evite dar permissões globais de admin do Play Console.

## 7) Primeira configuração obrigatória do app (antes do CI publicar)
Algumas etapas costumam ser exigidas para liberar releases:
1. Preencher **Store listing** (nome, descrição, ícone, feature graphic, screenshots).
2. Configurar:
   - **Privacy Policy URL**
   - **Data safety**
   - **Content rating**
   - **Target audience / app access** (se aplicável)
3. Confirmar políticas e declarações exigidas pelo Play Console.

Observação: dependendo do estado do app no Play Console, pode ser necessário fazer **um primeiro upload manual** no track `internal` para finalizar o setup. Depois disso, o CI assume.

## 8) Configurar GitHub Secrets (obrigatório para CI/CD)
No GitHub: `Settings -> Secrets and variables -> Actions`:

- `ANDROID_KEYSTORE_BASE64`: base64 do `.jks`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `PLAY_SERVICE_ACCOUNT_JSON`: conteúdo do JSON da service account

Link direto (este repositório):
- `https://github.com/raphaelhendrigo/engenhodigital/settings/secrets/actions`

## 8.1) Arquivos locais (onde ficam no seu PC e para que servem)
- `c:\\apps\\engenhodigital\\keystore\\engenho-digital-upload.jks`
  - Não subir no Git. Use para gerar `ANDROID_KEYSTORE_BASE64`.
- `c:\\apps\\engenhodigital\\keystore\\engenho-digital-upload-cert.pem`
  - Subir no Play Console **somente** se for solicitado (App integrity -> upload key).
- `c:\\apps\\engenhodigital\\play-service-account.json`
  - Não subir no Git. Copie o conteúdo para o secret `PLAY_SERVICE_ACCOUNT_JSON`.
- `c:\\apps\\engenhodigital\\bin\\*.aab`
  - Saída de build local (gitignored). Se precisar upload manual, este é o arquivo.

## 9) Itens não automatizáveis (sempre revisar)
- Declarações legais e políticas do app
- Formulário de segurança de dados (Data safety)
- Classificação indicativa (Content rating)
- Acesso ao app / credenciais de teste (se exigido)
- Revisão e aprovação da primeira publicação em production
