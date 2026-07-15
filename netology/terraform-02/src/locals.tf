locals {
  vm_web_name = "${var.project_name}-${var.env_name}-${var.vm_web_name}"
  vm_db_name  = "${var.project_name}-${var.env_name}-${var.vm_db_name}"

  vm_metadata = merge(
    var.metadata,
    {
      ssh-keys = "ubuntu:${var.vms_ssh_public_root_key}"
    }
  )
}
