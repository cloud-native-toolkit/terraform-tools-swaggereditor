
locals {
  tmp_dir      = "${path.cwd}/.tmp"
  cluster_type = var.cluster_type == "kubernetes" ? "kubernetes" : "openshift"
  ingress_host = "apieditor-${var.releases_namespace}.${var.cluster_ingress_hostname}"
  name         = "swaggereditor"
  endpoint_url = "http${var.tls_secret_name != "" ? "s" : ""}://${local.ingress_host}"
}

resource null_resource print_toolkit_namespace {
  provisioner "local-exec" {
    command = "echo 'Toolkit namespace: ${var.toolkit_namespace}'"
  }
}

resource "null_resource" "swaggereditor_cleanup" {
  depends_on = [null_resource.print_toolkit_namespace]

  provisioner "local-exec" {
    command = "kubectl delete scc privileged-swaggereditor || true"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

resource "helm_release" "swaggereditor" {
  depends_on = [null_resource.swaggereditor_cleanup]

  name         = "swaggereditor"
  repository   = "https://charts.cloudnativetoolkit.dev"
  chart        = "swaggereditor"
  version      = var.chart_version
  namespace    = var.releases_namespace
  force_update = true

  disable_openapi_validation = true

  set {
    name  = "clusterType"
    value = local.cluster_type
  }

  set {
    name  = "ingressSubdomain"
    value = var.cluster_ingress_hostname
  }

  set {
    name  = "sso.enabled"
    value = var.enable_sso
  }

  set {
    name  = "tlsSecretName"
    value = var.tls_secret_name
  }
}
