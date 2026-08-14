output "key_id" {
  value = aws_kms_key.main.key_id
}

output "key_arn" {
  value = aws_kms_key.main.arn
}

output "ssm_key_id" {
  value = aws_kms_key.ssm.key_id
}

output "ssm_key_arn" {
  value = aws_kms_key.ssm.arn
}
