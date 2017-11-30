#!/bin/bash

SSH=ssh
SCP=scp
JOIN_CMD=

err() {
    echo -e "\\x1b[1;33mWARNING: $*\\x1b[0m"
}

warn() {
    echo -e "\\x1b[1;33mWARNING: $*\\x1b[0m"
}

info() {
    echo "INFO: $*"
}

get_ip_info() {
    local file_path=$1
    local scope=$2

    [[ -s "$file_path" ]] || {
        err "cannot find the $file_path"
        return 1
    }

    local ip_info=$(grep -v -e "^#" -e "^$" $file_path | grep "$scope" | cut -f2 -d":")
    ip_info="${ip_info//[[:blank:]]/}"
    echo "$ip_info"
}

install_k8s() {
    local node=$1
    $SSH $node "yum install kubeadm&& systemctl enable kubelet && systemctl start kubelet" >/dev/null || {
        err "$SSH $node \"yum install kubeadm && systemctl enable kubelet && systemctl start kubelet\" failed"
        return 1
    }
}

uninstall_k8s() {
    local node=$1
    $SSH $node "systemctl disable kubelet && systemctl stop kubelet && yum remove kubeadm kubelet kubectl kubernetes-cni" > /dev/null 2>&1 || {
        err "$SSH $node \"systemctl disable kubelet && systemctl stop kubelet && yum remove kubeadm kubelet kubectl kubernetes-cni\" failed"
        return 1
    }
}

scp_scripts() {
    local deploy_dir=$1
    local scripts_dir=$deploy_dir/bin
    [[ -d "$scripts_dir" ]] || {
        err "$scripts_dir is not exist"
        return 1
    }

    local install_dir=$2
    local node=$3
    $SSH $node "[[ ! -d $install_dir ]] && mkdir -p $install_dir"
    $SCP -r $scripts_dir $node:$install_dir > /dev/null || {
        err "$SCP -r $scripts_dir $node@$install_dir failed"
        return 1
    }
}

scp_and_load_images() {
    local deploy_dir=$1
    local images_path=$deploy_dir/pkgs/images.tar.gz
    [[ -f "$images_path" ]] || {
        err "$images_path is not exist"
        return 1
    }

    local install_dir=$2
    local bin_dir=$install_dir/bin
    local pkgs_dir=$install_dir/pkgs
    local node=$3
    $SSH $node "[[ ! -d $pkgs_dir ]] && mkdir -p $pkgs_dir"
    $SCP $images_path $node:$pkgs_dir > /dev/null || {
        err "$SCP $images_path $node:$pkgs_dir failed"
        return 1
    }

    $SSH $node "cd $pkgs_dir && tar xzvf images.tar.gz" > /dev/null || {
        err "$SSH $node \"cd $pkgs_dir && tar xzvf images.tar.gz\" failed"
        return 1
    }

    $SSH $node "cd $bin_dir && sh load-all-images.sh $pkgs_dir/images" > /dev/null || {
        err "$SSH $node \"cd $bin_dir && sh load-all-images.sh $pkgs_dir/images\" failed"
        return 1
    }
}

init_masters() {
    local master_nodes=$1
    for node in $master_nodes; do
        echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
        swapoff -a
        JOIN_CMD=$(kubeadm init --kubernetes-version=v1.8.4 --pod-network-cidr=192.168.0.0/16 >&1 | grep 'kubeadm join')
        if [[ -s "$JOIN_CMD" ]]; then
            err "k8s master init failed"
            return 1
        fi

        echo export KUBECONFIG=/etc/kubernetes/admin.conf >> ~/.bashrc && source ~/.bashrc
        export KUBECONFIG=/etc/kubernetes/admin.conf && kubectl apply -f https://docs.projectcalico.org/v2.6/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml > /dev/null || {
            err "k8s get init calico failed"
            return 1
        }
    done
}

init_workers() {
    local worker_nodes=$1
    for node in $worker_nodes; do
        echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
        swapoff -a

        [[ -s "$JOIN_CMD" ]] && {
            err "join cmd is empty"
            return 1
        }

        $SSH $node "$JOIN_CMD" > /dev/null || {
            err "$SSH $node \"$JOIN_CMD\" failed"
            return 1
        }
    done
}

reset_k8s_nodes() {
    local nodes=$1
    for node in $nodes; do
        $SSH $node "kubeadm reset" > /dev/null 2>&1
    done
}

cleanup() {
    for node in $MASTERS $WORKERS; do
        reset_k8s_nodes $node
        uninstall_k8s $node
        $SSH $node "[[ "$INSTALL_DIR" != "/" ]] && [[ -d $INSTALL_DIR ]] && rm -rf $INSTALL_DIR/*"
    done
}


# parse params and init
CURRENT_DIR=$(cd $(dirname $0);pwd)
CONF_DIR=$CURRENT_DIR/conf
[[ -d $CONF_DIR ]] || {
    err "$CONF_DIR is not a dir"
    exit 1
}

IP_FILE_PATH=$CONF_DIR/install_ip
DEPLOY_FILE_PATH=$CONF_DIR/deploy.conf

DEPLOY_DIR=$(grep -v -e "^#" -e "^$" $DEPLOY_FILE_PATH | grep DEPLOY_DIR | cut -f2 -d"=")
INSTALL_DIR=$(grep -v -e "^#" -e "^$" $DEPLOY_FILE_PATH | grep INSTALL_DIR | cut -f2 -d"=")
MASTERS=$(get_ip_info $IP_FILE_PATH "master")
WORKERS=$(get_ip_info $IP_FILE_PATH "worker")

[[ $(echo "$MASTERS" | tr ' ' '\n' | wc -l) -ne 1 ]] && {
    err "current one master supported only !!!"
    exit 1
}

action=$1
case $action in
    install)
        # init master
        for node in $MASTERS; do
            info "begin to scp scripts to master($node) ..."
            scp_scripts $DEPLOY_DIR $INSTALL_DIR "$node" || {
                err "scp scripts to k8s master($node) failed, revert all installed nodes"
                cleanup && exit 1
            }
            info "scp scripts to master($node) finished"

            info "begin to scp and load images on master($node) ..."
            scp_and_load_images $DEPLOY_DIR $INSTALL_DIR "$node" || {
                err "scp and load images to k8s master($node) failed, revert all installed nodes"
                cleanup && exit 1
            }
            info "scp and load images on master($node) finished"

            info "begin to install k8s on master($node) ..."
            install_k8s $node || {
                err "install k8s on master($node) failed"
                cleanup && exit 1
            }
            info "install k8s on master($node) finished"

            info "begin to init k8s master($node) ..."
            init_masters $node || {
                err "init k8s master($node) failed"
                cleanup && exit 1
            }
            info "init k8s master($node) finished"
        done
        info "install k8s master on ($MASTERS) finished"

        # init workers
        for node in $WORKERS; do
            info "begin to scp scripts to worker($node) ..."
            scp_scripts $DEPLOY_DIR $INSTALL_DIR "$node" || {
                err "scp scripts to k8s worker($node) failed, revert all installed nodes"
                cleanup && exit 1
            }
            info "scp scripts to worker($node) finished"

            info "begin to scp and load images on worker($node) ..."
            scp_and_load_images $DEPLOY_DIR $INSTALL_DIR "$node" || {
                err "scp and load images to k8s worker($node) failed, revert all installed nodes"
                cleanup && exit 1
            }
            info "scp and load images on worker($node) finished"

            info "begin to install k8s on worker($node) ..."
            install_k8s $node || {
                err "install k8s on worker($node) failed"
                cleanup && exit 1
            }
            info "install k8s on worker($node) finished"

            info "begin to init k8s worker($node) ..."
            init_workers $node || {
                err "init k8s worker($node) failed"
                cleanup && exit 1
            }
            info "init k8s worker($node) finished"
        done
        info "install k8s workers on ($WORKERS) finished"
    ;;
    uninstall)
        cleanup && info "uninstall k8s cluster finished"
        exit 0
    ;;
    *)
        warn "$action is not supported"
    ;;
esac

