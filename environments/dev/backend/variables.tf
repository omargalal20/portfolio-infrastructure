variable "region" {
  description = "AWS Region"
  default     = "us-west-2"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  default     = "portfolio-infrastructure"
  type        = string
}

variable "env_name" {
  description = "The environment name of the project"
  default     = "dev"
  type        = string
}
