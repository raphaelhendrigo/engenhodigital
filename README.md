# Engenho Digital App

Aplicativo mobile em Python/Kivy para apresentar a Engenho Digital (Projetos & Sistemas). Estrutura preparada para empacotamento Android via Buildozer.

## Requisitos
- Python 3.10+
- Kivy (ver `requirements.txt`)
- Buildozer em ambiente Linux/WSL para gerar APK/AAB

## Ambiente local
1) Crie o ambiente virtual:
```bash
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
```
2) Instale as dependencias:
```bash
pip install --upgrade pip
pip install -r requirements.txt
```
3) Rode o app:
```bash
python main.py
```

## Estrutura
- `main.py`: ponto de entrada.
- `engdigital/`: pacote da aplicacao.
  - `app.py`: classe `EngenhoDigitalApp` e carga do KV.
  - `screens/`: telas Home, Servicos e Contato.
- `engdigital/config.py`: dados de contato e links (atualize antes de publicar).
- `app.kv`: layout e navegação.
- `assets/`: imagens do app e materiais da Play Store.
- `scripts/generate_assets.py`: gera ícone, presplash e artes iniciais.

## Build Android (Linux/WSL)
1) Instale o Buildozer (fora do venv ou em um dedicado):
```bash
pip install --user buildozer
```
2) Inicialize e confirme dependencias do sistema (SDK/NDK/Java via buildozer):
```bash
buildozer android debug  # primeira execucao baixa toolchain
```
3) Geração:
- Debug APK: `buildozer -v android debug`
- Release APK: `buildozer android release` (assinar depois)
- AAB (Play Store): `buildozer android release aab`

## Build via GitHub Actions
- Veja `docs/RELEASE_PLAYSTORE.md` (e `CI_BUILD.md`) para release automatizado e publicação no Google Play.

## Publicação Play Store
1) Assine o release (`.apk` ou `.aab`) com keystore propria.
2) Faça upload no Google Play Console (app novo, preencha metadata e politicas).
3) Acompanhe reviews/testes internos antes de liberar em producao.

### Publicação automática (CI/CD)
- O workflow **Android Release (Play Store)** publica automaticamente no Play Console.
- Automático por tag: crie e faça push de uma tag `vX.Y.Z` (ex.: `v1.2.3`) para publicar no track `internal`.
- Para publicar em outro track (`closed`/`open`/`production`) e/ou promover para production, use o `workflow_dispatch` conforme `docs/RELEASE_PLAYSTORE.md`.

## Observacoes
- Atualize URLs e contatos reais em `engdigital/config.py`.
- Execute `python3 scripts/generate_assets.py` para gerar os assets iniciais.
