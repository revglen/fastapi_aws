variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Used to name the ECS cluster, service, ECR repo, ALB, etc."
  type        = string
  default     = "fastapi-cicd"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "container_port" {
  description = "Port the FastAPI app listens on inside the container"
  type        = number
  default     = 8000
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Fargate task memory in MB"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Number of ECS tasks"
  type        = number
  default     = 1
}

variable "image_tag" {
  description = "Image tag used for the FIRST deploy only. After that, Jenkins updates the running task definition directly and terraform ignores further changes to it, see the lifecycle block on aws_ecs_service."
  type        = string
  default     = "latest"
}