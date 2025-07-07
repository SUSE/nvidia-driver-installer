# Nvidia Drivers Installer

**Important Note: The repository is currently under development and not yet ready for production use**

- nvidia-driver-installer installs a `DaemonSet` which runs a pod on all the nodes labeled `node-role.kubernetes.io/ai-worker=true`. The pod on each node runs a privileged container that runs a script to install the drivers on the node.

- The script after installing the drivers writes a file `/host/var/run/reboot-needed` which [kured](https://kured.dev/) looks for to trigger the node reboot.
