# Checklist de Publicação - Engenho Digital

## Antes do build
- Atualizar `engdigital/config.py` com site, e-mail, WhatsApp e política de privacidade.
- Substituir as imagens em `assets/` por artes reais (ícone, presplash, screenshots e feature graphic).
- Revisar textos em `STORE_LISTING.md`.

## Build (Linux/WSL)
1) Instalar dependências do sistema (Java, Android SDK/NDK) via Buildozer.
2) Gerar AAB:
   ```bash
   buildozer android release aab
   ```
3) Assinar com keystore (obrigatório para Play Store).

## Play Console
- Criar o app e preencher informações da ficha.
- Subir `AAB` assinado.
- Preencher política de privacidade, categoria, classificação etária e declaração de dados.
- Submeter para revisão.

## Pós-publicação
- Acompanhar feedback do console.
- Preparar atualização com correções se necessário.
