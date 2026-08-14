output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  value = aws_iam_role.eks_node.arn
}

output "eks_node_role_name" {
  value = aws_iam_role.eks_node.name
}

output "karpenter_controller_role_arn" {
  value = aws_iam_role.karpenter_controller.arn
}

output "karpenter_controller_role_name" {
  value = aws_iam_role.karpenter_controller.name
}

output "karpenter_node_role_arn" {
  value = aws_iam_role.karpenter_node.arn
}

output "karpenter_node_profile_name" {
  value = aws_iam_instance_profile.karpenter_node.name
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda_basic.arn
}
