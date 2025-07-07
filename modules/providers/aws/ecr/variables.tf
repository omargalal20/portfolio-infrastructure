variable "vpc" {
  type = any
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "env_name" {
  description = "The environment name of the project"
  type        = string
}

variable "namespace" {
  type = string
}

variable "name" {
  type = string
}