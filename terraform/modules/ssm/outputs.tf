output "app_config_arn" {
  value = aws_ssm_parameter.app_config.arn
}

output "db_password_arn" {
  value = aws_ssm_parameter.db_password.arn
}

output "feature_flags_arn" {
  value = aws_ssm_parameter.feature_flags.arn
}
