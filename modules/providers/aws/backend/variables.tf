variable "vpc" {
  type = any
}

variable "region" {
  description = "AWS Region"
  type        = string
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
  description = "The namespace of the project"
  type        = string
}

variable "functionality" {
  description = "The functionality of the ec2 instance"
  type        = string
}

variable "instance_type" {
  description = "The instance type of the ec2 instance"
  type        = string
}

variable "key_name" {
  description = "The key name of the ec2 instance"
  type        = string
}

variable "key_pair_file_path" {
  description = "The key pair file path of the ec2 instance"
  type        = string
}

variable "iam_role_name" {
  description = "The iam role name of the ec2 instance"
  type        = string
}

variable "security_group_id" {
  description = "The security group id of the ec2 instance"
  type        = string
}
