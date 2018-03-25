provider "google" {
  version = "1.4.0"
  project = "${var.project}"
  region  = "${var.region}"
}

# Подключение SSH ключей для пользователя asomirl И appuser
resource "google_compute_project_metadata" "ssh-asomirl" {
  metadata {
    ssh-keys = "${var.gitlab_admin}:${file(var.public_key_path)}"
  }
}

resource "google_compute_instance" "gitlab" {
  name         = "gitlab"
  machine_type = "n1-standard-1"
  zone         = "${var.zone}"
  tags         = ["docker-host", "default-allow-ssh"]

  # добавление SSH ключей для моего пользователя
  #metadata {
  #sshKeys = "asomirl:${file(var.public_key_path)}"
  #}

  # определение загрузочного диска
  boot_disk {
    initialize_params {
      image = "${var.disk_image}"
      size  = 50
    }
  }
  # определение сетевого интерфейса
  network_interface {
    # сеть, к которой присоединить данный интерфейс
    network = "default"

    # использовать ephemeral IP для доступа из Интернет
    access_config {}
  }
  # включаем подключение по ssh с путём к приватному ключу
  connection {
    type        = "ssh"
    user        = "${var.gitlab_admin}"
    agent       = false
    private_key = "${file(var.private_key_path)}"
  }
}

# Создание правила для firewall
resource "google_compute_firewall" "docker-host-allow" {
  name = "docker-host-allow"

  # Название сети, в которой действует правило
  network = "default"

  # Какой доступ разрешить
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  # Каким адресам разрешаем доступ
  source_ranges = ["0.0.0.0/0"]

  # Правило применимо для инстансов с тегом …
  target_tags = ["docker-host"]
}

resource "google_compute_address" "gitlab_ip" {
  name = "gitlab-ip"
}


resource "google_compute_firewall" "firewall_ssh" {
  name    = "gitlab-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = "${var.source_ranges}"
}