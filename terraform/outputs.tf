output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "alb_dns_name" {
  description = "Visit this URL to reach the running app"
  value       = aws_lb.app.dns_name
}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}