
locals {
  tmp_dir      = "${path.cwd}/.tmp"
  bin_dir      = module.setup_clis.bin_dir
  values_file  = "${local.tmp_dir}/swaggereditor-values.yaml"
  cluster_type = var.cluster_type == "kubernetes" ? "kubernetes" : "openshift"
  name         = "swaggereditor"
  swagger_config = {
    clusterType = local.cluster_type
    ingressSubdomain = var.cluster_ingress_hostname
    "sso.enabled" = var.enable_sso
    tlsSecretName = var.tls_secret_name
  }
}

resource null_resource print_toolkit_namespace {
  provisioner "local-exec" {
    command = "echo 'Toolkit namespace: ${var.toolkit_namespace}'"
  }
}

module setup_clis {
  source = "github.com/cloud-native-toolkit/terraform-util-clis.git"

  clis = ["helm"]
}

resource local_file swaggereditor_values {
  content  = yamlencode(local.swagger_config)

  filename = local.values_file
}

resource null_resource swaggereditor_helm {
  depends_on = [null_resource.print_toolkit_namespace]

  provisioner "local-exec" {
    command = "${local.bin_dir}/helm template swaggereditor swaggereditor --repo https://charts.cloudnativetoolkit.dev --version ${var.chart_version} -n ${var.releases_namespace} -f ${local.values_file} | kubectl apply -n ${var.releases_namespace} -f -"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = "${local.bin_dir}/helm template swaggereditor swaggereditor --repo https://charts.cloudnativetoolkit.dev --version ${var.chart_version} -n ${var.releases_namespace} -f ${local.values_file} | kubectl delete -n ${var.releases_namespace} -f -"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

resource null_resource wait-for-deployment {
  depends_on = [null_resource.swaggereditor_helm]

  provisioner "local-exec" {
    command = "kubectl rollout status -n ${var.releases_namespace} deployment/swaggereditor"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}
