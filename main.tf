provider "helm" {
  version = ">= 1.1.1"

  kubernetes {
    config_path = var.cluster_config_file
  }
}

locals {
  tmp_dir      = "${path.cwd}/.tmp"
  cluster_type = var.cluster_type == "kubernetes" ? "kubernetes" : "openshift"
  ingress_host = "apieditor-${var.releases_namespace}.${var.cluster_ingress_hostname}"
  name         = "swaggereditor"
  endpoint_url = "https://${local.ingress_host}"
}

resource "null_resource" "swaggereditor_cleanup" {
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
  repository   = "https://ibm-garage-cloud.github.io/toolkit-charts/"
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

resource "null_resource" "delete-consolelink" {
  count = var.cluster_type != "kubernetes" ? 1 : 0

  provisioner "local-exec" {
    command = "kubectl delete consolelink -l grouping=garage-cloud-native-toolkit -l app=apieditor || exit 0"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

resource "helm_release" "apieditor-config" {
  depends_on = [helm_release.swaggereditor, null_resource.delete-consolelink]

  name         = "apieditor"
  repository   = "https://ibm-garage-cloud.github.io/toolkit-charts/"
  chart        = "tool-config"
  namespace    = var.releases_namespace
  force_update = true

  set {
    name  = "url"
    value = local.endpoint_url
  }

  set {
    name  = "applicationMenu"
    value = var.cluster_type == "ocp4"
  }

  set {
    name  = "ingressSubdomain"
    value = var.cluster_ingress_hostname
  }

  set {
    name  = "displayName"
    value = "Swagger Editor"
  }
}
