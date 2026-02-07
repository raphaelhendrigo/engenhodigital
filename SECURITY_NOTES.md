# Security Notes (CI/CD + Play Store)

## Princípios
- Nunca commitar: keystore, senhas, JSON da service account, outputs (`bin/`, `.buildozer/`).
- Segredos somente via **GitHub Secrets** (ou equivalente no provedor de CI).
- Menor privilégio possível: service account com acesso apenas ao app necessário.

## Service Account (Google Play Developer API)
- Crie uma service account dedicada para este app.
- No Play Console, conceda apenas permissões necessárias para:
  - publicar em `internal` (e opcionalmente promover para `production`)
- Rotacione a chave JSON periodicamente:
  - crie uma nova key
  - atualize `PLAY_SERVICE_ACCOUNT_JSON` no GitHub
  - revogue a key antiga no Google Cloud

## Upload Key / Keystore
- Guarde o `.jks` em cofre seguro (1Password/Vault/KMS), nunca no repo.
- Rotação de upload key exige processo no Play Console (App integrity).
- Não reutilize keystore entre apps diferentes.

## GitHub Actions
- Restringir quem pode disparar `workflow_dispatch` de release.
- (Opcional) usar ambientes (`environments`) com approvals para `production`.
- Nunca imprimir secrets em logs; evitar `set -x` e `echo` de env sensíveis.

## Hardening opcional (futuro)
- Substituir JSON key por **Workload Identity Federation** (reduz risco de vazamento de chave longa).
- Assinatura em KMS/HSM (quando aplicável).

