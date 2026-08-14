# -----------------------------------------------------------------------------
# AWS provider apontando para o MiniStack (emulador AWS local, porta 4566).
# Compatível com o padrão LocalStack: credentials falsas + skip de validações.
# A conta é resolvida via STS.GetCallerIdentity -> 000000000000 (miniStack).
# -----------------------------------------------------------------------------
provider "aws" {
  region                      = var.region
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = false
  s3_use_path_style           = true

  endpoints {
    sts            = var.ministack_endpoint
    iam            = var.ministack_endpoint
    ec2            = var.ministack_endpoint
    eks            = var.ministack_endpoint
    ecr            = var.ministack_endpoint
    kafka          = var.ministack_endpoint
    apigateway     = var.ministack_endpoint
    apigatewayv2   = var.ministack_endpoint
    elbv2          = var.ministack_endpoint
    sns            = var.ministack_endpoint
    sqs            = var.ministack_endpoint
    kms            = var.ministack_endpoint
    ssm            = var.ministack_endpoint
    lambda         = var.ministack_endpoint
    cloudwatch     = var.ministack_endpoint
    cloudwatchlogs = var.ministack_endpoint
    s3             = var.ministack_endpoint
  }

  default_tags {
    tags = local.tags
  }
}

# Providers kubernetes/helm leem o kubeconfig do k3s criado pelo módulo eks.
# Como o arquivo só existe após o primeiro apply (fase 1, addons_enabled=false),
# eles ficam inativos até a fase 2 — o provider só é configurado quando há
# recurso usando-o, e o module.addons tem count=0 na fase 1.
provider "kubernetes" {
  config_path = local.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = local.kubeconfig_path
  }
}
