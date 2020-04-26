terraform {
  required_version = ">= 0.12.0"
}

provider "aws" {
  version = ">= 2.28.1"
  region  = "us-east-1"
}

provider "random" {
  version = "~> 2.1"
}

provider "local" {
  version = "~> 1.2"
}

provider "null" {
  version = "~> 2.1"
}

provider "template" {
  version = "~> 2.1"
}
/*
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}
*/
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.11"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.6.0"

  name                             = "demo-vpc"
  cidr                             = "10.0.0.0/16"
  azs                              = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets                  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets                   = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway               = true
  single_nat_gateway               = true
  one_nat_gateway_per_az           = false
  enable_dns_hostnames             = true

  public_subnet_tags = {
    "kubernetes.io/cluster/eks-dev-test-cluster" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/eks-dev-test-cluster" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

/*

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "eks-dev-test-cluster"
  cluster_version = "1.14"
  subnets         = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id
  cluster_endpoint_private_access  = true
  cluster_endpoint_public_access   = false

  node_groups_defaults = {
    ami_type  = "AL2_x86_64"
    disk_size = 20
  }

  node_groups = {
    example = {
      desired_capacity = 1
      max_capacity     = 3
      min_capacity     = 1

      instance_type = "t2.medium"
      k8s_labels = {
        env = "dev-test"
      }
      additional_tags = {
        env = "dev-test"
      }
    }
  }

  tags = {
    env = "dev-test"
  }
  */

resource "aws_security_group" "ssh-http" {
  name        = "allow ssh-http"
  description = "allow ssh-http traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "jenkins-port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "demokey"
  public_key = tls_private_key.keypair.public_key_openssh
}

resource "aws_instance" "jenkins" {
  ami                            = "ami-00b99db251c4b691a"
  instance_type                  = "t2.small"
  subnet_id                      = module.vpc.public_subnets[0]
  associate_public_ip_address    = "true"
  vpc_security_group_ids         = [aws_security_group.ssh-http.id]
  key_name                       = aws_key_pair.generated_key.key_name
}

