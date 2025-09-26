# Ubuntu 24.04 LTS for Docker
Minimal OS to run Docker containers. Built with [Elemental toolkit](https://rancher.github.io/elemental-toolkit/)

# Usage
## Install
1. Boot from ISO
2. Install by running command: `elemental install /dev/sda`
3. Reboot

# Upgrade
1. Run command `elemental upgrade`
2. Reboot
3. Check version by running `grep IMAGE_TAG /etc/os-release`
