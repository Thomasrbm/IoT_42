#!/usr/bin/env bash
# setup-iot.sh - Installe les outils IoT dans sgoinfre + configure VirtualBox
# Usage : ./setup-iot.sh
# Idempotent : peut être relancé sans casser l'existant

set -e

# ==== Config ====
SGOINFRE="/sgoinfre/goinfre/Perso/$(whoami)"
BIN="$SGOINFRE/bin"
TMP="$SGOINFRE/tmp-install"

VAGRANT_VERSION="2.4.9"
K3D_VERSION="v5.7.4"
KUBECTL_VERSION="v1.31.0"
HELM_VERSION="v3.16.2"
ARGOCD_VERSION="v2.13.1"

echo "============================================"
echo " IoT setup script — installs tools in sgoinfre"
echo "============================================"
echo ""

# ==== Setup dirs ====
mkdir -p "$BIN" "$TMP"
mkdir -p "$SGOINFRE/.vagrant.d"
mkdir -p "$SGOINFRE/.VirtualBox"
mkdir -p "$SGOINFRE/VirtualBox_VMs"
cd "$TMP"

# ==== Outils CLI ====
echo "=== Vagrant ==="
if [ ! -f "$BIN/vagrant" ] || [ "$1" = "--force" ]; then
  curl -LO "https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_linux_amd64.zip"
  unzip -o "vagrant_${VAGRANT_VERSION}_linux_amd64.zip"
  mv vagrant "$BIN/"
  chmod +x "$BIN/vagrant"
else
  echo "  → already installed, skipping (use --force to reinstall)"
fi

echo "=== kubectl ==="
if [ ! -f "$BIN/kubectl" ] || [ "$1" = "--force" ]; then
  curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  mv kubectl "$BIN/"
  chmod +x "$BIN/kubectl"
else
  echo "  → already installed, skipping"
fi

echo "=== k3d ==="
if [ ! -f "$BIN/k3d" ] || [ "$1" = "--force" ]; then
  curl -L "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-linux-amd64" -o "$BIN/k3d"
  chmod +x "$BIN/k3d"
else
  echo "  → already installed, skipping"
fi

echo "=== Helm ==="
if [ ! -f "$BIN/helm" ] || [ "$1" = "--force" ]; then
  curl -LO "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
  tar -xzf "helm-${HELM_VERSION}-linux-amd64.tar.gz"
  mv linux-amd64/helm "$BIN/"
  chmod +x "$BIN/helm"
else
  echo "  → already installed, skipping"
fi

echo "=== Argo CD CLI ==="
if [ ! -f "$BIN/argocd" ] || [ "$1" = "--force" ]; then
  curl -L "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64" -o "$BIN/argocd"
  chmod +x "$BIN/argocd"
else
  echo "  → already installed, skipping"
fi

# ==== VirtualBox machinefolder (CRITIQUE) ====
echo ""
echo "=== Configuring VirtualBox machinefolder ==="
if command -v VBoxManage >/dev/null 2>&1; then
  CURRENT_FOLDER=$(VBoxManage list systemproperties 2>/dev/null | grep "Default machine folder" | awk -F: '{print $2}' | xargs)
  TARGET_FOLDER="$SGOINFRE/VirtualBox_VMs"
  
  if [ "$CURRENT_FOLDER" != "$TARGET_FOLDER" ]; then
    VBoxManage setproperty machinefolder "$TARGET_FOLDER"
    echo "  → set to $TARGET_FOLDER"
  else
    echo "  → already set to $TARGET_FOLDER"
  fi
else
  echo "  → VBoxManage not found (VirtualBox not installed?), skipping"
fi

# ==== Cleanup ====
cd "$HOME"
rm -rf "$TMP"

# ==== Setup PATH + env vars dans le shell rc ====
SHELL_RC="$HOME/.bashrc"
[ -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.zshrc"

if ! grep -q "IoT project" "$SHELL_RC" 2>/dev/null; then
  cat >> "$SHELL_RC" <<EOF

# === IoT project (added by setup-iot.sh) ===
export PATH="$BIN:\$PATH"
export VAGRANT_HOME="$SGOINFRE/.vagrant.d"
export VBOX_USER_HOME="$SGOINFRE/.VirtualBox"
EOF
  echo ""
  echo "→ Added env vars to $SHELL_RC"
else
  echo ""
  echo "→ Env vars already in $SHELL_RC, skipping"
fi

# ==== Final ====
echo ""
echo "============================================"
echo " ✅ Done"
echo "============================================"
echo ""
echo "Installed binaries:"
ls -lh "$BIN"
echo ""
echo "VirtualBox machinefolder:"
VBoxManage list systemproperties 2>/dev/null | grep "Default machine folder" || echo "  (VBox not available)"
echo ""
echo "Next steps:"
echo "  1. Reload your shell: source $SHELL_RC"
echo "  2. Test: vagrant --version && kubectl version --client"
echo "  3. cd $SGOINFRE/IoT_42/p1 && vagrant up"