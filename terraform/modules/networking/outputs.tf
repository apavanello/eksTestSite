output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "cluster_security_group_id" {
  value = aws_security_group.cluster.id
}

output "nodes_security_group_id" {
  value = aws_security_group.nodes.id
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}
