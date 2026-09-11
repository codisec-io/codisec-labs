#!/usr/bin/env sh
# Instalador da CLI codisec (Linux/macOS).
#
#   curl -sSL https://codisec.com.br/install.sh | bash
#
# Baixa o binário certo pra sua máquina de uma GitHub Release, confere
# o checksum SHA-256 publicado junto (ver docs/SECURITY.md) antes de
# instalar, e coloca no PATH. Não pede sudo — instala em
# $HOME/.local/bin por padrão.
set -eu

REPO="codisec-io/codisec-labs"
INSTALL_DIR="${CODISEC_INSTALL_DIR:-$HOME/.local/bin}"

fail() {
  echo "Erro: $1" >&2
  exit 1
}

command -v curl >/dev/null 2>&1 || fail "precisa de curl instalado."
command -v tar >/dev/null 2>&1 || fail "precisa de tar instalado."

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    fail "nem sha256sum nem shasum disponível — não consigo conferir o checksum."
  fi
}

os=$(uname -s)
arch=$(uname -m)

case "$os" in
  Linux) goos=linux ;;
  Darwin) goos=darwin ;;
  *) fail "sistema operacional não suportado: $os (use install.ps1 no Windows)" ;;
esac

case "$arch" in
  x86_64 | amd64) goarch=amd64 ;;
  arm64 | aarch64) goarch=arm64 ;;
  *) fail "arquitetura não suportada: $arch" ;;
esac

echo "Detectado: ${goos}/${goarch}"

api_url="https://api.github.com/repos/${REPO}/releases/latest"
echo "Consultando a última versão..."
release_json=$(curl -fsSL "$api_url") || fail "não consegui consultar ${api_url}"

version=$(printf '%s' "$release_json" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
[ -n "$version" ] || fail "não consegui determinar a versão mais recente — veja https://github.com/${REPO}/releases"
echo "Última versão: ${version}"

archive="codisec_${goos}_${goarch}.tar.gz"
base_url="https://github.com/${REPO}/releases/download/${version}"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT INT TERM

echo "Baixando ${archive}..."
curl -fsSL -o "$tmpdir/$archive" "${base_url}/${archive}" || fail "não consegui baixar ${archive}"
curl -fsSL -o "$tmpdir/checksums.txt" "${base_url}/checksums.txt" || fail "não consegui baixar checksums.txt"

echo "Conferindo checksum..."
expected=$(grep " ${archive}\$" "$tmpdir/checksums.txt" | awk '{print $1}')
[ -n "$expected" ] || fail "checksum de ${archive} não encontrado em checksums.txt — abortando, não é seguro instalar."

actual=$(cd "$tmpdir" && sha256_of "$archive")
[ "$expected" = "$actual" ] || fail "checksum não bate (esperado ${expected}, obtido ${actual}) — abortando, não é seguro instalar."
echo "Checksum ok."

mkdir -p "$INSTALL_DIR"
tar -xzf "$tmpdir/$archive" -C "$tmpdir"
[ -f "$tmpdir/codisec" ] || fail "o arquivo baixado não contém o binário codisec esperado."
mv "$tmpdir/codisec" "$INSTALL_DIR/codisec"
chmod +x "$INSTALL_DIR/codisec"

echo "✓ codisec instalado em ${INSTALL_DIR}/codisec"

case ":${PATH}:" in
  *":${INSTALL_DIR}:"*)
    # já está no PATH desta sessão, nada a fazer
    ;;
  *)
    shell_rc="$HOME/.profile"
    case "${SHELL:-}" in
      */zsh) shell_rc="$HOME/.zshrc" ;;
      */bash) shell_rc="$HOME/.bashrc" ;;
    esac
    line="export PATH=\"${INSTALL_DIR}:\$PATH\""
    if [ -f "$shell_rc" ] && grep -qF "$line" "$shell_rc" 2>/dev/null; then
      : # já foi adicionado numa instalação anterior
    else
      printf '\n# adicionado pelo instalador da CLI codisec\n%s\n' "$line" >> "$shell_rc"
      echo "Adicionado ${INSTALL_DIR} ao PATH em ${shell_rc}. Abra um novo terminal (ou rode: . ${shell_rc})."
    fi
    ;;
esac

echo ""
echo "Pronto! Teste com: codisec lab list"
echo "Pré-requisito pra rodar labs: Docker Desktop instalado e aberto."
