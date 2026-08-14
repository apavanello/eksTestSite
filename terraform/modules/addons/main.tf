resource "null_resource" "coredns_hosts" {
  triggers = {
    host_gateway_ip    = var.host_gateway_ip
    cluster_name       = var.cluster_name
    cluster_created_at = var.cluster_created_at
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      KUBE="--kubeconfig=${var.kubeconfig_path}"
      kubectl $KUBE -n kube-system patch configmap/coredns --type merge \
        -p '{"data":{"NodeHosts":"${var.host_gateway_ip} host.docker.internal\n"}}'
      kubectl $KUBE -n kube-system rollout restart deployment/coredns
    EOT
  }
}

resource "null_resource" "helm_repos" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
      helm repo update argo || true
    EOT
  }
}

resource "helm_release" "argocd" {
  count = var.argocd_enabled ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = true
  timeout          = 600

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  depends_on = [null_resource.coredns_hosts, null_resource.helm_repos]
}

resource "helm_release" "karpenter" {
  count = var.karpenter_enabled ? 1 : 0

  name             = "karpenter"
  repository       = var.karpenter_repository
  chart            = "karpenter"
  version          = var.karpenter_chart_version
  namespace        = var.karpenter_namespace
  create_namespace = true
  timeout          = 600
  cleanup_on_fail  = true

  # Karpenter v1.1.x: settings sao top-level (settings.clusterName -> env CLUSTER_NAME),
  # nao mais settings.aws.* como no v1.0.x. defaultInstanceProfile virou campo do NodeClass.
  # Provisioning emulado: controller aponta para o ministack via AWS_ENDPOINT_URL e
  # creds fake (qualquer valor valido, igual LocalStack). replicas=1 por ser single-node.
  values = [yamlencode({
    replicas = 1
    settings = merge(
      {
        clusterName     = var.cluster_name
        clusterEndpoint = var.cluster_endpoint
      },
      var.karpenter_interruption_queue != "" ? { interruptionQueue = var.karpenter_interruption_queue } : {}
    )
    controller = {
      env = [
        { name = "AWS_ENDPOINT_URL", value = var.in_cluster_aws_endpoint },
        { name = "AWS_REGION", value = var.region },
        { name = "AWS_DEFAULT_REGION", value = var.region },
        { name = "AWS_ACCESS_KEY_ID", value = "test" },
        { name = "AWS_SECRET_ACCESS_KEY", value = "test" },
      ]
    }
  })]

  depends_on = [null_resource.coredns_hosts]
}
