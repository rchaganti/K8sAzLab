#!/bin/sh

USERNAME=$1
PLUGIN=$2
CIDR=$3

mkdir -p /home/$USERNAME/.kube
cp -i /etc/kubernetes/admin.conf /home/$USERNAME/.kube/config
chown $(id -u $USERNAME):$(id -g $USERNAME) /home/$USERNAME/.kube/config

# This is needed for root
export KUBECONFIG=/etc/kubernetes/admin.conf

case "$PLUGIN" in
        "calico") 
                curl -Lo /tmp/tigera-operator.yaml https://raw.githubusercontent.com/projectcalico/calico/master/manifests/tigera-operator.yaml
                kubectl create -f /tmp/tigera-operator.yaml

                curl -Lo /tmp/custom-resources.yaml https://raw.githubusercontent.com/projectcalico/calico/master/manifests/custom-resources.yaml
                sed -i "s|192.168.0.0/16|$CIDR|" /tmp/custom-resources.yaml
                kubectl create -f /tmp/custom-resources.yaml
                ;;
        *)
                echo "Nothing to install"
                ;;
esac