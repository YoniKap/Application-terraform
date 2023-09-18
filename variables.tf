variable "project_name" {
  default = "Browntown"
  type    = string
}

variable "environment" {
  default = "dev"
  type    = string
}

variable "vpc_cidr" {
  default = "10.1.0.0/16"
  type    = string
}

variable "num_of_azs" {
  default = 3
  type    = number
}

variable "tags" {
  default = {
    Terraform = "true"
  }
}

variable "create_eks_cluster" {
  description = "Create EKS cluster or not"
  default     = true
  type        = bool
}
