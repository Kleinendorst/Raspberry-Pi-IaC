# Raspberry Pi IaC
Contains the Infrastructure as Code files which are used for provisioning my in house Raspberry Pi.

## Prerequisites
The files within this repository should be run on a computer with Ansible installed. This is only possible on MacOS or Linux systems. For Windows it can be run within a WSL distro (see [this guide](https://code.visualstudio.com/docs/remote/wsl-tutorial) on how to set this up, make sure the repository is checked out on the WSL distribution itself).

### Ansible control node prerequisites
Install Ansible ([see instructions](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)).

### Environment prerequisites
The Raspberry Pi IaC code contained within this repository provisions the Raspberry Pi itself but doesn't provision all surrounding infrastructure which is presumed to be managed by hand. The following relevant configuration is assumed:

1. The Raspberry Pi should be installed and running with reachable SSH from the network. Setup its MicroSD card using the Raspberry Pi Imager ([download](https://www.raspberrypi.com/software/)). For **CHOOSE OS** select the : **Raspberry Pi OS (other)** > **Raspberry Pi OS Lite (64-bit)** option. Start the Raspberry Pi with an ethernet cable attached.
2. The Raspberry Pi should have a fixed internal IP on the home network, this can be configured in [the router](http://asusrouter.com/Main_Login.asp). Make note of this internal ip, it should match the value in the *hosts* file.
3. [Cloudflare](https://dash.cloudflare.com/login) should be setup for managing the domain records of *kleinendorst.info*.
