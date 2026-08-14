resource "aws_ssm_parameter" "app_config" {
  name        = "/${var.name_prefix}/app/config"
  description = "Configuracao geral da aplicacao de teste"
  type        = "SecureString"
  key_id      = var.kms_key_id
  value = jsonencode({
    region          = "us-east-1"
    log_level       = "debug"
    feature_flags   = ["billing-v2", "dark-mode"]
    service_timeout = 30
  })

  tags = var.common_tags
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.name_prefix}/app/db/password"
  description = "Senha do banco de dados (apenas para testes)"
  type        = "SecureString"
  key_id      = var.kms_key_id
  value       = "test-password-change-me"

  tags = var.common_tags
}

resource "aws_ssm_parameter" "feature_flags" {
  name        = "/${var.name_prefix}/app/feature-flags"
  description = "Feature flags em formato texto plano"
  type        = "String"
  value = jsonencode({
    new_checkout = true
    beta_flow    = false
  })

  tags = var.common_tags
}
