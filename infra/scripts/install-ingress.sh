#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] === Instalación de NGINX Ingress Controller ==="

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
INGRESS_NAMESPACE="${INGRESS_NAMESPACE:-ingress-nginx}"
INGRESS_CHART_VERSION="${INGRESS_CHART_VERSION:-4.10.1}"
HELM_REPO_NAME="${HELM_REPO_NAME:-nginx-stable}"
HELM_REPO_URL="${HELM_REPO_URL:-https://helm.nginx.com/stable}"
RELEASE_NAME="${RELEASE_NAME:-nginx-ingress}"
# Configuración para laboratorio: NodePort
SERVICE_TYPE="${SERVICE_TYPE:-NodePort}"
# Puertos NodePort (opcionales, Helm asigna automáticamente si no se especifican)
HTTP_NODEPORT="${HTTP_NODEPORT:-}"
HTTPS_NODEPORT="${HTTPS_NODEPORT:-}"
# IngressClass por defecto
DEFAULT_INGRESS_CLASS="${DEFAULT_INGRESS_CLASS:-true}"
INGRESS_CLASS_NAME="${INGRESS_CLASS_NAME:-nginx}"
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
# Instalar NGINX Ingress Controller
# -----------------------------
gh_group "Instalar NGINX Ingress Controller"
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
if helm list -n "$INGRESS_NAMESPACE" | grep -q "$RELEASE_NAME"; then
    echo "[INFO] NGINX Ingress Controller ya instalado en namespace $INGRESS_NAMESPACE"
else
    echo "[INFO] Instalando NGINX Ingress Controller versión $INGRESS_CHART_VERSION..."

    # Crear namespace si no existe
    kubectl create namespace "$INGRESS_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

    # Valores para la instalación
    VALUES_FILE=$(mktemp)
    cat > "$VALUES_FILE" <<EOF
controller:
  service:
    type: $SERVICE_TYPE
EOF

    # Añadir puertos NodePort si se especifican
    if [ -n "$HTTP_NODEPORT" ]; then
        cat >> "$VALUES_FILE" <<EOF
    nodePorts:
      http: $HTTP_NODEPORT
EOF
    fi
    if [ -n "$HTTPS_NODEPORT" ]; then
        cat >> "$VALUES_FILE" <<EOF
    nodePorts:
      https: $HTTPS_NODEPORT
EOF
    fi

    # Configurar IngressClass por defecto
    if [ "$DEFAULT_INGRESS_CLASS" = "true" ]; then
        cat >> "$VALUES_FILE" <<EOF
  ingressClassResource:
    default: true
    name: $INGRESS_CLASS_NAME
EOF
    fi

    # Instalar el chart
    helm install "$RELEASE_NAME" "$HELM_REPO_NAME/nginx-ingress" \
        --namespace "$INGRESS_NAMESPACE" \
        --version "$INGRESS_CHART_VERSION" \
        --values "$VALUES_FILE" \
        --wait \
        --timeout "${VALIDATION_TIMEOUT}s"

    # Limpiar archivo temporal
    rm -f "$VALUES_FILE"
fi
gh_group_end

# -----------------------------
# Validación de readiness
# -----------------------------
gh_group "Validación de readiness"
echo "[INFO] Validando readiness del NGINX Ingress Controller..."

# Esperar a que el deployment esté listo
if ! kubectl rollout status deployment/"$RELEASE_NAME"-controller \
    -n "$INGRESS_NAMESPACE" \
    --timeout="${VALIDATION_TIMEOUT}s"; then
    echo "[ERROR] El deployment no está listo tras ${VALIDATION_TIMEOUT}s"
    kubectl get pods -n "$INGRESS_NAMESPACE" -o wide
    exit 1
fi

# Verificar que el servicio esté creado y tenga endpoints
SERVICE_NAME="$RELEASE_NAME-controller"
if ! kubectl get service "$SERVICE_NAME" -n "$INGRESS_NAMESPACE" >/dev/null 2>&1; then
    echo "[ERROR] Servicio $SERVICE_NAME no encontrado"
    exit 1
fi

# Mostrar información del servicio
echo "[INFO] Información del servicio NGINX Ingress:"
kubectl get service "$SERVICE_NAME" -n "$INGRESS_NAMESPACE" -o wide

# Verificar IngressClass
if [ "$DEFAULT_INGRESS_CLASS" = "true" ]; then
    if kubectl get ingressclass "$INGRESS_CLASS_NAME" >/dev/null 2>&1; then
        echo "[INFO] IngressClass '$INGRESS_CLASS_NAME' configurado como por defecto"
        kubectl get ingressclass "$INGRESS_CLASS_NAME"
    else
        echo "[WARN] IngressClass '$INGRESS_CLASS_NAME' no encontrado"
    fi
fi

echo "[INFO] NGINX Ingress Controller instalado y listo."
gh_group_end