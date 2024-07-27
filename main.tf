terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.56.1"
    }
  }
}

variable "aws_access_key" {
  type        = string
  description = "AWS Access Key"
  sensitive   = true
}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Key"
  sensitive   = true
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = "ap-southeast-1"
}


data "coder_parameter" "bundle_id" {
  name        = "Instance Size"
  description = "Which instance Size?"
  type        = "string"
  mutable     = true
  default     = "micro_3_0"

  option {
    name  = "2 vCpus, 0.5 GB Memory, 20 GB SSD, $5"
    value = "nano_3_0"
  }

  option {
    name  = "2 vCpus, 1.0 GB Memory, 40 GB SSD, $7"
    value = "micro_3_0"
  }

  option {
    name  = "2 vCpus, 2.0 GB Memory, 60 GB SSD, $12"
    value = "small_3_0"
  }

  option {
    name  = "2 vCpus, 4.0 GB Memory, 80 GB SSD, $24"
    value = "medium_3_0"
  }

  option {
    name  = "2 vCpus, 8.0 GB Memory, 160 GB SSD, $44"
    value = "large_3_0"
  }

  option {
    name  = "4 vCpus, 16.0 GB Memory, 160 GB SSD, $84"
    value = "xlarge_3_0"
  }
}

data "coder_parameter" "blueprint_id" {
  name        = "Operating System"
  description = "Which Operating System?"
  type        = "string"
  mutable     = true
  default     = "ubuntu_22_04"

  option {
    name  = "Ubuntu 22.04 LTS"
    value = "ubuntu_22_04"
  }

  option {
    name  = "Ubuntu 20.04 LTS"
    value = "ubuntu_20_04"
  }
}

data "coder_parameter" "availability_zone" {
  name        = "Instance Location"
  description = "Which Instance Location?"
  type        = "string"
  mutable     = true
  default     = "ap-southeast-1a"

  option {
    name  = "Zone A"
    value = "ap-southeast-1a"
  }

  option {
    name  = "Zone B"
    value = "ap-southeast-1b"
  }

  option {
    name  = "Zone C"
    value = "ap-southeast-1c"
  }
}

data "coder_workspace" "me" {
}
data "coder_workspace_owner" "me" {}

resource "coder_agent" "main" {
  count                   = data.coder_workspace.me.start_count
  arch                    = "amd64"
  os                      = "linux"
  dir                     = "/home/coder/workspaces"
  startup_script          = local.startup_script
  startup_script_behavior = "blocking"

  display_apps {
    port_forwarding_helper = true
    vscode                 = true
    vscode_insiders        = true
    web_terminal           = true
    ssh_helper             = true
  }

  metadata {
    key          = "cpu"
    display_name = "CPU Usage"
    interval     = 15
    timeout      = 30
    script       = "coder stat cpu"
  }
  metadata {
    key          = "memory"
    display_name = "Memory Usage"
    interval     = 15
    timeout      = 30
    script       = "coder stat mem"
  }
  metadata {
    key          = "disk"
    display_name = "Disk Usage"
    interval     = 600 # every 10 minutes
    timeout      = 30  # df can take a while on large filesystems
    script       = "coder stat disk --path $HOME/workspaces"
  }
}

# Create a Lightsail Instance
resource "aws_lightsail_instance" "codiy_instance" {
  name              = "codiy"
  availability_zone = data.coder_parameter.availability_zone.value
  blueprint_id      = data.coder_parameter.blueprint_id.value
  bundle_id         = data.coder_parameter.bundle_id.value
  key_pair_name     = "id_rsa"

  user_data = <<-EOF
    #!/usr/bin/env sh
    set -eux

    sudo apt update -y
    sudo apt-get update -y
    sudo apt upgrade -y

    sudo apt install unzip zip -y

    # If user does not exist, create it and set up passwordless sudo
    if ! id -u "${local.linux_user}" >/dev/null 2>&1; then
      useradd -m -s /bin/bash "${local.linux_user}"
      echo "${local.linux_user} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${local.linux_user}
    fi

    sudo mkdir /home/coder/workspaces

    exec sudo -u ${local.linux_user} sh -c 'export CODER_AGENT_TOKEN="${try(coder_agent.main[0].token, "")}" && ${try(coder_agent.main[0].init_script, "")}'
    EOF
}

resource "aws_lightsail_disk_attachment" "codiy_attach_disk" {
  # replace disk name with your disk name
  disk_name     = "codiy-disk"
  instance_name = aws_lightsail_instance.codiy_instance.name
  disk_path     = "/dev/xvdf"
}

resource "aws_lightsail_instance_public_ports" "config_port" {
  instance_name = aws_lightsail_instance.codiy_instance.name

  port_info {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
  }

  port_info {
    protocol  = "tcp"
    from_port = 80
    to_port   = 80
  }
}

locals {
  # Ensure Coder username is a valid Linux username
  linux_user = "coder"

  # Define the init script
  startup_script = <<-EOT
    set -e

    # Set HOME explicitly
    export HOME=/home/coder
    # install and start code-server
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server --version 4.90.3

    # Export PATH and set PASSWORD
    export PATH="/tmp/code-server/bin/:$PATH"
    env

    echo "setup extension"
    code-server --install-extension PKief.material-icon-theme \
             --install-extension esbenp.prettier-vscode \
             --install-extension octref.vetur \
             --install-extension mikestead.dotenv \
             --install-extension bradlc.vscode-tailwindcss \
             --install-extension eamodio.gitlens \
             --force

    echo "starting code server"
    code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &

    echo "done all config"
    EOT
}

resource "coder_app" "code-server" {
  count        = data.coder_workspace.me.start_count
  agent_id     = coder_agent.main[0].id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:13337/?folder=/home/coder"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }
}

resource "coder_metadata" "workspace_info" {
  resource_id = aws_lightsail_instance.codiy_instance.id
  item {
    key   = "region"
    value = data.coder_parameter.availability_zone.value
  }
  item {
    key   = "instance type"
    value = aws_lightsail_instance.codiy_instance.bundle_id
  }

  item {
    key   = "disk name"
    value = aws_lightsail_disk_attachment.codiy_attach_disk.disk_name
  }
}

resource "coder_script" "ssh-config" {
  agent_id           = try(coder_agent.main[0].id, "")
  display_name       = "ssh-config"
  icon               = "/icon/code.svg"
  run_on_start       = true
  start_blocks_login = true
  script = templatefile("./ssh-config.sh", {
    LOG_PATH : "/tmp/ssh-config.log",
  })
}

resource "coder_script" "attach-disk" {
  agent_id           = try(coder_agent.main[0].id, "")
  display_name       = "attach-disk"
  icon               = "/icon/code.svg"
  run_on_start       = true
  start_blocks_login = true
  script = templatefile("./mount-disk.sh", {
    LOG_PATH : "/tmp/attach-disk.log"
  })
}

resource "coder_script" "install-mise" {
  agent_id           = try(coder_agent.main[0].id, "")
  display_name       = "install-mise"
  icon               = "/icon/code.svg"
  run_on_start       = true
  start_blocks_login = true
  script = templatefile("./install-mise.sh", {
    LOG_PATH : "/tmp/install-mise.log"
  })
}

resource "coder_script" "install-apt-tools" {
  agent_id           = try(coder_agent.main[0].id, "")
  display_name       = "install-apt-tools"
  icon               = "/icon/code.svg"
  run_on_start       = true
  start_blocks_login = true
  script = templatefile("./install-apt-tools.sh", {
    LOG_PATH : "/tmp/install-apt-tools.log"
  })
}

output "cpu_count" {
  value = aws_lightsail_instance.codiy_instance.cpu_count
}

output "ram_size" {
  value = aws_lightsail_instance.codiy_instance.ram_size
}

output "public_ip_address" {
  value = aws_lightsail_instance.codiy_instance.public_ip_address
}

output "availability_zone" {
  value = aws_lightsail_instance.codiy_instance.availability_zone
}
