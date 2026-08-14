output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_arn" {
  value = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  value = aws_eks_cluster.this.version
}

output "cluster_status" {
  value = aws_eks_cluster.this.status
}

output "cluster_created_at" {
  value = aws_eks_cluster.this.created_at
}

output "nodegroup_id" {
  value = aws_eks_node_group.this.id
}

output "nodegroup_status" {
  value = aws_eks_node_group.this.status
}

output "host_gateway_ip" {
  value = data.external.host_gateway.result["ip"]
}

output "container_name" {
  value = local.container_name
}
