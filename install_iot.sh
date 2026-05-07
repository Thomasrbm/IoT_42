#!/usr/bin/env bash
# setup-iot.sh - Installe les outils IoT dans sgoinfre (sans sudo)

set -e

# ==== Config ====
SGOINFRE="/sgoinfre/goinfre/Perso/throbert"
BIN="$SGOINFRE/bin"
TMP="$SGOINFRE/tmp-install"

VAGRANT_VERSION="2.4.9"
K3D_VERSION="v5.7.4"
KUBECTL_VERSION="v1.31.0"
HELM_VERSION="v3.16.2"
ARGOCD_VERSION="v2.13.1"

# ==== Setup dirs ====
mkdir -p "$BIN" "$TMP"
mkdir -p "$SGOINFRE/.vagrant.d"
mkdir -p "$SGOINFRE/.VirtualBox"
cd "$TMP"

echo "=== Vagrant ==="
curl -LO "https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_linux_amd64.zip"
unzip -o "vagrant_${VAGRANT_VERSION}_linux_amd64.zip"
mv vagrant "$BIN/"
chmod +x "$BIN/vagrant"

echo "=== kubectl ==="
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
mv kubectl "$BIN/"
chmod +x "$BIN/kubectl"

echo "=== k3d ==="
curl -L "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-linux-amd64" -o "$BIN/k3d"
chmod +x "$BIN/k3d"

echo "=== Helm ==="
curl -LO "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
tar -xzf "helm-${HELM_VERSION}-linux-amd64.tar.gz"
mv linux-amd64/helm "$BIN/"
chmod +x "$BIN/helm"

echo "=== Argo CD CLI ==="
curl -L "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64" -o "$BIN/argocd"
chmod +x "$BIN/argocd"

# ==== Cleanup ====
cd "$HOME"
rm -rf "$TMP"

# ==== Setup PATH (idempotent) ====
SHELL_RC="$HOME/.bashrc"
[ -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.zshrc"

if ! grep -q "sgoinfre.*throbert/bin" "$SHELL_RC" 2>/dev/null; then
  cat >> "$SHELL_RC" <<EOF

# === IoT project (added by setup-iot.sh) ===
export PATH="$BIN:\$PATH"
export VAGRANT_HOME="$SGOINFRE/.vagrant.d"
export VBOX_USER_HOME="$SGOINFRE/.VirtualBox"
EOF
  echo "Added env vars to $SHELL_RC"
fi

echo ""
echo "=== Done. Installed binaries: ==="
ls -lh "$BIN"
echo ""
echo "Reload shell with: source $SHELL_RC"
echo "Then test: vagrant --version && kubectl version --client && k3d version"
