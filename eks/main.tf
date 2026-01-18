module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  availability_zones = var.availability_zones

  cluster_name = var.cluster_name
}

module "eks" {
  source = "./modules/eks"

  vpc_id = module.vpc.vpc_id
  cluster_name = var.cluster_name
  cluster_version = var.cluster_version
  subnet_ids = module.vpc.private_subnet_ids
  node_groups = var.node_groups

  depends_on = [ module.vpc ]
}

module "customization" {
  source = "./modules/customization"

  cluster_name = var.cluster_name
  vpcId = module.vpc.vpc_id

  aws_eks_cluster = data.aws_eks_cluster.main
  aws_eks_cluster_auth = data.aws_eks_cluster_auth.main
  tls_certificate = data.tls_certificate.eks
  
  depends_on = [ module.eks ]
}