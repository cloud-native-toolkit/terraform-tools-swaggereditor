module "dev_tools_swagger" {
  source = "./module"

  cluster_config_file      = module.dev_cluster.config_file_path
  cluster_ingress_hostname = module.dev_cluster.platform.ingress
  cluster_type             = module.dev_cluster.platform.type_code
  tls_secret_name          = module.dev_cluster.platform.tls_secret
  releases_namespace       = module.dev_capture_state.namespace
  enable_sso               = true
}
