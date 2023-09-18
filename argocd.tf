resource "helm_release" "argocd" {
  count            = var.create_eks_cluster ? 1 : 0
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  version          = "5.31.0"
  create_namespace = true

  # set {
  #   name  = "controller.adminPassword"
  #   value = "admin"
  # }

  # set {
  #   name  = "controller.adminUser"
  #   value = "admin"
  # }

  set {
    name  = "server.ingress.enabled"
    value = "true"
  }


  # values = [
  #   file("argocd-values.yml"),
  # ]
}



