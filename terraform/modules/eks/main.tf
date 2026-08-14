locals {
  container_name = "ministack-eks-${var.region}-${var.cluster_name}"
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.role_arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids             = var.subnet_ids
    security_group_ids     = var.security_group_ids
    endpoint_public_access = true
  }

  tags = var.common_tags
}

data "external" "host_gateway" {
  program = ["bash", "${path.module}/scripts/host_gateway.sh"]

  query = {
    container = local.container_name
  }

  depends_on = [aws_eks_cluster.this]
}

resource "null_resource" "kubeconfig" {
  triggers = {
    endpoint = aws_eks_cluster.this.endpoint
    arn      = aws_eks_cluster.this.arn
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      mkdir -p "$(dirname "${var.kubeconfig_path}")"
      container="${local.container_name}"
      for i in $(seq 1 60); do
        if docker exec "$container" sh -c 'test -f /etc/rancher/k3s/k3s.yaml' 2>/dev/null; then break; fi
        sleep 2
      done
      docker exec "$container" cat /etc/rancher/k3s/k3s.yaml \
        | sed "s|https://127.0.0.1:6443|${aws_eks_cluster.this.endpoint}|g" \
        > "${var.kubeconfig_path}"
      chmod 600 "${var.kubeconfig_path}"
    EOT
  }

  depends_on = [aws_eks_cluster.this]
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  ami_type        = "AL2_x86_64"
  capacity_type   = "ON_DEMAND"
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }

  tags = var.common_tags

  depends_on = [aws_eks_cluster.this]
}
