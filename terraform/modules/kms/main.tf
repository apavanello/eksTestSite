resource "aws_kms_key" "main" {
  description             = "Chave KMS principal do ambiente de testes"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = var.common_tags
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.name_prefix}-main"
  target_key_id = aws_kms_key.main.key_id
}

resource "aws_kms_key" "ssm" {
  description             = "Chave KMS para o Parameter Store"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = var.common_tags
}

resource "aws_kms_alias" "ssm" {
  name          = "alias/${var.name_prefix}-ssm"
  target_key_id = aws_kms_key.ssm.key_id
}
