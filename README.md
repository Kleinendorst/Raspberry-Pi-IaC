# Raspberry Pi IaC
Contains the Infrastructure as Code files which are used for provisioning my in house Raspberry Pi.

## Prerequisites
The files within this repository should be run on a computer with Ansible installed which is only supported on MacOS and Linux systems. For Windows it can be run within a WSL distro (see [this guide](https://code.visualstudio.com/docs/remote/wsl-tutorial) on how to set this up, make sure the repository is checked out on the WSL distribution itself).

### Ansible control node prerequisites
1. Install Ansible ([see instructions](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)).
2. Install Ansible Galaxy content:

    ```bash
    ansible-galaxy install -r requirements.yml
    ```
3. Enter the vault password in the **.vault_pass** file. This is included in **.gitignore** so it shouldn't end up in the repository:

    ```bash
    # Notice the space at the beginning, this prevents the shell from saving this command in its history.
     echo '[ -- enter vault pass here -- ]' > .vault_pass
    ```

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
ansible-playbook playbook.yml
```

## Overview of installed software
### SSH with ZSH
It's possible to connect to the Raspberry Pi from the internal network via either its FQDN or IP address **using a public key only** setup as part of [the Raspberry Pi preperation](#raspberry-pi-preperation).
When logged in the user will be prompted with the **zsh** configured with **[Oh My Zsh](https://ohmyz.sh)** and **[Starhip](https://starship.rs) prompts**.

![zsh](./images/zsh.png)

## Other
### Reinstalling the Pi
It can be handy to reinstall the Pi. First shutdown the pi by running `sudo shutdown` from SSH. Next take out the memory card and follow all steps in [Raspberry Pi preperation](#raspberry-pi-preperation).
For the next step remove the current *known_hosts* entry with: `ssh-keygen -R '192.168.50.27'` for all PCs that had SSH access to the Pi.

### Debugging users other than the main user
The **user** role included in this repository makes it possible to create new users which will also have a fully configured
ZSH environment. They can't be accessed via SSH because no SSH keys are added for them and password logins are disabled.
Logging into the new user's account can be done as follows (for testing and debugging):

```bash
# Enter both the username and password
sudo login
```

This is verified to be working:

![new users](./images/login_success.png)
