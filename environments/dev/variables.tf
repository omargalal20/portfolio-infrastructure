variable "region" {
  description = "AWS Region"
  default     = "us-west-2"
  type        = string
}

variable "profile" {
  description = "The AWS CLI profile of the project"
  default     = "portfolio"
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


# --- Secrets ---

variable "BACKEND_KEY_PAIR_PATH" {
  description = "The local key pair path needed to store the Backend Instance SSH key"
  type        = string
}