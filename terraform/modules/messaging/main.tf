resource "aws_sns_topic" "main" {
  name = "${var.name_prefix}-events"

  tags = var.common_tags
}

resource "aws_sqs_queue" "main" {
  name = "${var.name_prefix}-queue"

  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400
  delay_seconds              = 0

  tags = var.common_tags
}

resource "aws_sqs_queue" "dlq" {
  name = "${var.name_prefix}-dlq"

  message_retention_seconds = 1209600

  tags = var.common_tags
}

resource "aws_sqs_queue_policy" "main" {
  queue_url = aws_sqs_queue.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.main.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.main.arn
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "main" {
  topic_arn = aws_sns_topic.main.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.main.arn
}
