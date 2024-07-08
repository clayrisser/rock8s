#!/bin/sh

KUBESPRAY_DATA_DIR="${kubespray_data_dir}"
cd "$KUBESPRAY_DATA_DIR/kubespray"
pwd
echo ../env/bin/ansible-playbook -i inventory/sample/inventory.ini -u admin --become --become-user=root cluster.yml
../env/bin/ansible-playbook -i inventory/sample/inventory.ini -u admin --become --become-user=root cluster.yml
