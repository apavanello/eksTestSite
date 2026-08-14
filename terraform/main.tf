module "networking" {
  source = "./modules/networking"

  name_prefix   = local.prefix
  cluster_name  = local.cluster_name
  vpc_cidr      = var.vpc_cidr
  public_cidrs  = var.public_subnet_cidrs
  private_cidrs = var.private_subnet_cidrs
  environment   = local.environment
  common_tags   = local.tags
}

module "iam" {
  source = "./modules/iam"

  name_prefix = local.prefix
  common_tags = local.tags
}

module "kms" {
  source = "./modules/kms"

  name_prefix = local.prefix
  common_tags = local.tags
}

module "ssm" {
  source = "./modules/ssm"

  name_prefix = local.prefix
  kms_key_id  = module.kms.key_id
  common_tags = local.tags

  depends_on = [module.kms]
}

module "messaging" {
  source = "./modules/messaging"

  name_prefix = local.prefix
  common_tags = local.tags
}

module "ecr" {
  source = "./modules/ecr"

  name_prefix  = local.prefix
  repositories = var.ecr_repositories
  common_tags  = local.tags
}

module "kafka" {
  source = "./modules/kafka"

  name_prefix   = local.prefix
  cluster_name  = var.kafka_cluster_name
  kafka_version = var.kafka_version
  instance_type = var.kafka_instance_type
  subnet_ids    = module.networking.private_subnet_ids
  endpoint      = var.ministack_endpoint
  region        = var.region
  common_tags   = local.tags

  depends_on = [module.networking]
}

module "apigateway" {
  source = "./modules/apigateway"

  name_prefix     = local.prefix
  lambda_role_arn = module.iam.lambda_role_arn
  environment     = local.environment
  common_tags     = local.tags

  depends_on = [module.iam]
}

module "elb" {
  source = "./modules/elb"

  name_prefix        = local.prefix
  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.public_subnet_ids
  security_group_ids = [module.networking.alb_security_group_id]
  common_tags        = local.tags
  api_target_host    = module.apigateway.api_hostname

  depends_on = [module.networking]
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = local.cluster_name
  cluster_version    = var.cluster_version
  region             = var.region
  role_arn           = module.iam.eks_cluster_role_arn
  node_role_arn      = module.iam.eks_node_role_arn
  subnet_ids         = module.networking.private_subnet_ids
  security_group_ids = [module.networking.cluster_security_group_id]
  kubeconfig_path    = local.kubeconfig_path
  common_tags        = local.tags

  depends_on = [module.networking, module.iam]
}

module "addons" {
  count = var.addons_enabled ? 1 : 0

  source = "./modules/addons"

  cluster_name                 = local.cluster_name
  kubeconfig_path              = local.kubeconfig_path
  host_gateway_ip              = module.eks.host_gateway_ip
  cluster_created_at           = module.eks.cluster_created_at
  cluster_endpoint             = module.eks.cluster_endpoint
  in_cluster_aws_endpoint      = local.in_cluster_aws_endpoint
  region                       = var.region
  argocd_enabled               = var.argocd_enabled
  karpenter_enabled            = var.karpenter_enabled
  argocd_namespace             = var.argo_cd_namespace
  karpenter_namespace          = var.karpenter_namespace
  karpenter_controller_role    = module.iam.karpenter_controller_role_name
  karpenter_node_profile       = module.iam.karpenter_node_profile_name
  karpenter_interruption_queue = module.messaging.queue_name
  common_tags                  = local.tags

  depends_on = [module.eks, module.iam, module.messaging]
}
