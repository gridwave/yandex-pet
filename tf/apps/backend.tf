terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  backend "s3" {
    endpoint                    = "storage.yandexcloud.net"
    bucket                      = "pet-terraform-state"
    key                         = "apps/terraform.tfstate"
    region                      = "ru-central1"
    shared_credentials_file     = "storage.key"
    skip_region_validation      = true
    skip_credentials_validation = true
  }
}
