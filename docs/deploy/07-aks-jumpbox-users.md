# Configuring Jump Box Users

You've [built the jump box image](./06-aks-jumpboximage.md), now you need to build out a user access plan.

## Jump box user management

You have multiple options on how you manage your jump box users. Because jump box user management isn't the focus of the walkthrough, we'll stick with a relatively straightforward mechanism to keep you moving. However, generally you'll want to ensure you're using a solution like [Microsoft Entra ID with OpenSSH](https://learn.microsoft.com/entra/identity/devices/howto-vm-sign-in-azure-ad-linux) so that you can take advantage of Microsoft Entra Conditional Access policies, JIT permissions, and so on. Employ whatever user governance mechanism will help you achieve your desired compliance outcome and still being able to easily on- and off-board users as your ops teams' needs and personnel change.

> :notebook: For more information, see [Azure Architecture Center guidance for PCI DSS 3.2.1 Requirement 7 and 8 in AKS](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-identity).

## Expected results

Following these steps, you'll end up with an SSH public-key-based solution that uses [cloud-init](https://learn.microsoft.com/azure/virtual-machines/linux/using-cloud-init). The results will be captured in `jumpBoxCloudInit.yml` which you will later convert to Base64 for use in your cluster's ARM template.

## Steps

1. Open `jumpBoxCloudInit.yml` in your preferred editor.
1. Inspect the two users examples in that file. You need **one** user defined in this file to complete this walk through (*more than one user is fine*, but not necessary). 🛑
   1. `name:` set to whatever you login account name you wish. (You'll need to remember this later.)
   1. `sudo:` - Suggested to leave at `False`. This means the user cannot `sudo`. If this user needs sudo access, use [sudo rule strings](https://cloudinit.readthedocs.io/en/latest/topics/examples.html?highlight=sudo#including-users-and-groups) to restrict what sudo access is allowed.
   1. `lock_passwd:` - Leave at `True`. This disables password login, and as such the user can only connect via an SSH authorized key. Your jump box should enforce this as well on its SSH daemon. If you deployed using the image builder in the prior step, it does this enforcement there as well.
   1. In `ssh-authorized-keys` replace the `<public-ssh-rsa-for-...>` placeholder with an actual public ssh public key for the user. This must be an RSA key of at least 2048 bits and **must be secured with a passphrase**. This key will be added to that user's `~/.ssh/authorized_keys` file on the jump box via the cloud-init bootstrap process.

1. Generate a key pair for this walk through

   ```bash
   ssh-keygen -t rsa -b 4096 -f opsuser01.key
   ```

   **Enter a passphrase when requested** (*do not leave empty*) and note where the public and private key file was saved. The *public* key file *contents* (`opsuser01.key.pub` in the example above) is what is added to the `ssh-authorized-keys` array in `jumpBoxCloudInit.yml`. You'll need the username, the private key file (`opsuser01.key`), and passphrase later in this walkthrough.

   > On Windows, as an alternative to Bash in WSL, you can use a solution like PuTTYGen found in the [PuTTY installer](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html).
   >
   > Azure also has an SSH Public Key resources type that allows you to [generate SSH keys](https://learn.microsoft.com/azure/virtual-machines/ssh-keys-portal) and keep public keys available as a managed resource.

1. Manually add/remove/modify users following the information from the previous steps or simply execute the following command to overwrite the `jumpBoxCloudInit.yml` file with a valid user example

   ```bash
   cat <<EOF > jumpBoxCloudInit.yml -
   #cloud-config
   users:
     - default
     - name: opsuser01
       sudo: False
       lock_passwd: True
       ssh-authorized-keys:
         - $(cat opsuser01.key.pub)
   EOF
   ```

1. *Optional 🛑.* Remove the `- default` line to remove the default admin user from the jump box.

   If you leave the `- default` line in the file, then the default admin user (defined in the cluster's ARM template as pseudo-random name to discourage usage) will also exist on this jump box. We do not provide any instructions on setting up this default user to be a valid user you can access, and as such you might wish to simply remove it from the jump box. That user has unrestricted sudo access, by default. Unfortunately, you cannot directly deploy the jump box infrastructure with this user removed, so removing it via cloud-init is a common resolution -- by not including `- default` in this file.
1. You can commit this file change if you wish, as the only values in here are public keys, which are not secrets. **Never commit any private SSH keys.**

### Next step

:arrow_forward: [Deploy the AKS cluster network spoke](./08-cluster-networking.md).
