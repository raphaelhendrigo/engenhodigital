# Build AAB via GitHub Actions (mínimo de passos)

Este fluxo gera um `.aab` assinado automaticamente usando Buildozer.

## 1) Criar repositório
- Crie um repositório no GitHub e faça o push deste projeto.
- Garanta que o branch principal se chame `main`.

## 2) Gerar keystore (uma vez)
No seu computador (com JDK instalado):
```bash
./scripts/generate_keystore.sh
```
Isso vai criar `keystore/engenho-digital.jks`.

## 3) Criar secrets no GitHub
No repositório, vá em **Settings → Secrets and variables → Actions** e adicione:
- `ANDROID_KEYSTORE_BASE64` = conteúdo base64 do arquivo JKS
  - Gere com: `base64 -i keystore/engenho-digital.jks | pbcopy` (macOS)
- `ANDROID_KEYSTORE_PASSWORD` = senha do keystore
- `ANDROID_KEY_ALIAS` = alias usado na criação (padrão: `engenho_digital`)
- `ANDROID_KEY_ALIAS_PASSWORD` = senha do alias

## 4) Rodar o workflow
- Vá em **Actions → Android AAB (Buildozer)** e clique em **Run workflow**.
- Ao terminar, baixe o artifact `engenho-digital-aab`.

## 5) Subir no Play Console
- Faça upload do `.aab` no Play Console e finalize os formulários.

---

## Observações
- O workflow usa `buildozer.spec` e injeta as credenciais de assinatura no CI.
- Se quiser mudar o keystore, basta atualizar os secrets.
