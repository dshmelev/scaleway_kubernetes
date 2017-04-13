#!/bin/bash
set -euo pipefail
ETCD_VERSION=3.1.5
KUB_VERSION=1.6.1
FLANNEL_VERSION=0.7.0

ETCD_URL="https://github.com/coreos/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz"
KUB_URL="https://dl.k8s.io/v${KUB_VERSION}/kubernetes-server-linux-amd64.tar.gz"
FLANNEL_URL="https://github.com/coreos/flannel/releases/download/v${FLANNEL_VERSION}/flannel-v${FLANNEL_VERSION}-linux-amd64.tar.gz"

systemctl stop apt-daily
systemctl disable apt-daily

# Update system
apt-get -qy update
apt-get -qy dist-upgrade
apt-get -qy install apt-transport-https

apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo 'deb https://apt.dockerproject.org/repo ubuntu-xenial main' \
  > /etc/apt/sources.list.d/docker.list
apt-get -qy update

# Install packages; RUNLEVEL disabled autostart services
RUNLEVEL=1 apt-get -qy install docker-engine=1.13.1-0~ubuntu-xenial \
                               jq iotop htop conntrack

# Install etcd
curl -L "$ETCD_URL" \
  | tar -C /usr/bin -xzf - --strip-components=1

# Install Kubernetes
curl -L "$KUB_URL" \
  | tar -C /tmp -xzf -
mv /tmp/kubernetes/server/bin/hyperkube /usr/bin
chmod a+x /usr/bin/hyperkube
ln -s hyperkube /usr/bin/kubectl

# Install flannel
mkdir -p /tmp/flannel
curl -L "$FLANNEL_URL" \
  | tar -C /tmp/flannel -xzf -
mv /tmp/flannel/flanneld /usr/bin
chmod a+x /usr/bin/flanneld
rm -rf /tmp/flannel

useradd -m -G docker k8s
