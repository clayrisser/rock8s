#!/bin/sh

KUBESPRAY_DATA_DIR="${kubespray_data_dir}"
cd "$KUBESPRAY_DATA_DIR"
env/bin/ansible-playbook -i kubespray/inventory/sample/inventory.ini -u admin --become --become-user=root cluster.yml
