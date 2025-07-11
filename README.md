# Nvidia Drivers Installer

**Important Note: The repository is currently under development and not yet ready for production use**

- nvidia-driver-installer installs a `DaemonSet` which runs a pod on all the nodes labeled `node-role.kubernetes.io/ai-worker=true`. The pod on each node runs a privileged container that runs a script to install the drivers on the node.

- The script after installing the drivers writes a file `/host/var/run/reboot-needed` which [kured](https://kured.dev/) looks for to trigger the node reboot.

## Usage Guide

### Prerequisites

Before proceeding, ensure you have the following:

1. A running Kubernetes cluster with nodes based on **SLES** and/or **SLE Micro**.
2. Access to the cluster's `kubeconfig` file.
3. The [Helm CLI](https://helm.sh/docs/intro/install/) installed.

---

### Installation Steps

#### 1. Label GPU Nodes

Label the nodes with GPUs using the `node-role.kubernetes.io/ai-worker=true` label. The following command targets all worker nodes that are **not** control plane nodes:

```sh
kubectl get nodes -l node-role.kubernetes.io/worker=true -o json \
  | jq -r '.items[] | select(.metadata.labels["node-role.kubernetes.io/control-plane"] != "true") | .metadata.name' \
  | sed 's/\r//' \
  | xargs -r -I{} kubectl label node {} node-role.kubernetes.io/ai-worker=true --overwrite
```

> **Note:** Adjust the label logic if your cluster has different roles or labeling conventions.

---

#### 2. Configure `values.yaml`

Create or update a `values.yaml` file with your desired configuration. You can define either or both `sles` and `slem` sections under `os`, based on the operating systems present in your cluster.

```yaml
namespace: kube-system

nvidia:
  image: ghcr.io/suse/nvidia-driver-installer:0.1.0
  nodeSelector:
    node-role.kubernetes.io/ai-worker: "true"

os:
  sles:
    regcode: "VALID-SCC-REG-CODE"
    regemail: "VALID-SCC-EMAIL"
    driverVersion: "570.144"
  slem:
    regcode: "VALID-SCC-REG-CODE"
    regemail: "VALID-SCC-EMAIL"
    driverVersion: "550.54.14"

kured:
  image: ghcr.io/kubereboot/kured:1.17.1
  updatePeriod: "1m"
  rebootSentinel: "/sentinel/reboot-needed"
```

---

#### 3. Install the Helm Chart

Deploy the chart using the Helm CLI. If your current Kubernetes context is set appropriately, you may omit the `--kubeconfig` flag.

```sh
helm install nvidia-driver-installer oci://ghcr.io/suse/chart/nvidia-driver-installer \
  --version 0.1.0 \
  -f values.yaml \
  --kubeconfig /path/to/your/kubeconfig
```
