variable "cluster_name" {
  type = string
  description = "Our EKS Cluster name"
}

variable "vpcId" {
  type = string
  description = "VPC Id"
}

variable "aws_eks_cluster" {
  description = "Our EKS cluster info"
}

variable "aws_eks_cluster_auth" {
  description = "Our EKS cluster auth info"
}

variable "tls_certificate" {
  description = "TLS certificate of our cluster endpoint"
}