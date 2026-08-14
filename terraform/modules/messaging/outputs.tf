output "topic_name" {
  value = aws_sns_topic.main.name
}

output "topic_arn" {
  value = aws_sns_topic.main.arn
}

output "queue_name" {
  value = aws_sqs_queue.main.name
}

output "queue_url" {
  value = aws_sqs_queue.main.id
}

output "queue_arn" {
  value = aws_sqs_queue.main.arn
}

output "dlq_url" {
  value = aws_sqs_queue.dlq.id
}

output "dlq_arn" {
  value = aws_sqs_queue.dlq.arn
}

output "subscription_arn" {
  value = aws_sns_topic_subscription.main.arn
}
