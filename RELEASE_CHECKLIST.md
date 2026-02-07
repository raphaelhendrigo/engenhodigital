# Checklist de Publicação - Engenho Digital

## Antes do build
- Atualizar `engdigital/config.py` com site, e-mail, WhatsApp e política de privacidade.
- Substituir as imagens em `assets/` por artes reais (ícone, presplash, screenshots e feature graphic).
- Revisar textos em `STORE_LISTING.md`.

## Build (Linux/WSL)
1) Instalar dependências do sistema (Java, Android SDK/NDK) via Buildozer.
2) Gerar AAB:
   ```bash
   buildozer android release
   ```
3) Assinar com keystore (obrigatório para Play Store).

## Build/Publish via GitHub Actions (recomendado)
- Configure os secrets conforme `CI_BUILD.md`.
- Para publicar automaticamente no track `internal`, crie e faça push de uma tag `vX.Y.Z`.
- Para publicar em `beta`/`alpha`/`production` (e/ou promover para production), use **Actions → Android Release (Play Store)** (workflow dispatch).

## Play Console
- Criar o app e preencher informações da ficha.
- Subir `AAB` assinado.
- Preencher política de privacidade, categoria, classificação etária e declaração de dados.
- Submeter para revisão.

## Pós-publicação
- Acompanhar feedback do console.
- Preparar atualização com correções se necessário.
