# Raspberry Pi IaC
Contains the Infrastructure as Code files which are used for provisioning my in house Raspberry Pi.

## Prerequisites
The files within this repository should be run on a computer with Ansible installed which is only supported on MacOS and Linux systems. For Windows it can be run within a WSL distro (see [this guide](https://code.visualstudio.com/docs/remote/wsl-tutorial) on how to set this up, make sure the repository is checked out on the WSL distribution itself).

### Ansible control node prerequisites
Install Ansible ([see instructions](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)).

### Environment prerequisites
The Raspberry Pi IaC code contained within this repository provisions the Raspberry Pi itself but doesn't provision all surrounding infrastructure which is presumed to be managed by hand. The following relevant configuration is assumed:

1. [A prepared Raspberry Pi]((#raspberry-pi-preperation)).
3. [Cloudflare](https://dash.cloudflare.com/login) should be setup for managing the domain records of *kleinendorst.info*.

### Raspberry Pi preperation
The Raspberry Pi should be installed and running with reachable SSH from the network.

1. Setup its MicroSD card using the Raspberry Pi Imager ([download](https://www.raspberrypi.com/software/)). For **CHOOSE OS** select the : **Raspberry Pi OS (other)** > **Raspberry Pi OS Lite (64-bit)** option.
2. When asked: **Would you like to apply OS customisation settings?** select **EDIT SETTINGS**. Select and fill in the following settings:
    1. **Set username and password**
    2. **Set locale settings**
    3. **Enable SSH** > **Use password authentication** (we'll harden it later to use public keys).
    4. Disable **Eject media when finished** (probably not really important but I heard it could prevent problems on Windows).
3. Start the Raspberry Pi with an ethernet cable attached.
4. Find the assigned IP of the Raspberry Pi in the [router](http://asusrouter.com/) and configure DHCP to statically asign this address to the Raspberry Pi.
5. Add the new Raspberry Pi to the *hosts* file using the internal IP.
6. Test if the Raspberry Pi is correctly configured by opening an SSH session to it (using its IP address). If this works the next step is to [add SSH public keys for each computer that should provision/connect to the Raspberry Pi](https://linuxhandbook.com/add-ssh-public-key-to-server/). **It's important to perform this step before provisioning because that will disallow logging into SSH with  a password.**

## Provisioning
Provision the Raspberry Pi by running:

```bash
ansible-playbook -i inventory playbook.yml
```
