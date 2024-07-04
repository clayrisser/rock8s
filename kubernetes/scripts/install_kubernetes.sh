#!/bin/bash
kubespray_docker_image="${kubespray_docker_image}"
kubespray_data_dir="${kubespray_data_dir}"

# Install Kubernetes
sudo docker run \
    --mount type=bind,source="$kubespray_data_dir/inventory.ini",dst=/inventory/sample/inventory.ini \
    --mount type=bind,source="$kubespray_data_dir/addons.yml",dst=/inventory/sample/group_vars/k8s_cluster/addons.yml \
    --mount type=bind,source="$kubespray_data_dir/k8s-cluster.yml",dst=/inventory/sample/group_vars/k8s_cluster/k8s-cluster.yml \
    --mount type=bind,source="$kubespray_data_dir/id_rsa",dst=/root/.ssh/id_rsa \
    $kubespray_docker_image bash -c \
    "ansible-playbook -i /inventory/sample/inventory.ini -u admin -become cluster.yml"
