# Variables

variable "az_cidr_map" {
  default = {
    ru-central1-a = "10.100.0.0/24"
    ru-central1-b = "10.100.1.0/24"
    ru-central1-c = "10.100.2.0/24"
  }
}

locals {
  az = keys(var.az_cidr_map)
}

# Networking

resource "yandex_vpc_network" "pet" {
  name        = "pet"
  description = "VPC for pet cluster setup"
  labels = {
    Name  = "pet"
    Owner = "Grid"
  }
}

/*
resource "yandex_vpc_gateway" "pet_egress_gateway" {
  name = "pet-egress-gateway"
}
resource "yandex_vpc_route_table" "pet_route_table_a" {
  network_id = yandex_vpc_network.pet.id
  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.pet_egress_gateway.id
  }
  labels = {
    Name  = "pet-route-table-a"
    Owner = "Grid"
  }
}
*/

resource "yandex_vpc_subnet" "pet_subnets" {
  count          = length(local.az)
  name           = "pet-subnet-${element(local.az, count.index)}"
  v4_cidr_blocks = [lookup(var.az_cidr_map, element(local.az, count.index))]
  zone           = element(local.az, count.index)
  network_id     = yandex_vpc_network.pet.id
  #  route_table_id = yandex_vpc_route_table.pet_route_table_a.id
  labels = {
    Name  = "pet-subnet-${element(local.az, count.index)}"
    Owner = "Grid"
  }
}

# Instances section

data "yandex_compute_image" "ubuntu_image" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "compute_master" {
  count       = 1
  name        = "master-${count.index + 1}"
  platform_id = "standard-v1"
  zone        = element(local.az, count.index)

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_image.id
      size     = 10
    }
  }

  network_interface {
    ip_address = cidrhost(element(yandex_vpc_subnet.pet_subnets[count.index].v4_cidr_blocks, count.index), 100)
    subnet_id  = yandex_vpc_subnet.pet_subnets[count.index].id
    nat        = true
  }

  metadata = {
    ssh-keys  = "ubuntu:${file("/Users/aromanin/.ssh/yandex-cloud.pub")}"
    user-data = "${templatefile("scripts/init.sh.tftpl", { cluster_node_role = "master", node_index = count.index + 1 })}"
  }
}

resource "yandex_compute_instance" "compute_node" {
  count       = 3
  name        = "node-${count.index + 1}"
  platform_id = "standard-v1"
  zone        = element(local.az, count.index)

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_image.id
      size     = 10
    }
  }

  network_interface {
    ip_address = cidrhost(element(yandex_vpc_subnet.pet_subnets[count.index].v4_cidr_blocks, count.index), 200)
    subnet_id  = yandex_vpc_subnet.pet_subnets[count.index].id
    nat        = true
  }

  metadata = {
    ssh-keys  = "ubuntu:${file("/Users/aromanin/.ssh/yandex-cloud.pub")}"
    user-data = "${templatefile("scripts/init.sh.tftpl", { cluster_node_role = "node", node_index = count.index + 1 })}"
  }
}

# Outputs section

output "external-ipv4-master" {
  value = yandex_compute_instance.compute_master[*].network_interface.0.nat_ip_address
}

output "external-ipv4-node" {
  value = yandex_compute_instance.compute_node[*].network_interface.0.nat_ip_address
}
