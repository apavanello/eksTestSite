output "cluster" {
  description = "Dados do cluster EKS"
  value = {
    name      = module.eks.cluster_name
    arn       = module.eks.cluster_arn
    endpoint  = module.eks.cluster_endpoint
    version   = module.eks.cluster_version
    status    = module.eks.cluster_status
    nodegroup = module.eks.nodegroup_id
  }
}

output "kubeconfig_path" {
  description = "Caminho do kubeconfig gerado (k3s real do MiniStack)"
  value       = local.kubeconfig_path
}

output "networking" {
  description = "IDs da rede emulada"
  value = {
    vpc_id          = module.networking.vpc_id
    private_subnets = module.networking.private_subnet_ids
    public_subnets  = module.networking.public_subnet_ids
  }
}

output "iam" {
  description = "Roles IAM emuladas"
  value = {
    eks_cluster_role       = module.iam.eks_cluster_role_arn
    eks_node_role          = module.iam.eks_node_role_arn
    karpenter_controller   = module.iam.karpenter_controller_role_arn
    karpenter_node_profile = module.iam.karpenter_node_profile_name
    lambda_role            = module.iam.lambda_role_arn
  }
}

output "ecr" {
  description = "Repositórios ECR"
  value       = module.ecr.repository_urls
}

output "kafka" {
  description = "Cluster MSK (Kafka) — bootstrap aponta para o Redpanda via host.docker.internal"
  value = {
    cluster_name      = module.kafka.cluster_name
    cluster_arn       = module.kafka.cluster_arn
    bootstrap_brokers = module.kafka.bootstrap_brokers
    bootstrap_tls     = module.kafka.bootstrap_brokers_tls
  }
}

output "messaging" {
  description = "Tópicos SNS e filas SQS"
  value = {
    topic_arn        = module.messaging.topic_arn
    queue_url        = module.messaging.queue_url
    queue_arn        = module.messaging.queue_arn
    dlq_url          = module.messaging.dlq_url
    subscription_arn = module.messaging.subscription_arn
  }
}

output "kms" {
  description = "Chave KMS"
  value = {
    key_id  = module.kms.key_id
    key_arn = module.kms.key_arn
  }
}

output "ssm" {
  description = "Parâmetros do Parameter Store"
  value = {
    app_config_arn    = module.ssm.app_config_arn
    db_password_arn   = module.ssm.db_password_arn
    feature_flags_arn = module.ssm.feature_flags_arn
  }
}

output "apigateway" {
  description = "API Gateway REST"
  value = {
    api_id      = module.apigateway.rest_api_id
    api_arn     = module.apigateway.rest_api_arn
    invoke_url  = module.apigateway.invoke_url
    lambda_name = module.apigateway.lambda_function_name
  }
}

output "elb" {
  description = "Application Load Balancer"
  value = {
    lb_arn       = module.elb.lb_arn
    lb_dns_name  = module.elb.lb_dns_name
    target_group = module.elb.target_group_arn
  }
}

output "addons" {
  description = "Add-ons instalados no EKS"
  value = {
    argocd_namespace    = try(module.addons[0].argocd_namespace, null)
    karpenter_namespace = try(module.addons[0].karpenter_namespace, null)
    host_gateway_ip     = module.eks.host_gateway_ip
  }
}
