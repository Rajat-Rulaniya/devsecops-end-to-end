module "elb_controller_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"

  name = "aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    eks = {
      provider_arn = aws_iam_openid_connect_provider.eks.arn
      namespace_service_accounts = [
        "kube-system:aws-load-balancer-controller"
      ]
    }
  }

  depends_on = [ aws_iam_openid_connect_provider.eks ]
}

module "ebs_csi_driver_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"

  name = "ebs-csi-controller-sa"

  attach_ebs_csi_policy = true

  oidc_providers = {
    eks = {
      provider_arn = aws_iam_openid_connect_provider.eks.arn
      namespace_service_accounts = [
        "kube-system:ebs-csi-controller-sa"
      ]
    }
  }

  depends_on = [ aws_iam_openid_connect_provider.eks ]
}

resource "kubernetes_service_account_v1" "elb" {
  metadata {
    name = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = module.elb_controller_irsa.arn
    }
  }

  automount_service_account_token = true
}

resource "kubernetes_service_account_v1" "csi" {
  metadata {
    name = "ebs-csi-controller-sa"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = module.ebs_csi_driver_irsa.arn
    }
  }

  automount_service_account_token = true
}
