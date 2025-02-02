## Copyright © 2021, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "tls_private_key" "public_private_key_pair" {
  algorithm = "RSA"
}

resource "oci_containerengine_cluster" "oci_oke_cluster" {
  compartment_id     = var.compartment_ocid
  kubernetes_version = var.k8s_version
  name               = var.oke_cluster_name
  vcn_id             = var.use_existing_vcn ? var.vcn_id : oci_core_vcn.oke_vcn[0].id

  dynamic "endpoint_config" {
    for_each = var.vcn_native ? [1] : []
    content {
      is_public_ip_enabled = var.is_api_endpoint_subnet_public
      subnet_id            = var.use_existing_vcn ? var.api_endpoint_subnet_id : oci_core_subnet.oke_api_endpoint_subnet[0].id
    }
  }

  options {
    service_lb_subnet_ids = [var.use_existing_vcn ? var.lb_subnet_id : oci_core_subnet.oke_lb_subnet[0].id]

    add_ons {
      is_kubernetes_dashboard_enabled = var.cluster_options_add_ons_is_kubernetes_dashboard_enabled
      is_tiller_enabled               = var.cluster_options_add_ons_is_tiller_enabled
    }

    admission_controller_options {
      is_pod_security_policy_enabled = var.cluster_options_admission_controller_options_is_pod_security_policy_enabled
    }

    kubernetes_network_config {
      pods_cidr     = var.pods_cidr
      services_cidr = var.services_cidr
    }
  }
}

resource "oci_containerengine_node_pool" "oci_oke_node_pool" {
  cluster_id         = oci_containerengine_cluster.oci_oke_cluster.id
  compartment_id     = var.compartment_ocid
  kubernetes_version = var.k8s_version
  name               = var.pool_name
  node_shape         = var.node_shape

  initial_node_labels {
    key   = var.node_pool_initial_node_labels_key
    value = var.node_pool_initial_node_labels_value
  }

  node_source_details {
    image_id                = var.node_image_id == "" ? element([for source in data.oci_containerengine_node_pool_option.oci_oke_node_pool_option.sources : source.image_id if length(regexall("Oracle-Linux-${var.node_linux_version}-20[0-9]*.*", source.source_name)) > 0], 0) : var.node_image_id
    source_type             = "IMAGE"
    boot_volume_size_in_gbs = var.node_pool_boot_volume_size_in_gbs
  }

  ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : tls_private_key.public_private_key_pair.public_key_openssh

  node_config_details {
    placement_configs {
      availability_domain = var.availability_domain == "" ? data.oci_identity_availability_domains.ADs.availability_domains[0]["name"] : var.availability_domain
      subnet_id           = var.use_existing_vcn ? var.nodepool_subnet_id : oci_core_subnet.oke_nodepool_subnet[0].id
    }
    size = var.node_count
  }

  dynamic "node_shape_config" {
    for_each = length(regexall("Flex", var.node_shape)) > 0 ? [1] : []
    content {
      ocpus         = var.node_ocpus
      memory_in_gbs = var.node_memory
    }
  }
}


