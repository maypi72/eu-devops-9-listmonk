#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] === Instalación de cert-manager con self-signing ==="

# Forzamos KUBECONFIG para evitar el error x509 (unknown authority)
export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

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
CERT_MANAGER_NAMESPACE="${CERT_MANAGER_NAMESPACE:-cert-manager}"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.14.5}"
HELM_REPO_NAME="${HELM_REPO_NAME:-jetstack}"
HELM_REPO_URL="${HELM_REPO_URL:-https://charts.jetstack.io}"
RELEASE_NAME="${RELEASE_NAME:-cert-manager}"
# Configuración para self-signing
DOMAIN="${DOMAIN:-listmonk.local}"
CLUSTER_ISSUER_NAME="${CLUSTER_ISSUER_NAME:-selfsigned-issuer}"
CERTIFICATE_NAME="${CERTIFICATE_NAME:-listmonk-tls}"
# Timeout para validaciones
VALIDATION_TIMEOUT="${VALIDATION_TIMEOUT:-300}"

# -----------------------------
# Pre-chequeos básicos
# -----------------------------
gh_group "Pre-chequeos"
echo "[INFO] Verificando herramientas necesarias..."
for cmd in kubectl helm curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[ERROR] '$cmd' no encontrado. Asegúrate de que k3s y Helm estén instalados."
        exit 1
    fi
done

# Verificar conectividad al repo de Helm
if ! curl -sfL "$HELM_REPO_URL/index.yaml" >/dev/null; then
  echo "[ERROR] No hay conectividad al repo de Helm: $HELM_REPO_URL"
  exit 1
fi

# Verificar que el cluster esté listo
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "[ERROR] El cluster de Kubernetes no está accesible."
  exit 1
fi
gh_group_end

# -----------------------------
# Instalar cert-manager
# -----------------------------
gh_group "Instalar cert-manager"
# Añadir repo si no existe
if ! helm repo list | grep -q "$HELM_REPO_NAME"; then
    echo "[INFO] Añadiendo repo de Helm: $HELM_REPO_NAME"
    helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL"
else
    echo "[INFO] Repo $HELM_REPO_NAME ya añadido"
fi

# Actualizar repos
helm repo update

# Verificar si ya está instalado
if helm list -n "$CERT_MANAGER_NAMESPACE" | grep -q "$RELEASE_NAME"; then
    echo "[INFO] cert-manager ya instalado en namespace $CERT_MANAGER_NAMESPACE"
else
    echo "[INFO] Instalando cert-manager versión $CERT_MANAGER_VERSION..."

    # Crear namespace si no existe
    kubectl create namespace "$CERT_MANAGER_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

    # Instalar cert-manager con CRDs
    helm install "$RELEASE_NAME" "$HELM_REPO_NAME/cert-manager" \
        --namespace "$CERT_MANAGER_NAMESPACE" \
        --version "$CERT_MANAGER_VERSION" \
        --set installCRDs=true \
        --wait \
        --timeout "${VALIDATION_TIMEOUT}s"
fi
gh_group_end

# -----------------------------
# Configurar ClusterIssuer para self-signing
# -----------------------------
gh_group "Configurar ClusterIssuer self-signed"
CLUSTER_ISSUER_YAML=$(mktemp)
cat > "$CLUSTER_ISSUER_YAML" <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: $CLUSTER_ISSUER_NAME
spec:
  selfSigned: {}
EOF

if kubectl get clusterissuer "$CLUSTER_ISSUER_NAME" >/dev/null 2>&1; then
    echo "[INFO] ClusterIssuer '$CLUSTER_ISSUER_NAME' ya existe"
else
    echo "[INFO] Creando ClusterIssuer self-signed..."
    kubectl apply -f "$CLUSTER_ISSUER_YAML"
fi
rm -f "$CLUSTER_ISSUER_YAML"
gh_group_end

# -----------------------------
# Crear Certificate para listmonk.local
# -----------------------------
gh_group "Crear Certificate para $DOMAIN"
CERTIFICATE_YAML=$(mktemp)
cat > "$CERTIFICATE_YAML" <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: $CERTIFICATE_NAME
  namespace: default  # Cambia si tu app está en otro namespace
spec:
  secretName: $CERTIFICATE_NAME-secret
  issuerRef:
    name: $CLUSTER_ISSUER_NAME
    kind: ClusterIssuer
  dnsNames:
  - $DOMAIN
EOF

if kubectl get certificate "$CERTIFICATE_NAME" -n default >/dev/null 2>&1; then
    echo "[INFO] Certificate '$CERTIFICATE_NAME' ya existe"
else
    echo "[INFO] Creando Certificate para $DOMAIN..."
    kubectl apply -f "$CERTIFICATE_YAML"
fi
rm -f "$CERTIFICATE_YAML"
gh_group_end

# -----------------------------
# Validación de readiness y emisión
# -----------------------------
gh_group "Validación de cert-manager y certificado"
echo "[INFO] Validando readiness de cert-manager..."

# Esperar a que cert-manager esté listo
kubectl wait --for=condition=available --timeout="${VALIDATION_TIMEOUT}s" deployment -n "$CERT_MANAGER_NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME"

# Esperar a que el certificado se emita
echo "[INFO] Esperando emisión del certificado para $DOMAIN..."
kubectl wait --for=condition=ready --timeout="${VALIDATION_TIMEOUT}s" certificate "$CERTIFICATE_NAME" -n default

# Verificar el secreto del certificado
if kubectl get secret "$CERTIFICATE_NAME-secret" -n default >/dev/null 2>&1; then
    echo "[INFO] Certificado emitido correctamente. Secreto '$CERTIFICATE_NAME-secret' creado."
    kubectl get certificate "$CERTIFICATE_NAME" -n default
else
    echo "[ERROR] El secreto del certificado no se creó"
    kubectl describe certificate "$CERTIFICATE_NAME" -n default
    exit 1
fi

echo "[INFO] cert-manager instalado y certificado TLS listo para $DOMAIN."
gh_group_end