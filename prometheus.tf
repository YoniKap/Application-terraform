resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "prometheus"
  create_namespace = true

  set {
    name  = "prometheusOperator.createCustomResource"
    value = "true"
  }

  # In case you want to override other values, you can use additional set blocks
  set {
    name  = "alertmanager.ingress.enabled"
    value = "true"
  }

  # If you want to completely replace the values, use the values block
  # values = [
  #   "${file("values.yaml")}"
  # ]

  # Resetting values to default might not be necessary, as you are explicitly setting values
  reset_values = true
}

resource "helm_release" "prometheus_mysql" {
  name       = "prometheus-mysql"  # Unique release name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-mysql-exporter"
  namespace  = "prometheus"
  create_namespace = true

  set {
    name  = "sqlExporter.createCustomResource"
    value = "true"
  }
}