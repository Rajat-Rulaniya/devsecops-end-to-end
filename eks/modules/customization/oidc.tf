resource "aws_iam_openid_connect_provider" "eks" {
  url = var.aws_eks_cluster.identity[0].oidc[0].issuer

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    var.tls_certificate.certificates[0].sha1_fingerprint
  ]
}