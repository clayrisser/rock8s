#!/bin/sh

KUBESPRAY_DOCKER_IMAGE="${kubespray_docker_image}"
KUBESPRAY_DATA_DIR="${kubespray_data_dir}"
sudo docker run --rm \
    --mount type=bind,source="$KUBESPRAY_DATA_DIR/inventory.ini",dst=/inventory/sample/inventory.ini \
    --mount type=bind,source="$KUBESPRAY_DATA_DIR/addons.yml",dst=/inventory/sample/group_vars/k8s_cluster/addons.yml \
    --mount type=bind,source="$KUBESPRAY_DATA_DIR/k8s-cluster.yml",dst=/inventory/sample/group_vars/k8s_cluster/k8s-cluster.yml \
    --mount type=bind,source="$KUBESPRAY_DATA_DIR/id_rsa",dst=/root/.ssh/id_rsa \
    "$KUBESPRAY_DOCKER_IMAGE" sh -c \
    "ansible-playbook -i /inventory/sample/inventory.ini -u admin -become cluster.yml"
