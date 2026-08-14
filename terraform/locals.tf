locals {
  prefix       = var.resource_prefix
  cluster_name = var.cluster_name
  environment  = var.environment

  # Caminho do kubeconfig gerado a partir do cluster k3s criado pelo MiniStack.
  kubeconfig_path = abspath("${path.root}/.kube/${var.cluster_name}.yaml")

  # Endpoint que os pods (dentro do k3s) usam para alcançar o MiniStack no host.
  # O gateway do bridge docker é descoberto em runtime pelo módulo eks.
  in_cluster_aws_endpoint = "http://host.docker.internal:4566"

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Stack       = "eks-test-site"
  }
}
