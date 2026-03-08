#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] === Instalación de ArgoCD con Helm ==="

# -----------------------------
# Configuración y Entorno
# -----------------------------

# Forzamos KUBECONFIG para evitar el error x509 (unknown authority)
export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
if [ ! -r "$KUBECONFIG" ]; then sudo chmod 644 "$KUBECONFIG"; fi

# helpers para GitHub Actions (grupos plegables)
gh_group() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::group::$*"
  else
    echo "[INFO] $*"
  fi
}

gh_group_end() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::endgroup::"
  fi
}

# -----------------------------
# Parámetros/flags (ajustables por env)
# -----------------------------
NAMESPACE="${NAMESPACE:-argocd}"
ARGOCD_VERSION="${ARGOCD_VERSION:-7.3.0}"

# -----------------------------
# Instalación
# -----------------------------

gh_group "Añadiendo repositorio de ArgoCD Helm"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
gh_group_end

gh_group "Creando namespace $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
gh_group_end

gh_group "Instalando ArgoCD"
helm upgrade --install argocd argo/argo-cd \
  --namespace "$NAMESPACE" \
  --version "$ARGOCD_VERSION" \
  --set server.service.type=ClusterIP \
  --set server.ingress.enabled=true \
  --set server.ingress.hosts[0]=argocd.local \
  --set server.ingress.tls[0].secretName=argocd-tls \
  --set server.ingress.tls[0].hosts[0]=argocd.local \
  --wait
gh_group_end

echo "[INFO] === Instalación completada ==="
echo "ArgoCD Server: https://argocd.local"
echo "Usuario inicial: admin"
echo "Contraseña inicial: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"