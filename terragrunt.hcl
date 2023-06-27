terraform {
  source = "${local.artifactory_base_path}/${local.this.module}/tags/v${local.this.version}/${local.this.module}-v${local.this.version}.zip//${local.this.module}-${local.this.version}/${local.this.submodule}"
}

remote_state {
  backend = "remote"
}

include {
  path = find_in_parent_folders()
}

locals {
  gke_base_yaml         = (fileexists("/terragrunt/yaml_base/gke.yaml") ? yamldecode(file("/terragrunt/yaml_base/gke.yaml")) : {})
  default_yaml_path     = find_in_parent_folders("empty.yaml")
  common_vars           = yamldecode(file(find_in_parent_folders("common_vars.yaml")))
  this                  = yamldecode(file("${get_terragrunt_dir()}/this.yaml"))
  artifactory_base_path = "https://artifactoryrepo1.appslatam.com/artifactory/terraform-modules/terraform-google-modules"
  bucket_tf_state       = local.common_vars.environment == "prod" ? "sp-te-resman-prod-latam-productivo" : "sp-te-resman-prod-latam-noproductivo"
  prefix_tf_state       = local.common_vars.bitbucket_repo == "" ? "${local.common_vars.bitbucket_key}" : "${local.common_vars.bitbucket_key}/${local.common_vars.bitbucket_repo}"
  release_channel       = local.common_vars.environment == "intg" || local.common_vars.environment == "prod" || local.common_vars.environment == "cert" ? "STABLE" : "REGULAR"
}

inputs = merge(
  local.gke_base_yaml,
  {
    network                         = dependency.vpc.outputs.network_name
    subnetwork                      = "sub-${local.common_vars.region}"
    project_id                      = dependency.project.outputs.project_id
    remove_default_node_pool        = true
    create_service_account          = true
    network_policy                  = true
    enable_private_nodes            = true
    ip_range_pods                   = "${local.this.name}-pods"
    ip_range_services               = "${local.this.name}-services"
    release_channel                 = local.release_channel
    horizontal_pod_autoscaling      = false
    enable_vertical_pod_autoscaling = false
    database_encryption = [
      { "key_name" : format("%s/cryptoKeys/key", dependency.kms.outputs.keyring), "state" : "ENCRYPTED" }
    ]
  },
  local.common_vars,
  local.this
)

prevent_destroy = false  # Set false if you want to allow to destroy this resource
skip            = false # Set true if you want to skip making changes to this resource

# Dependency list and configuration
dependency "project" {
  config_path                             = "../../${local.this.project}"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  skip_outputs                            = false
  mock_outputs = {
    project_id = "sp-dg-cloudhub-cert-w7ev"
  }
}

dependency "vpc" {
  config_path                             = "../../${local.this.vpc}"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  skip_outputs                            = false
  mock_outputs = {
    network_name = "vpc-lan"
  }
}

dependency "kms" {
  config_path                             = "../../${local.this.kms}"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  skip_outputs                            = false
  mock_outputs = {
    keyring = "keyring_fake"
  }
}

dependencies {
  paths = ["../../${local.this.subnets}", "../../${local.this.iam_kms}"]
}
