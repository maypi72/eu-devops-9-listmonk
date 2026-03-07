#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] === K3s Lab: Instalación NGINX Ingress (Calico Compatible) ==="

# -----------------------------
# Configuración y Rutas
# -----------------------------
# Forzamos KUBECONFIG para evitar el error x509 (unknown authority)
export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

# Parámetros Corregidos para la versión 4.10.1
INGRESS_NAMESPACE="${INGRESS_NAMESPACE:-ingress-nginx}"
INGRESS_CHART_VERSION="4.10.1"
HELM_REPO_NAME="ingress-nginx"
HELM_REPO_URL="https://kubernetes.github.io/ingress-nginx"
RELEASE_NAME="ingress-nginx"

# Helpers para GitHub Actions
gh_group() { [ -n "${GITHUB_ACTIONS:-}" ] && echo "::group::$*" || echo "[INFO] $*"; }
gh_group_end() { [ -n "${GITHUB_ACTIONS:-}" ] && echo "::endgroup::" || echo ""; }

# -----------------------------
# Pre-chequeos
# -----------------------------
gh_group "Pre-chequeos"

# 1. Permisos de KUBECONFIG
if [ ! -r "$KUBECONFIG" ]; then
    echo "[INFO] Ajustando permisos de Kubeconfig para el runner..."
    sudo chmod 644 "$KUBECONFIG"
fi

# 2. Herramientas
for cmd in kubectl helm curl; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "[ERROR] $cmd no encontrado"; exit 1; }
done

# 3. Conectividad (Verificando el archivo index.yaml real)
echo "[INFO] Verificando conectividad al repo Helm..."
if ! curl -IsfL "${HELM_REPO_URL}/index.yaml" >/dev/null; then
    echo "[ERROR] No se puede alcanzar el repositorio en $HELM_REPO_URL"
    exit 1
fi

# 4. Conexión al Cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "[ERROR] El runner no puede hablar con K3s. Revisa KUBECONFIG."
    exit 1
fi
gh_group_end

# -----------------------------
# Instalación con Helm
# -----------------------------
gh_group "Instalación de Ingress Controller"

echo "[INFO] Configurando repositorio $HELM_REPO_NAME..."
helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL" --force-update
helm repo update "$HELM_REPO_NAME"

# Crear namespace si no existe
kubectl create namespace "$INGRESS_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "[INFO] Ejecutando Helm Upgrade/Install (Versión $INGRESS_CHART_VERSION)..."
# Usamos HostPort para laboratorios sin LoadBalancer externo (MetalLB)
helm upgrade --install "$RELEASE_NAME" "$HELM_REPO_NAME/ingress-nginx" \
    --namespace "$INGRESS_NAMESPACE" \
    --version "$INGRESS_CHART_VERSION" \
    --set controller.kind=DaemonSet \
    --set controller.hostNetwork=true \
    --set controller.service.type=ClusterIP \
    --set controller.admissionWebhooks.enabled=false \
    --wait \
    --timeout 300s

gh_group_end

# -----------------------------
# Validación Final
# -----------------------------
gh_group "Validación de Estado"
echo "[INFO] Verificando pods en $INGRESS_NAMESPACE..."
kubectl get pods -n "$INGRESS_NAMESPACE" -o wide

if kubectl rollout status daemonset/"$RELEASE_NAME"-controller -n "$INGRESS_NAMESPACE" --timeout=60s; then
    echo "[SUCCESS] NGINX Ingress Controller está listo."
else
    echo "[ERROR] El despliegue falló o tardó demasiado."
    exit 1
fi
gh_group_end
