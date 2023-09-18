terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.22"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
  }
}

#in order to auth with aws and enables to interact with the cloud in a declarative way
provider "aws" {
  region = "eu-central-1"
}

data "aws_eks_cluster_auth" "cluster" {
  count      = var.create_eks_cluster ? 1 : 0
  name       = module.eks[0].cluster_name
  depends_on = [module.eks[0].cluster_arn]
}

provider "kubernetes" {
  host                   = module.eks[0].cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks[0].cluster_certificate_authority_data) 
  token                  = try(data.aws_eks_cluster_auth.cluster[0].token, "")
}

provider "helm" {
  kubernetes {
    host                   = module.eks[0].cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks[0].cluster_certificate_authority_data)
    token                  = try(data.aws_eks_cluster_auth.cluster[0].token, "")
  }
}

# provider "argocd" {
#   host                   = module.eks[0].cluster_endpoint
#   cluster_ca_certificate = base64decode(module.eks[0].cluster_certificate_authority_data) 
#   token                  = try(data.aws_eks_cluster_auth.cluster[0].token, "")
# }

# resource "argocd_application" "notes-argo-application" {
# }