# Security Notes (CI/CD + Play Store)

## Princípios
- Nunca commitar: keystore, senhas, JSON da service account, outputs (`bin/`, `.buildozer/`).
- Segredos somente via **GitHub Secrets** (ou equivalente no provedor de CI).
- Menor privilégio possível: service account com acesso apenas ao app necessário.

## Service Account (Google Play Developer API)
- Crie uma service account dedicada para este app.
- No Play Console, conceda apenas permissões necessárias para:
  - publicar em `internal` (e opcionalmente promover para `production`)
- Preferência: **Workload Identity Federation (WIF) + GitHub OIDC** (sem chave JSON longa).
  - Isso reduz muito o risco de vazamento de credenciais de longa duração.
- Fallback (se WIF não for possível): JSON da service account via `PLAY_SERVICE_ACCOUNT_JSON`.
  - Rotacione a chave JSON periodicamente:
    - crie uma nova key
    - atualize `PLAY_SERVICE_ACCOUNT_JSON` no GitHub
    - revogue a key antiga no Google Cloud

### Se você já baixou/armazenou JSON de service account no repo
Arquivos do tipo `appengenho-*.json` (ou similares) são **chaves privadas** e não devem ficar dentro do repositório (mesmo gitignored).

Se uma chave dessas já foi compartilhada por engano:
1. Revogue/rotacione a key no Google Cloud o quanto antes.
2. Remova o arquivo da árvore do repo e guarde em local seguro fora do projeto.
3. Se foi commitado em algum momento, considere reescrever o histórico (ex.: `git filter-repo`) e invalidar a chave.

## Upload Key / Keystore
- Guarde o `.jks` em cofre seguro (1Password/Vault/KMS), nunca no repo.
- Rotação de upload key exige processo no Play Console (App integrity).
- Não reutilize keystore entre apps diferentes.

## GitHub Actions
- Restringir quem pode disparar `workflow_dispatch` de release.
- (Opcional) usar ambientes (`environments`) com approvals para `production`.
- Nunca imprimir secrets em logs; evitar `set -x` e `echo` de env sensíveis.
- CI tem um guard-rail: `scripts/security_scan.py` falha se detectar `private_key` em JSON commitado.

## Hardening opcional (futuro)
- (Já suportado neste repo) Usar **Workload Identity Federation** (reduz risco de vazamento de chave longa).
- Assinatura em KMS/HSM (quando aplicável).
