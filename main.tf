locals {
  name            = "${var.project_name}-${var.environment}-eks"
  cluster_version = "1.27"
  tags            = merge(var.tags, { project = var.project_name, clusterName = local.name, environment = var.environment })
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.project_name}-${var.environment}-vpc"

  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.azs.names, 0, var.num_of_azs)
  private_subnets = [for i in range(var.num_of_azs) : cidrsubnet(var.vpc_cidr, 6, i)]
  public_subnets  = [for i in range(var.num_of_azs) : cidrsubnet(var.vpc_cidr, 6, 5 + i)]
  intra_subnets   = [for i in range(var.num_of_azs) : cidrsubnet(var.vpc_cidr, 6, 10 + i)]

  enable_nat_gateway = true
  enable_vpn_gateway = false
  single_nat_gateway = true

  # enable_dns_support   = true#
  # enable_dns_hostnames = true#


  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }


  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.16.0"

  count = var.create_eks_cluster ? 1 : 0

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  manage_aws_auth_configmap = true

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["t3.large"]

    # We are using the IRSA created below for permissions
    # However, we have to deploy with the policy attached FIRST (when creating a fresh cluster)
    # and then turn this off after the cluster/node group is created. Without this initial policy,
    # the VPC CNI fails to assign IPs and nodes cannot join the cluster
    # See https://github.com/aws/containers-roadmap/issues/1666 for more context
    iam_role_attach_cni_policy = true
  }

  eks_managed_node_groups = {
    # Default node group - as provided by AWS EKS
    #    default_node_group = {
    #      # By default, the module creates a launch template to ensure tags are propagated to instances, etc.,
    #      # so we need to disable it to use the default template provided by the AWS EKS managed node group service
    #      use_custom_launch_template = false
    #
    #      disk_size = 50
    #
    #      # Remote access cannot be specified with a launch template
    #    }
    #
    #    # Default node group - as provided by AWS EKS using Bottlerocket
    #    bottlerocket_default = {
    #      # By default, the module creates a launch template to ensure tags are propagated to instances, etc.,
    #      # so we need to disable it to use the default template provided by the AWS EKS managed node group service
    #      use_custom_launch_template = false
    #
    #      ami_type = "BOTTLEROCKET_x86_64"
    #      platform = "bottlerocket"
    #    }
    #
    #    # Adds to the AWS provided user data
    #    bottlerocket_add = {
    #      ami_type = "BOTTLEROCKET_x86_64"
    #      platform = "bottlerocket"
    #
    #      # This will get added to what AWS provides
    #      bootstrap_extra_args = <<-EOT
    #        # extra args added
    #        [settings.kernel]
    #        lockdown = "integrity"
    #      EOT
    #    }
    #
    #    # Custom AMI, using module provided bootstrap data
    #    bottlerocket_custom = {
    #      # Current bottlerocket AMI
    #      ami_id   = data.aws_ami.eks_default_bottlerocket.image_id
    #      platform = "bottlerocket"
    #
    #      # Use module user data template to bootstrap
    #      enable_bootstrap_user_data = true
    #      # This will get added to the template
    #      bootstrap_extra_args = <<-EOT
    #        # The admin host container provides SSH access and runs with "superpowers".
    #        # It is disabled by default, but can be disabled explicitly.
    #        [settings.host-containers.admin]
    #        enabled = false
    #
    #        # The control host container provides out-of-band access via SSM.
    #        # It is enabled by default, and can be disabled if you do not expect to use SSM.
    #        # This could leave you with no way to access the API and change settings on an existing node!
    #        [settings.host-containers.control]
    #        enabled = true
    #
    #        # extra args added
    #        [settings.kernel]
    #        lockdown = "integrity"
    #
    #        [settings.kubernetes.node-labels]
    #        project = var.project_name
    #
    #      EOT
    #    }
    #
    #    # Use a custom AMI
    #    custom_ami = {
    #      ami_type = "AL2_ARM_64"
    #      # Current default AMI used by managed node groups - pseudo "custom"
    #      ami_id = data.aws_ami.eks_default_arm.image_id
    #
    #      # This will ensure the bootstrap user data is used to join the node
    #      # By default, EKS managed node groups will not append bootstrap script;
    #      # this adds it back in using the default template provided by the module
    #      # Note: this assumes the AMI provided is an EKS optimized AMI derivative
    #      enable_bootstrap_user_data = true
    #
    #      instance_types = ["t4g.medium"]
    #    }
    #
    # Complete
    complete = {
      name            = "${var.environment}-${var.project_name}-eks"
      use_name_prefix = true

      subnet_ids = module.vpc.private_subnets

      min_size     = 1
      max_size     = 1
      desired_size = 1

      ami_id                     = data.aws_ami.eks_default.image_id
      enable_bootstrap_user_data = true

      capacity_type        = "SPOT"
      force_update_version = true
      instance_types       = ["t3.large"]
      labels = {
        project = var.project_name
      }

      update_config = {
        max_unavailable_percentage = 33 # or set `max_unavailable`
      }

      description = "eks managed node group for ${var.project_name}"

      ebs_optimized           = true
      disable_api_termination = false
      enable_monitoring       = true

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 75
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
        instance_metadata_tags      = "disabled"
      }

      create_iam_role          = true
      iam_role_name            = "eks-${var.environment}-${var.project_name}-node-group"
      iam_role_use_name_prefix = false
      iam_role_description     = "eks node group role for ${var.project_name}"
      iam_role_tags = {
        project = var.project_name
        env     = var.environment
      }
      iam_role_additional_policies = {
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        additional                         = aws_iam_policy.node_additional.arn
        AmazonEBSCSIDriverPolicy           = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }

      tags = {
        description = "EKS managed node group complete example"
        environment = var.environment
        project     = var.project_name
      }
    }
  }

  tags = local.tags
}

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  count = var.create_eks_cluster ? 1 : 0

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks[0].oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = local.tags
}

data "aws_ami" "eks_default" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${local.cluster_version}-v*"]
  }
}

data "aws_ami" "eks_default_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-arm64-node-${local.cluster_version}-v*"]
  }
}

data "aws_ami" "eks_default_bottlerocket" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["bottlerocket-aws-k8s-${local.cluster_version}-x86_64-*"]
  }
}
resource "aws_iam_policy" "node_additional" {
  name        = "${local.name}-additional"
  description = "Example usage of node additional policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })

  tags = local.tags
}
