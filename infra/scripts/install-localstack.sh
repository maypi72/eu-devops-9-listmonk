#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] === Instalación de LocalStack con Helm ==="

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
LOCALSTACK_NAMESPACE="${LOCALSTACK_NAMESPACE:-localstack}"
LOCALSTACK_VERSION="${LOCALSTACK_VERSION:-0.6.27}"
HELM_REPO_NAME="${HELM_REPO_NAME:-localstack}"
HELM_REPO_URL="${HELM_REPO_URL:-https://helm.localstack.cloud}"
RELEASE_NAME="${RELEASE_NAME:-localstack}"
# Servicios AWS a habilitar
SERVICES="${SERVICES:-s3,ecr,secretsmanager}"
# Configuración para Terraform
S3_BUCKET_NAME="${S3_BUCKET_NAME:-terraform-state-bucket}"
LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
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
# Instalar AWS CLI si no está
# -----------------------------
gh_group "Instalar AWS CLI"
if command -v aws >/dev/null 2>&1; then
    echo "[INFO] AWS CLI ya instalado"
else
    echo "[INFO] Instalando AWS CLI..."
    # Instalar AWS CLI v2
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
fi

# Configurar AWS CLI para usar LocalStack
export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_ENDPOINT_URL="$LOCALSTACK_ENDPOINT"
gh_group_end

# -----------------------------
# Instalar LocalStack
# -----------------------------
gh_group "Instalar LocalStack"
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
if helm list -n "$LOCALSTACK_NAMESPACE" | grep -q "$RELEASE_NAME"; then
    echo "[INFO] LocalStack ya instalado en namespace $LOCALSTACK_NAMESPACE"
else
    echo "[INFO] Instalando LocalStack versión $LOCALSTACK_VERSION..."

    # Crear namespace si no existe
    kubectl create namespace "$LOCALSTACK_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

    # Instalar LocalStack con servicios específicos
    helm install "$RELEASE_NAME" "$HELM_REPO_NAME/localstack" \
        --namespace "$LOCALSTACK_NAMESPACE" \
        --version "$LOCALSTACK_VERSION" \
        --set startServices="$SERVICES" \
        --set persistence.enabled=true \
        --set persistence.size=1Gi \
        --wait \
        --timeout "${VALIDATION_TIMEOUT}s"
fi
gh_group_end

# -----------------------------
# Esperar a que LocalStack esté listo
# -----------------------------
gh_group "Esperar readiness de LocalStack"
echo "[INFO] Esperando a que LocalStack esté listo..."

# Obtener el puerto del servicio
LOCALSTACK_PORT=$(kubectl get svc "$RELEASE_NAME" -n "$LOCALSTACK_NAMESPACE" -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
if [ -z "$LOCALSTACK_PORT" ]; then
    echo "[ERROR] No se pudo obtener el puerto de LocalStack"
    exit 1
fi

# Actualizar endpoint si es necesario
LOCALSTACK_ENDPOINT="http://localhost:$LOCALSTACK_PORT"

# Esperar a que responda
timeout "$VALIDATION_TIMEOUT" bash -c 'until curl -sf "$LOCALSTACK_ENDPOINT/_localstack/health" >/dev/null; do sleep 5; done' || {
  echo "[ERROR] LocalStack no respondió en ${VALIDATION_TIMEOUT}s"
  kubectl logs -n "$LOCALSTACK_NAMESPACE" deployment/"$RELEASE_NAME" --tail=50
  exit 1
}
gh_group_end

# -----------------------------
# Crear bucket S3 para Terraform
# -----------------------------
gh_group "Crear bucket S3 para Terraform"
echo "[INFO] Creando bucket S3 '$S3_BUCKET_NAME'..."

# Configurar AWS CLI con el endpoint actualizado
export AWS_ENDPOINT_URL="$LOCALSTACK_ENDPOINT"

# Crear bucket si no existe
if aws s3 ls "s3://$S3_BUCKET_NAME" >/dev/null 2>&1; then
    echo "[INFO] Bucket '$S3_BUCKET_NAME' ya existe"
else
    aws s3 mb "s3://$S3_BUCKET_NAME"
    echo "[INFO] Bucket '$S3_BUCKET_NAME' creado"
fi

# Verificar bucket
aws s3 ls "s3://$S3_BUCKET_NAME"
gh_group_end

# -----------------------------
# Validación final
# -----------------------------
gh_group "Validación final"
echo "[INFO] Validando servicios de LocalStack..."

# Verificar S3
if aws s3 ls >/dev/null 2>&1; then
    echo "[INFO] S3 funcionando correctamente"
else
    echo "[ERROR] S3 no disponible"
    exit 1
fi

# Verificar ECR (si habilitado)
if echo "$SERVICES" | grep -q "ecr"; then
    if aws ecr describe-repositories >/dev/null 2>&1; then
        echo "[INFO] ECR funcionando correctamente"
    else
        echo "[WARN] ECR no disponible (puede que no esté inicializado aún)"
    fi
fi

# Verificar Secrets Manager (si habilitado)
if echo "$SERVICES" | grep -q "secretsmanager"; then
    if aws secretsmanager list-secrets >/dev/null 2>&1; then
        echo "[INFO] Secrets Manager funcionando correctamente"
    else
        echo "[WARN] Secrets Manager no disponible (puede que no esté inicializado aún)"
    fi
fi

echo "[INFO] LocalStack instalado y listo. Bucket S3 '$S3_BUCKET_NAME' creado."
echo "[INFO] Endpoint: $LOCALSTACK_ENDPOINT"
echo "[INFO] Configura Terraform con:"
echo "  backend \"s3\" {"
echo "    bucket = \"$S3_BUCKET_NAME\""
echo "    key    = \"terraform.tfstate\""
echo "    region = \"$AWS_REGION\""
echo "    endpoint = \"$LOCALSTACK_ENDPOINT\""
echo "    skip_credentials_validation = true"
echo "    skip_metadata_api_check = true"
echo "  }"
gh_group_end