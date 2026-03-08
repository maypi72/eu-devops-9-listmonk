#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] === Instalación del stack de observabilidad con Helm ==="

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
NAMESPACE="${NAMESPACE:-observability}"
PROMETHEUS_VERSION="${PROMETHEUS_VERSION:-25.8.0}"
GRAFANA_VERSION="${GRAFANA_VERSION:-8.5.0}"
ALLOY_VERSION="${ALLOY_VERSION:-v1.0.0}"

# -----------------------------
# Instalación
# -----------------------------

gh_group "Añadiendo repositorios de Helm"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
gh_group_end

gh_group "Creando namespace $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
gh_group_end

gh_group "Instalando Prometheus"
helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace "$NAMESPACE" \
  --version "$PROMETHEUS_VERSION" \
  --set server.service.type=ClusterIP \
  --set alertmanager.enabled=false \
  --set pushgateway.enabled=false \
  --wait
gh_group_end

gh_group "Instalando Grafana"
helm upgrade --install grafana grafana/grafana \
  --namespace "$NAMESPACE" \
  --version "$GRAFANA_VERSION" \
  --set adminPassword='admin' \
  --set service.type=ClusterIP \
  --wait
gh_group_end

gh_group "Instalando Grafana Alloy"
helm upgrade --install alloy grafana/alloy \
  --namespace "$NAMESPACE" \
  --version "$ALLOY_VERSION" \
  --set alloy.config='prometheus.scrape "default" { targets = ["prometheus-server:80"] }' \
  --wait
gh_group_end

echo "[INFO] === Instalación completada ==="
echo "Prometheus: http://prometheus-server.$NAMESPACE.svc.cluster.local"
echo "Grafana: http://grafana.$NAMESPACE.svc.cluster.local (admin/admin)"
echo "Alloy: Configurado para scrapear Prometheus"