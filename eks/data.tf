data "aws_eks_cluster" "main" {
  name = var.cluster_name

  depends_on = [ module.eks ]
}

data "aws_eks_cluster_auth" "main" {
  name = var.cluster_name

  depends_on = [ module.eks ]
}

data "tls_certificate" "eks" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer

  depends_on = [ data.aws_eks_cluster.main ]
}