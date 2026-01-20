resource "helm_release" "elb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.14.0"

  set = [
    {
    name = "clusterName"
    value = var.cluster_name
    }, 
    {
      name = "serviceAccount.create"
      value = false
    },
    {
      name = "serviceAccount.name"
      value = kubernetes_service_account_v1.elb.metadata[0].name
    },
    {
      name = "vpcId"
      value = var.vpcId
    }
  ]

  depends_on = [ kubernetes_service_account_v1.elb ]
}

resource "helm_release" "csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"

  set = [
    {
    name = "controller.serviceAccount.create"
    value = false
    }, 
    {
      name = "controller.serviceAccount.name"
      value = kubernetes_service_account_v1.csi.metadata[0].name
    }
  ]

  depends_on = [ kubernetes_service_account_v1.csi ]
}

resource "helm_release" "nginx_ingress_controller" {
  name = "nginx-ingress-controller"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart = "ingress-nginx"
  namespace = "ingress-nginx"
  
  create_namespace = true

  wait = false
  timeout = 300
}

resource "helm_release" "cert_manager" {
  name = "cert-manager"
  chart = "oci://quay.io/jetstack/charts/cert-manager"
  namespace = "cert-manager"

  create_namespace = true

  wait = false
  timeout = 300

  set = [ {
    name = "crds.enabled"
    value = true
  } ]
}
