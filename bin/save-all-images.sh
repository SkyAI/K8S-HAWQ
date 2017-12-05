#!/bin/bash

if [[ $# -ne 1 ]]
then
    echo "please input the dir for save image"
    exit 1
fi

SAVE_DIR=$1
[[ ! -d ${SAVE_DIR} ]] && {
    echo "${SAVE_DIR} is not a directory, please set an exist dir"
    exit 1
}

KUBE_VERSION=v1.8.4
KUBE_DNS_VERSION=1.14.5
KUBE_ETCD_VERSION=3.0.17
KUBE_PAUSE_VERSION=3.0
KUBE_DASHBOARD_VERSION=v1.8.0
CALICO_NODE_VERSION=v2.6.3
CALICO_KUBECTL_VERSION=v1.0.1
CALICO_CNI_VERSION=v1.11.1
COREOS_ETCD_VERSION=v3.1.10
GCR_URL=gcr.io/google_containers
CALICO_URL=quay.io/calico
COREOS_URL=quay.io/coreos

kube_images=(kube-apiserver-amd64:${KUBE_VERSION}
kube-controller-manager-amd64:${KUBE_VERSION}
kube-scheduler-amd64:${KUBE_VERSION}
kube-proxy-amd64:${KUBE_VERSION}
k8s-dns-sidecar-amd64:${KUBE_DNS_VERSION}
k8s-dns-kube-dns-amd64:${KUBE_DNS_VERSION}
k8s-dns-dnsmasq-nanny-amd64:${KUBE_DNS_VERSION}
etcd-amd64:${KUBE_ETCD_VERSION}
pause-amd64:${KUBE_PAUSE_VERSION}
kubernetes-dashboard-amd64:${KUBE_DASHBOARD_VERSION})

calico_images=(node:${CALICO_NODE_VERSION}
kube-controllers:${CALICO_KUBECTL_VERSION}
cni:${CALICO_CNI_VERSION})

coreos_images=(etcd:${COREOS_ETCD_VERSION})

for image in ${kube_images[@]} ; do
    echo "begin to save ${image} ..."
    name=$(echo ${image} | awk -F":" '{print $1}')
    docker save -o ${SAVE_DIR}/${name}.tar ${GCR_URL}/${image}
    echo "save ${image} finished"
done

for image in ${calico_images[@]} ; do
    echo "begin to save ${image} ..."
    name=$(echo ${image} | awk -F":" '{print $1}')
    docker save -o ${SAVE_DIR}/${name}.tar ${CALICO_URL}/${image}
    echo "save ${image} finished"
done

for image in ${coreos_images[@]} ; do
    echo "begin to save ${image} ..."
    name=$(echo ${image} | awk -F":" '{print $1}')
    docker save -o ${SAVE_DIR}/${name}.tar ${COREOS_URL}/${image}
    echo "save ${image} finished"
done

