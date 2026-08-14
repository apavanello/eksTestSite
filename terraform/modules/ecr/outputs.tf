output "repository_urls" {
  value = {
    for repo in aws_ecr_repository.this : repo.name => repo.repository_url
  }
}

output "repository_names" {
  value = values(aws_ecr_repository.this)[*].name
}

output "repository_arns" {
  value = values(aws_ecr_repository.this)[*].arn
}
