VARS := -var cores=$(CORES) \
		-var cpu_type=$(CPU_TYPE) \
		-var disk_format=$(DISK_FORMAT) \
		-var disk_size=$(DISK_SIZE) \
		-var iso_checksum=$(ISO_CHECKSUM) \
		-var iso_file=$(ISO_FILE) \
		-var iso_storage_pool=$(ISO_STORAGE_POOL) \
		-var iso_url=$(ISO_URL) \
		-var memory=$(MEMORY) \
		-var network_bridge=$(NETWORK_BRIDGE) \
		-var network_ip=$(NETWORK_IP) \
		-var proxmox_host=$(PROXMOX_HOST) \
		-var proxmox_node=$(PROXMOX_NODE) \
		-var proxmox_token_id=$(PROXMOX_TOKEN_ID) \
		-var proxmox_token_secret=$(PROXMOX_TOKEN_SECRET) \
		-var storage_pool=$(STORAGE_POOL) \
		-var vm_name=$(VM_NAME)
