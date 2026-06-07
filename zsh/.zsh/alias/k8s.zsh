# k3d cluster creation helper with local registry mapping
k3d-create() {
    local cluster_name="${1:-dev-cluster}"
    echo "🚀 Creating k3d cluster '$cluster_name' with local Nexus registry configuration..."
    k3d cluster create "$cluster_name" \
        --api-port 6550 \
        -p "80:80@loadbalancer" \
        -p "443:443@loadbalancer" \
        --host-alias "host-gateway:nexus.local" \
        --registry-config "$HOME/.config/k3d/registries.yaml"
}

# Install ArgoCD to the active Kubernetes cluster
k8s-install-argocd() {
    echo "📦 Installing ArgoCD to the active Kubernetes cluster..."
    kubectl create namespace argocd || true
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    echo "⏳ Waiting for ArgoCD pods to be ready..."
    kubectl wait --namespace argocd --for=condition=ready pod --all --timeout=300s
    echo "🔑 To get initial admin password run:"
    echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d; echo"
}
