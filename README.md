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
- `app.kv`: layout e navegação.
- `assets/`: logo/fonte (placeholder sem arquivo real).

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

## Publicação Play Store
1) Assine o release (`.apk` ou `.aab`) com keystore propria.
2) Faça upload no Google Play Console (app novo, preencha metadata e politicas).
3) Acompanhe reviews/testes internos antes de liberar em producao.

## Observacoes
- Atualize URLs e contatos reais em `contact_screen.py`.
- Adicione o arquivo real `assets/images/logo_placeholder.png` para icone/presplash.
