# App de teste (Fase 2): deploy no k3s + registro no target group default do ALB.
# Tudo via null_resource + kubectl/aws cli — mesmo padrão do módulo addons.
# Quando a Application do ArgoCD assumir o path k8s/app, o null_resource.apply sai.

locals {
  manifests_sha = sha1(join("", [for f in sort(fileset(var.manifests_dir, "*.yaml")) : file("${var.manifests_dir}/${f}")]))
}

resource "null_resource" "apply" {
  triggers = {
    manifests_sha      = local.manifests_sha
    cluster_created_at = var.cluster_created_at
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/apply.sh"

    environment = {
      KUBECONFIG    = var.kubeconfig_path
      MANIFESTS_DIR = var.manifests_dir
    }
  }
}

resource "null_resource" "register_targets" {
  triggers = {
    cluster_created_at = var.cluster_created_at
    tg_arn             = var.tg_arn
    node_port          = var.node_port
    manifests_sha      = local.manifests_sha
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/register_targets.sh"

    environment = {
      KUBECONFIG = var.kubeconfig_path
      TG_ARN     = var.tg_arn
      NODE_PORT  = var.node_port
      ENDPOINT   = var.endpoint
    }
  }

  depends_on = [null_resource.apply]
}
