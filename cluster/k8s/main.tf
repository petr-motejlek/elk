resource "vagrant_vm" "nodes" {
  env = {
    VAGRANT_EXPERIMENTAL = "disks",
    VAGRANTFILE_HASH = md5(file("Vagrantfile"))
  }
  get_ports = true
}
