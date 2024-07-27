---
display_name: AWS Lightsail Instance (Linux)
description: Provision AWS Lightsail Instance VMs as Coder workspaces
icon: ../../../site/static/icon/aws.svg
maintainer_github: coder
verified: true
tags: [vm, linux, aws, persistent-vm]
---

# Readme
1. Create new persistence disk on aws lightsail
2. Modify disk name on `main.tf` find `codiy-disk` then replace it with your disk name
3. If needed, you can customize `ssh-config.sh` script to configure ssh your new machine.
4. On `mount-disk.sh` please makesure attached disk usually name is `/dev/nvme1n1`, if not match you can change it. Location mount folder is `workspaces` on `coder` user.
5. Customize installation apt on `install-apt-tools.sh`.
6. Script `install-mise.sh` for setup depedency development tool all in one

# NOTES
Before attach you disk please makesure your disk already formatet by using ext4.