#!/usr/bin/env bash
# Run as root INSIDE a disposable Ubuntu 20.04 VM, not on the host.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
K8S_VERSION="${K8S_VERSION:-1.33.13}"
K8S_MINOR="${K8S_VERSION%.*}"
. /etc/os-release
[[ "$ID" == ubuntu && "$VERSION_ID" == 20.04 ]]

swapoff -a
modprobe overlay
modprobe br_netfilter
printf 'overlay\nbr_netfilter\n' > /etc/modules-load.d/kubernetes.conf
cat > /etc/sysctl.d/99-kubernetes.conf <<'CONFIG'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
CONFIG
sysctl --system >/dev/null

apt-get update
apt-get -o DPkg::Lock::Timeout=180 install -y apt-transport-https ca-certificates curl gpg containerd linux-image-generic-hwe-20.04
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
python3 - <<'PY'
from pathlib import Path
p = Path('/etc/containerd/config.toml')
s = p.read_text().replace('SystemdCgroup = false', 'SystemdCgroup = true')
s = s.replace('registry.k8s.io/pause:3.8', 'registry.k8s.io/pause:3.10')
p.write_text(s)
PY
systemctl enable --now containerd
systemctl restart containerd

mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR}/deb/Release.key" | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
printf 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v%s/deb/ /\n' "$K8S_MINOR" > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get -o DPkg::Lock::Timeout=180 install -y "kubelet=${K8S_VERSION}-1.1" "kubeadm=${K8S_VERSION}-1.1" "kubectl=${K8S_VERSION}-1.1" cri-tools
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

# Ubuntu 20.04's GA kernel is old; use HWE and unified cgroup v2.
printf 'GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX systemd.unified_cgroup_hierarchy=1"\n' > /etc/default/grub.d/99-kubernetes-cgroups.cfg
update-grub
printf '\nReboot the VM before kubeadm init/join.\n'
