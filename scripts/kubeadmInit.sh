#!/bin/sh
set -a
API_ADDVERTISE_IP=$(hostname -I)
APISERVER=$(hostname -s)
NODENAME=$(hostname -s)

POD_NET=$1
CP_NODE_FQDN=$2
KUBEADM_INIT_YML=$3

echo 

echo "running kubeadm init --apiserver-advertise-address=$IPADDR \
                  --apiserver-cert-extra-sans=$APISERVER \
                  --pod-network-cidr=$POD_NET \
                  --node-name $NODENAME
                  --apiserver-cert-extra-sans $CP_NODE_FQDN"

kubeadm init --apiserver-advertise-address=$IPADDR \
             --apiserver-cert-extra-sans=$APISERVER \
             --pod-network-cidr=$POD_NET \
             --node-name $NODENAME \
             --apiserver-cert-extra-sans $CP_NODE_FQDN

